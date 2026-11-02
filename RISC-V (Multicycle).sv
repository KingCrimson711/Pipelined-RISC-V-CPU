// design.v — write your module here, or load one from Examples

//in multicycle risc-v processors
//we need a fsm for control signals insted of a 
//look up table in single cycle processors

module alu (
input [31:0] srca,
input [31:0] srcb,
input [2:0] alucontrols,
input clk,
output reg [31:0] aluout
);
always @(*) begin
if(alucontrols==3'b000) aluout=srca+srcb;
else if(alucontrols==3'b001) aluout=srca-srcb;
else if(alucontrols==3'b010) aluout=srca&srcb;
else if(alucontrols==3'b011) aluout=srca|srcb;
else if(alucontrols==3'b101) begin
    if(srca[31]!=srcb[31]) begin
        if(srca[31]) aluout=32'd1;
        else aluout=32'd0;
    end
    else begin
        if(srca<srcb) aluout=32'd1;
        else aluout=32'd0;
    end
end
else aluout=32'd0;
end
endmodule


module program_counter (
input [31:0]pcnext,
input clk,
input en,
input reset,
output reg [31:0] pc
);
always @(posedge clk) begin
if(reset) pc<=32'd0;
else if(en) pc<=pcnext;
end
endmodule

module inst_and_data_memory (
input [31:0] a,
input [31:0] wd,
input clk,
input we,
output reg [31:0] rd1
);
reg [31:0] mem [0:255];
always @(*) begin
rd1=mem[a[9:2]];
end
always @(posedge clk) begin
if(we) mem[a[9:2]]<=wd;
end
endmodule

module register_file (
input [4:0]a1,
input [4:0]a2,
input [4:0]a3,
input [31:0] wd3,
input clk,
input we3,
output reg [31:0] rd1,
output reg [31:0] rd2
);
reg [31:0] rf [0:31];
always @(*) begin
if(a1==5'd0) rd1=32'd0;
else rd1=rf[a1];
if(a2==5'd0) rd2=32'd0;
else rd2=rf[a2];
end
always @(posedge clk) begin
if(we3) begin
if(a3!=5'd0) rf[a3]<=wd3;
end
end
endmodule


module control_signals (
input [31:0] instruction, //we will extract opcode from here 
output reg pcwrite,
output reg adrsrc,
output reg memwrite,
output reg irwrite,
output reg [1:0]resultsrc,
output reg [2:0]alucontrol,
output reg [1:0] alusrcb,
output reg [1:0]alusrca,
output reg [1:0]immsrc,
output reg regwrite,
input clk,
input zero,
input reset
);
wire [6:0] op=instruction[6:0];
wire [2:0] funct3=instruction[14:12];
wire funct7b5=instruction[30];

// state numbers: 0 fetch, 1 decode, 2 memadr, 3 memread, 4 memwb, 5 memwrite,
// 6 executer, 7 aluwb, 8 executei, 9 jal, 10 beq
reg [3:0] state;
reg [3:0] nextstate;
reg [1:0] aluop;

always @(posedge clk) begin
if(reset) state<=4'd0;
else state<=nextstate;
end

always @(*) begin
nextstate=4'd0;
if(state==4'd0) nextstate=4'd1;
if(state==4'd1) begin
    if(op==7'b0000011) nextstate=4'd2;
    else if(op==7'b0100011) nextstate=4'd2;
    else if(op==7'b0110011) nextstate=4'd6;
    else if(op==7'b0010011) nextstate=4'd8;
    else if(op==7'b1101111) nextstate=4'd9;
    else if(op==7'b1100011) nextstate=4'd10;
    else nextstate=4'd0;
end
if(state==4'd2) begin
    if(op==7'b0000011) nextstate=4'd3;
    else nextstate=4'd5;
end
if(state==4'd3) nextstate=4'd4;
if(state==4'd4) nextstate=4'd0;
if(state==4'd5) nextstate=4'd0;
if(state==4'd6) nextstate=4'd7;
if(state==4'd7) nextstate=4'd0;
if(state==4'd8) nextstate=4'd7;
if(state==4'd9) nextstate=4'd7;
if(state==4'd10) nextstate=4'd0;
end

always @(*) begin
pcwrite=1'b0;
adrsrc=1'b0;
memwrite=1'b0;
irwrite=1'b0;
regwrite=1'b0;
resultsrc=2'b00;
alusrca=2'b00;
alusrcb=2'b00;
aluop=2'b00;
if(state==4'd0) begin      // fetch
    irwrite=1'b1; pcwrite=1'b1; resultsrc=2'b10; alusrca=2'b00; alusrcb=2'b10; aluop=2'b00;
end
if(state==4'd1) begin      // decode
    alusrca=2'b01; alusrcb=2'b01; aluop=2'b00;
end
if(state==4'd2) begin      // memadr
    alusrca=2'b10; alusrcb=2'b01; aluop=2'b00;
end
if(state==4'd3) begin      // memread
    adrsrc=1'b1; resultsrc=2'b00;
end
if(state==4'd4) begin      // memwb
    resultsrc=2'b01; regwrite=1'b1;
end
if(state==4'd5) begin      // memwrite
    adrsrc=1'b1; resultsrc=2'b00; memwrite=1'b1;
end
if(state==4'd6) begin      // executer
    alusrca=2'b10; alusrcb=2'b00; aluop=2'b10;
end
if(state==4'd7) begin      // aluwb
    resultsrc=2'b00; regwrite=1'b1;
end
if(state==4'd8) begin      // executei
    alusrca=2'b10; alusrcb=2'b01; aluop=2'b10;
end
if(state==4'd9) begin      // jal
    alusrca=2'b01; alusrcb=2'b10; aluop=2'b00; resultsrc=2'b00; pcwrite=1'b1;
end
if(state==4'd10) begin     // beq
    alusrca=2'b10; alusrcb=2'b00; aluop=2'b01; resultsrc=2'b00;
    if(zero) pcwrite=1'b1;
end
end

// alu decoder
always @(*) begin
if(aluop==2'b00) alucontrol=3'b000;
else if(aluop==2'b01) alucontrol=3'b001;
else begin
    if(funct3==3'b000) begin
        if(op[5]==1'b1 && funct7b5==1'b1) alucontrol=3'b001;
        else alucontrol=3'b000;
    end
    else if(funct3==3'b010) alucontrol=3'b101;
    else if(funct3==3'b110) alucontrol=3'b011;
    else if(funct3==3'b111) alucontrol=3'b010;
    else alucontrol=3'b000;
end
end

// immsrc depends only on the opcode
always @(*) begin
if(op==7'b0100011) immsrc=2'b01;
else if(op==7'b1100011) immsrc=2'b10;
else if(op==7'b1101111) immsrc=2'b11;
else immsrc=2'b00;
end
endmodule

module extender(
input [24:0]a,
input [1:0] sup,
output reg [31:0]b
);
always @(*)begin
if(sup==2'b00) b={{20{a[24]}},a[24:13]};
else if(sup==2'b01) b={{20{a[24]}},a[24:18],a[4:0]};
else if(sup==2'b10) b={{20{a[24]}},a[0],a[23:18],a[4:1],1'b0};
else b={{12{a[24]}},a[12:5],a[13],a[23:14],1'b0};
end

endmodule

module risc_v (
input clk,
input reset,
output reg [31:0] pc_out,
output reg [31:0] result_out
);
wire [31:0] w1;
reg  [31:0] w2;
wire [31:0] w3;
reg  [31:0] w4;
reg  [31:0] w5;
reg  [31:0] w6;
wire [31:0] w7;
reg  [31:0] w8;
reg  [31:0] w9;
reg  [31:0] w10;
reg  [31:0] w11;
reg  [31:0] w12;
wire [31:0] w13;
reg  [31:0] w14;
wire [31:0] w15; //wire below wire 8 see in diagram
reg  [31:0] below_w8;
reg zero;

wire pcwrite;
wire adrsrc;
wire memwrite;
wire irwrite;
wire regwrite;
wire [1:0] resultsrc;
wire [1:0] alusrca;
wire [1:0] alusrcb;
wire [1:0] immsrc;
wire [2:0] alucontrol;

program_counter aee(w12,clk,pcwrite,reset,w1);
always @(*) begin
if(adrsrc) w2=w12;
else w2=w1;
end

inst_and_data_memory bee(w2,below_w8,clk,memwrite,w3);

always @(posedge clk) begin
if(irwrite) begin
w4<=w1;
w5<=w3;
end
end

always @(posedge clk) begin
w6<=w3;
end

wire [4:0]rs1 ={w5[19],w5[18],w5[17],w5[16],w5[15]};
wire [4:0]rs2={w5[24],w5[23],w5[22],w5[21],w5[20]};
wire [4:0] rd={w5[11],w5[10],w5[9],w5[8],w5[7]};

wire [31:0] RD1;
wire [31:0] RD2;
//wire [31:0] below_w8;

register_file cee(rs1,rs2,rd,w12,clk,regwrite,RD1,RD2);




always @(posedge clk) begin
w8<=RD1;
below_w8<=RD2;
end

extender dee(w5[31:7],immsrc,w13);

always @(*) begin
if(alusrca==2'b00) w9=w1;
else if(alusrca==2'b01) w9=w4;
else w9=w8;
end

always @(*) begin
if(alusrcb==2'b00) w14=below_w8;
else if(alusrcb==2'b01) w14=w13;
else w14=32'd4;//this is 32 bit  
end

always @(*) begin
if(alucontrol==3'b000) w10=w9+w14;
else if(alucontrol==3'b001) w10=w9-w14;
else if(alucontrol==3'b010) w10=w9&w14;
else if(alucontrol==3'b011) w10=w9|w14;
else if(alucontrol==3'b101) begin
    if(w9[31]!=w14[31]) begin
        if(w9[31]) w10=32'd1;
        else w10=32'd0;
    end
    else begin
        if(w9<w14) w10=32'd1;
        else w10=32'd0;
    end
end
else w10=32'd0;
end

// zero flag, goes to the control unit (used by beq)
always @(*) begin
if(w10==32'd0) zero=1'b1;
else zero=1'b0;
end

always @(posedge clk) begin
w11<=w10;
end

always @(*) begin
if(resultsrc==2'b00) w12=w11;
else if(resultsrc==2'b01) w12=w6;
else w12=w10;
end

control_signals ctrl(w5,pcwrite,adrsrc,memwrite,irwrite,resultsrc,alucontrol,alusrcb,alusrca,immsrc,regwrite,clk,zero,reset);

// outputs so that synthesis keeps the design
always @(*) begin
pc_out=w1;
result_out=w12;
end
endmodule