// testbench.v — write your testbench here, or load one from Examples

`timescale 1ns/1ps
module testbench;
  reg clk = 0;
  integer errors = 0;
  reg reset = 1;
  wire [31:0] pc_out, result_out;
  risc_v dut(clk, reset, pc_out, result_out);
  always #5 clk = ~clk;

  // ---------------- program (loaded into instruction/data memory) ----------------
  initial begin
    dut.bee.mem[0]  = 32'h00500093;  // 00: addi x1,  x0, 5      x1  = 5
    dut.bee.mem[1]  = 32'h00700113;  // 04: addi x2,  x0, 7      x2  = 7
    dut.bee.mem[2]  = 32'h002081b3;  // 08: add  x3,  x1, x2     x3  = 12
    dut.bee.mem[3]  = 32'h04302023;  // 0c: sw   x3,  64(x0)     mem[0x40] = 12
    dut.bee.mem[4]  = 32'h04002203;  // 10: lw   x4,  64(x0)     x4  = 12
    dut.bee.mem[5]  = 32'h00418463;  // 14: beq  x3,  x4, +8     taken -> 0x1c
    dut.bee.mem[6]  = 32'h00100293;  // 18: addi x5,  x0, 1      SKIPPED
    dut.bee.mem[7]  = 32'h40118333;  // 1c: sub  x6,  x3, x1     x6  = 7
    dut.bee.mem[8]  = 32'h0020f433;  // 20: and  x8,  x1, x2     x8  = 5
    dut.bee.mem[9]  = 32'h0020e4b3;  // 24: or   x9,  x1, x2     x9  = 7
    dut.bee.mem[10] = 32'h0020a533;  // 28: slt  x10, x1, x2     x10 = 1
    dut.bee.mem[11] = 32'hffd00593;  // 2c: addi x11, x0, -3     x11 = -3
    dut.bee.mem[12] = 32'h008003ef;  // 30: jal  x7,  +8         x7  = 0x34, -> 0x38
    dut.bee.mem[13] = 32'h00900613;  // 34: addi x12, x0, 9      SKIPPED
    dut.bee.mem[14] = 32'h0000006f;  // 38: jal  x0,  0          halt (loops here)
  end

  task check(input [255:0] name, input [31:0] got, input [31:0] exp);
    begin
      if (got === exp) $display("PASS  %0s = %0d (0x%h)", name, $signed(got), got);
      else begin $display("FAIL  %0s : got 0x%h, expected 0x%h", name, got, exp); errors = errors + 1; end
    end
  endtask

  initial begin
    $dumpfile("wave.vcd"); $dumpvars(0, testbench);
    repeat (2) @(posedge clk);
    #1 reset = 0;                        // release reset after 2 clocks
    repeat (80) @(posedge clk);          // program needs ~48 cycles, then halts in a loop
    #1;
    check("x1  addi        ", dut.cee.rf[1],  32'd5);
    check("x2  addi        ", dut.cee.rf[2],  32'd7);
    check("x3  add         ", dut.cee.rf[3],  32'd12);
    check("x4  lw (sw->lw) ", dut.cee.rf[4],  32'd12);
    check("x6  sub         ", dut.cee.rf[6],  32'd7);
    check("x7  jal link    ", dut.cee.rf[7],  32'h34);
    check("x8  and         ", dut.cee.rf[8],  32'd5);
    check("x9  or          ", dut.cee.rf[9],  32'd7);
    check("x10 slt         ", dut.cee.rf[10], 32'd1);
    check("x11 addi neg    ", dut.cee.rf[11], 32'hFFFFFFFD);
    check("mem[0x40] sw    ", dut.bee.mem[16], 32'd12);
    check("pc  halt loop   ", dut.w1, 32'h38);
    if (dut.cee.rf[5]  === 32'd1) begin $display("FAIL  beq not taken (x5 written)");  errors = errors + 1; end
    else $display("PASS  beq taken, x5 not written");
    if (dut.cee.rf[12] === 32'd9) begin $display("FAIL  jal not taken (x12 written)"); errors = errors + 1; end
    else $display("PASS  jal taken, x12 not written");
    if (errors == 0) $display("\n*** ALL TESTS PASSED ***"); else $display("\n*** %0d TEST(S) FAILED ***", errors);
    $finish;
  end
endmodule