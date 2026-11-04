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
integer i;
initial begin
// program for synthesis (without contents the synthesizer sees an empty
// instruction memory and removes the whole cpu). the testbench overwrites it.
for(i=0;i<256;i=i+1) mem[i]=32'd0;
mem[0]=32'h00500093;
mem[1]=32'h00a00113;
mem[2]=32'h002081b3;
mem[3]=32'h40110233;
mem[4]=32'h0021f2b3;
mem[5]=32'h0020e333;
mem[6]=32'h0020a3b3;
mem[7]=32'h00312413;
mem[8]=32'h00302023;
mem[9]=32'h00002483;
mem[10]=32'h00148533;
mem[11]=32'h00a02223;
mem[12]=32'h00408463;
mem[13]=32'h06300593;
mem[14]=32'h00208463;
mem[15]=32'h00700613;
mem[16]=32'h008006ef;
mem[17]=32'h06300713;
mem[18]=32'h00100793;
mem[19]=32'h00068cb3;
mem[20]=32'h00508013;
mem[21]=32'h00100833;
mem[22]=32'h00402883;
mem[23]=32'h01102423;
mem[24]=32'h00300913;
mem[25]=32'h00300993;
mem[26]=32'h01390463;
mem[27]=32'h06300a13;
mem[28]=32'h02a00a93;
mem[29]=32'h00002b03;
mem[30]=32'h003b0463;
mem[31]=32'h06300b93;
mem[32]=32'h00100c13;
mem[33]=32'h00000063;
end
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


// =====================================================================
// everything below is new (harris and harris pipelined risc-v).
// the original modules above are not touched, so the multicycle
// risc_v still works. the pipelined cpu is risc_v_pipe.
// =====================================================================

// control unit of the pipelined cpu: same decoders as control_signals,
// but no fsm, it just decodes the instruction sitting in the decode stage
// (the signals are then carried down the pipeline registers in risc_v_pipe)
module control_signals_p (
input [31:0] instruction,
output reg regwrite,
output reg [1:0] resultsrc,   // 00 aluresult, 01 readdata, 10 pcplus4
output reg memwrite,
output reg jump,
output reg branch,
output reg [2:0] alucontrol,
output reg alusrc,            // 0 = rd2, 1 = immediate
output reg [1:0] immsrc
);
wire [6:0] op=instruction[6:0];
wire [2:0] funct3=instruction[14:12];
wire funct7b5=instruction[30];
reg [1:0] aluop;

