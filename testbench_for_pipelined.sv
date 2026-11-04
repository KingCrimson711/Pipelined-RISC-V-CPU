// testbench for risc_v_pipe
// loadss a small program, runs it, then checks registers and data meory

module testbench;
reg clk;
reg reset;
wire [31:0] pc_out;
wire [31:0] result_out;

integer n;
integer i;
integer errors;

risc_v_pipe dut(clk,reset,pc_out,result_out);

always #5 clk=~clk;

// ---------- instruction encoders ----------
function [31:0] rtype;
input [6:0] f7;
input [4:0] rs2;
input [4:0] rs1;
input [2:0] f3;
input [4:0] rd;
begin
rtype={f7,rs2,rs1,f3,rd,7'b0110011};
end
endfunction

function [31:0] itype;
input [11:0] imm;
input [4:0] rs1;
input [2:0] f3;
input [4:0] rd;
input [6:0] op;
begin
itype={imm,rs1,f3,rd,op};
end
endfunction

function [31:0] stype;
input [11:0] imm;
input [4:0] rs2;
input [4:0] rs1;
begin
stype={imm[11:5],rs2,rs1,3'b010,imm[4:0],7'b0100011};
end
endfunction

function [31:0] btype;
input [12:0] imm;
input [4:0] rs2;
input [4:0] rs1;
begin
btype={imm[12],imm[10:5],rs2,rs1,3'b000,imm[4:1],imm[11],7'b1100011};
end
endfunction

function [31:0] jtype;
input [20:0] imm;
input [4:0] rd;
begin
jtype={imm[20],imm[10:1],imm[11],imm[19:12],rd,7'b1101111};
end
endfunction

// put one instruction in instruction memory
task put;
input [31:0] instr;
begin
dut.bee.mem[n]=instr;
n=n+1;
end
endtask

task check;
input [255:0] name;
input [31:0] actual;
input [31:0] expected;
begin
if(actual===expected) $display("pass  %0s = %0d",name,actual);
else begin
$display("FAIL  %0s = %0d (expected %0d)",name,actual,expected);
errors=errors+1;
end
end
endtask

initial begin
clk=0;
reset=1;
n=0;
errors=0;
#1;   // wait for the memory initial block, then overwrite it

// clear memories and registers
for(i=0;i<256;i=i+1) begin
dut.bee.mem[i]=32'h00000013;
dut.gee.mem[i]=32'd0;
end
for(i=0;i<32;i=i+1) dut.cee.rf[i]=32'd0;

// ---------- program ----------
put(itype(12'd5,5'd0,3'b000,5'd1,7'b0010011));     //  0 addi x1,x0,5
put(itype(12'd10,5'd0,3'b000,5'd2,7'b0010011));    //  1 addi x2,x0,10
put(rtype(7'b0000000,5'd2,5'd1,3'b000,5'd3));      //  2 add  x3,x1,x2    forward from mem and wb
put(rtype(7'b0100000,5'd1,5'd2,3'b000,5'd4));      //  3 sub  x4,x2,x1    reg file write/read same cycle
put(rtype(7'b0000000,5'd2,5'd3,3'b111,5'd5));      //  4 and  x5,x3,x2
put(rtype(7'b0000000,5'd2,5'd1,3'b110,5'd6));      //  5 or   x6,x1,x2
put(rtype(7'b0000000,5'd2,5'd1,3'b010,5'd7));      //  6 slt  x7,x1,x2
put(itype(12'd3,5'd2,3'b010,5'd8,7'b0010011));     //  7 slti x8,x2,3
put(stype(12'd0,5'd3,5'd0));                       //  8 sw   x3,0(x0)
put(itype(12'd0,5'd0,3'b010,5'd9,7'b0000011));     //  9 lw   x9,0(x0)
put(rtype(7'b0000000,5'd1,5'd9,3'b000,5'd10));     // 10 add  x10,x9,x1   load use stall
put(stype(12'd4,5'd10,5'd0));                      // 11 sw   x10,4(x0)   store data forwarded
put(btype(13'd8,5'd4,5'd1));                       // 12 beq  x1,x4,+8    taken
put(itype(12'd99,5'd0,3'b000,5'd11,7'b0010011));   // 13 addi x11,x0,99   must be flushed
put(btype(13'd8,5'd2,5'd1));                       // 14 beq  x1,x2,+8    not taken
put(itype(12'd7,5'd0,3'b000,5'd12,7'b0010011));    // 15 addi x12,x0,7    must run
put(jtype(21'd8,5'd13));                           // 16 jal  x13,+8
put(itype(12'd99,5'd0,3'b000,5'd14,7'b0010011));   // 17 addi x14,x0,99   must be flushed
put(itype(12'd1,5'd0,3'b000,5'd15,7'b0010011));    // 18 addi x15,x0,1
put(rtype(7'b0000000,5'd0,5'd13,3'b000,5'd25));    // 19 add  x25,x13,x0  uses the jal result
put(itype(12'd5,5'd1,3'b000,5'd0,7'b0010011));     // 20 addi x0,x1,5     x0 must stay 0
put(rtype(7'b0000000,5'd1,5'd0,3'b000,5'd16));     // 21 add  x16,x0,x1
put(itype(12'd4,5'd0,3'b010,5'd17,7'b0000011));    // 22 lw   x17,4(x0)
put(stype(12'd8,5'd17,5'd0));                      // 23 sw   x17,8(x0)   lw then sw stall
put(itype(12'd3,5'd0,3'b000,5'd18,7'b0010011));    // 24 addi x18,x0,3
put(itype(12'd3,5'd0,3'b000,5'd19,7'b0010011));    // 25 addi x19,x0,3
put(btype(13'd8,5'd19,5'd18));                     // 26 beq  x18,x19,+8  taken, operands just computed
put(itype(12'd99,5'd0,3'b000,5'd20,7'b0010011));   // 27 addi x20,x0,99   must be flushed
put(itype(12'd42,5'd0,3'b000,5'd21,7'b0010011));   // 28 addi x21,x0,42
put(itype(12'd0,5'd0,3'b010,5'd22,7'b0000011));    // 29 lw   x22,0(x0)
put(btype(13'd8,5'd3,5'd22));                      // 30 beq  x22,x3,+8   taken, right after a load
put(itype(12'd99,5'd0,3'b000,5'd23,7'b0010011));   // 31 addi x23,x0,99   must be flushed
put(itype(12'd1,5'd0,3'b000,5'd24,7'b0010011));    // 32 addi x24,x0,1
put(btype(13'd0,5'd0,5'd0));                       // 33 beq  x0,x0,0     loop forever

// release reset and run
#22 reset=0;
#2000;

// ---------- checks ----------
$display("---- registers ----");
check("x0 ",dut.cee.rf[0],32'd0);
check("x1 ",dut.cee.rf[1],32'd5);
check("x2 ",dut.cee.rf[2],32'd10);
check("x3 ",dut.cee.rf[3],32'd15);
check("x4 ",dut.cee.rf[4],32'd5);
check("x5 ",dut.cee.rf[5],32'd10);
check("x6 ",dut.cee.rf[6],32'd15);
check("x7 ",dut.cee.rf[7],32'd1);
check("x8 ",dut.cee.rf[8],32'd0);
check("x9 ",dut.cee.rf[9],32'd15);
check("x10",dut.cee.rf[10],32'd20);
check("x11",dut.cee.rf[11],32'd0);
check("x12",dut.cee.rf[12],32'd7);
check("x13",dut.cee.rf[13],32'd68);
check("x14",dut.cee.rf[14],32'd0);
check("x15",dut.cee.rf[15],32'd1);
check("x16",dut.cee.rf[16],32'd5);
check("x17",dut.cee.rf[17],32'd20);
check("x18",dut.cee.rf[18],32'd3);
check("x19",dut.cee.rf[19],32'd3);
check("x20",dut.cee.rf[20],32'd0);
check("x21",dut.cee.rf[21],32'd42);
check("x22",dut.cee.rf[22],32'd15);
check("x23",dut.cee.rf[23],32'd0);
check("x24",dut.cee.rf[24],32'd1);
check("x25",dut.cee.rf[25],32'd68);
$display("---- data memory ----");
check("mem[0]",dut.gee.mem[0],32'd15);
check("mem[1]",dut.gee.mem[1],32'd20);
check("mem[2]",dut.gee.mem[2],32'd20);

if(errors==0) $display("all tests passed");
else $display("%0d tests failed",errors);
$finish;
end

initial begin
$dumpfile("pipe.vcd");
$dumpvars(0,testbench);
end
endmodule