always @(*) begin
regwrite=1'b0;
resultsrc=2'b00;
memwrite=1'b0;
jump=1'b0;
branch=1'b0;
alusrc=1'b0;
aluop=2'b00;
if(op==7'b0000011) begin    // lw
    regwrite=1'b1; resultsrc=2'b01; alusrc=1'b1; aluop=2'b00;
end
if(op==7'b0100011) begin    // sw
    memwrite=1'b1; alusrc=1'b1; aluop=2'b00;
end
if(op==7'b0110011) begin    // r type
    regwrite=1'b1; alusrc=1'b0; aluop=2'b10;
end
if(op==7'b0010011) begin    // i type
    regwrite=1'b1; alusrc=1'b1; aluop=2'b10;
end
if(op==7'b1101111) begin    // jal
    regwrite=1'b1; resultsrc=2'b10; jump=1'b1; aluop=2'b00;
end
if(op==7'b1100011) begin    // beq
    branch=1'b1; alusrc=1'b0; aluop=2'b01;
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


// hazard unit (the blue box at the bottom of the diagram)
module hazard_unit (
input [4:0] rs1d,
input [4:0] rs2d,
input [4:0] rs1e,
input [4:0] rs2e,
input [4:0] rde,
input [4:0] rdm,
input [4:0] rdw,
input regwritem,
input regwritew,
input resultsrce0,      // resultsrce[0]=1 means the instruction in execute is a lw
input pcsrce,
output reg stallf,
output reg stalld,
output reg flushd,
output reg flushe,
output reg [1:0] forwardae,
output reg [1:0] forwardbe
);
reg lwstall;

// data forwarding (00 = from register file, 10 = from memory stage, 01 = from writeback)
always @(*) begin
forwardae=2'b00;
forwardbe=2'b00;
if(rs1e!=5'd0) begin
    if(regwritem && rs1e==rdm) forwardae=2'b10;
    else if(regwritew && rs1e==rdw) forwardae=2'b01;
end
if(rs2e!=5'd0) begin
    if(regwritem && rs2e==rdm) forwardbe=2'b10;
    else if(regwritew && rs2e==rdw) forwardbe=2'b01;
end
end

// load use stall, and flush when a branch / jump is taken
always @(*) begin
if(resultsrce0 && (rs1d==rde || rs2d==rde)) lwstall=1'b1;
else lwstall=1'b0;
stallf=lwstall;
stalld=lwstall;
flushd=pcsrce;
flushe=lwstall||pcsrce;
end
endmodule


module risc_v_pipe (
input clk,
input reset,
output reg [31:0] pc_out,
output reg [31:0] result_out
);
// ---------------- fetch ----------------
wire [31:0] w1;          // pcf
reg  [31:0] w2;          // pcf' (next pc)
wire [31:0] w3;          // instruction read from instruction memory
wire [31:0] pcplus4f;

// ---------------- fetch/decode register ----------------
reg  [31:0] w4;          // pcd
reg  [31:0] w5;          // instrd
reg  [31:0] pcplus4d;

// ---------------- decode ----------------
wire [31:0] RD1;
wire [31:0] RD2;
reg  [31:0] rd1d;        // RD1 after the writeback bypass
reg  [31:0] rd2d;
wire [31:0] w13;         // extimmd
wire regwrited;
wire [1:0] resultsrcd;
wire memwrited;
wire jumpd;
wire branchd;
wire [2:0] alucontrold;
wire alusrcd;
wire [1:0] immsrcd;

// ---------------- decode/execute register ----------------
reg  [31:0] w8;          // rd1e
reg  [31:0] below_w8;    // rd2e
reg  [31:0] pce;
reg  [31:0] w13e;        // extimme
reg  [31:0] pcplus4e;
reg  [4:0] rs1e;
reg  [4:0] rs2e;
reg  [4:0] rde;
reg regwritee;
reg [1:0] resultsrce;
reg memwritee;
reg jumpe;
reg branche;
reg [2:0] alucontrole;
reg alusrce;

// ---------------- execute ----------------
wire [1:0] forwardae;
wire [1:0] forwardbe;
reg  [31:0] w9;          // srcae
reg  [31:0] writedatae;
reg  [31:0] w14;         // srcbe
reg  [31:0] w10;         // aluresulte
reg zero;
reg pcsrce;
wire [31:0] pctargete;

// ---------------- execute/memory register ----------------
reg  [31:0] w11;         // aluresultm
reg  [31:0] writedatam;
reg  [31:0] pcplus4m;
reg  [4:0] rdm;
reg regwritem;
reg [1:0] resultsrcm;
reg memwritem;

// ---------------- memory ----------------
wire [31:0] w7;          // readdatam

// ---------------- memory/writeback register ----------------
reg  [31:0] w6;          // readdataw
reg  [31:0] w11w;        // aluresultw
reg  [31:0] pcplus4w;
reg  [4:0] rdw;
reg regwritew;
reg [1:0] resultsrcw;

// ---------------- writeback ----------------
reg  [31:0] w12;         // resultw

// ---------------- hazard unit outputs ----------------
wire stallf;
wire stalld;
wire flushd;
wire flushe;


// ================= fetch =================
assign pcplus4f=w1+32'd4;

always @(*) begin
if(pcsrce) w2=pctargete;
else w2=pcplus4f;
end

program_counter aee(w2,clk,~stallf,reset,w1);

inst_and_data_memory bee(w1,32'd0,clk,1'b0,w3);

always @(posedge clk) begin
if(reset||flushd) begin
w4<=32'd0;
w5<=32'd0;
pcplus4d<=32'd0;
end
else if(!stalld) begin
w4<=w1;
w5<=w3;
pcplus4d<=pcplus4f;
end
end


// ================= decode =================
wire [4:0]rs1 ={w5[19],w5[18],w5[17],w5[16],w5[15]};
wire [4:0]rs2={w5[24],w5[23],w5[22],w5[21],w5[20]};
wire [4:0] rd={w5[11],w5[10],w5[9],w5[8],w5[7]};

control_signals_p ctrl(w5,regwrited,resultsrcd,memwrited,jumpd,branchd,alucontrold,alusrcd,immsrcd);

register_file cee(rs1,rs2,rdw,w12,clk,regwritew,RD1,RD2);

// the register file writes at the clock edge, so if writeback is writing the
// register that decode is reading in the same cycle, take the value directly
always @(*) begin
if(regwritew && rdw!=5'd0 && rdw==rs1) rd1d=w12;
else rd1d=RD1;
if(regwritew && rdw!=5'd0 && rdw==rs2) rd2d=w12;
else rd2d=RD2;
end

extender dee(w5[31:7],immsrcd,w13);

hazard_unit hzd(rs1,rs2,rs1e,rs2e,rde,rdm,rdw,regwritem,regwritew,resultsrce[0],pcsrce,stallf,stalld,flushd,flushe,forwardae,forwardbe);

always @(posedge clk) begin
if(reset||flushe) begin
w8<=32'd0;
below_w8<=32'd0;
pce<=32'd0;
w13e<=32'd0;
pcplus4e<=32'd0;
rs1e<=5'd0;
rs2e<=5'd0;
rde<=5'd0;
regwritee<=1'b0;
resultsrce<=2'b00;
memwritee<=1'b0;
jumpe<=1'b0;
branche<=1'b0;
alucontrole<=3'b000;
alusrce<=1'b0;
end
else begin
w8<=rd1d;
below_w8<=rd2d;
pce<=w4;
w13e<=w13;
pcplus4e<=pcplus4d;
rs1e<=rs1;
rs2e<=rs2;
rde<=rd;
regwritee<=regwrited;
resultsrce<=resultsrcd;
memwritee<=memwrited;
jumpe<=jumpd;
branche<=branchd;
alucontrole<=alucontrold;
alusrce<=alusrcd;
end
end


// ================= execute =================
always @(*) begin
if(forwardae==2'b00) w9=w8;
else if(forwardae==2'b01) w9=w12;
else w9=w11;
end

always @(*) begin
if(forwardbe==2'b00) writedatae=below_w8;
else if(forwardbe==2'b01) writedatae=w12;
else writedatae=w11;
end

always @(*) begin
if(alusrce==1'b0) w14=writedatae;
else w14=w13e;
end

always @(*) begin
if(alucontrole==3'b000) w10=w9+w14;
else if(alucontrole==3'b001) w10=w9-w14;
else if(alucontrole==3'b010) w10=w9&w14;
else if(alucontrole==3'b011) w10=w9|w14;
else if(alucontrole==3'b101) begin
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

// zero flag
always @(*) begin
if(w10==32'd0) zero=1'b1;
else zero=1'b0;
end

assign pctargete=pce+w13e;

// pcsrce = (branche and zero) or jumpe
always @(*) begin
if((branche && zero) || jumpe) pcsrce=1'b1;
else pcsrce=1'b0;
end

always @(posedge clk) begin
if(reset) begin
w11<=32'd0;
writedatam<=32'd0;
pcplus4m<=32'd0;
rdm<=5'd0;
regwritem<=1'b0;
resultsrcm<=2'b00;
memwritem<=1'b0;
end
else begin
w11<=w10;
writedatam<=writedatae;
pcplus4m<=pcplus4e;
rdm<=rde;
regwritem<=regwritee;
resultsrcm<=resultsrce;
memwritem<=memwritee;
end
end


// ================= memory =================
inst_and_data_memory gee(w11,writedatam,clk,memwritem,w7);

always @(posedge clk) begin
if(reset) begin
w6<=32'd0;
w11w<=32'd0;
pcplus4w<=32'd0;
rdw<=5'd0;
regwritew<=1'b0;
resultsrcw<=2'b00;
end
else begin
w6<=w7;
w11w<=w11;
pcplus4w<=pcplus4m;
rdw<=rdm;
regwritew<=regwritem;
resultsrcw<=resultsrcm;
end
end


// ================= writeback =================
always @(*) begin
if(resultsrcw==2'b00) w12=w11w;
else if(resultsrcw==2'b01) w12=w6;
else w12=pcplus4w;
end

// outputs so that synthesis keeps the design
always @(*) begin
pc_out=w1;
result_out=w12;
end
endmodule
