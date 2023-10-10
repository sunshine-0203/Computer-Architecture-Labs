`timescale 1ns / 1ps
//  功能说明
//  算数�?算和逻辑�?算功能部件
// 输入
// op1               第一个�?作数
// op2               第二个�?作数
// ALU_func          �?算类型
// 输出
// ALU_out           �?算结果
// 实验�?求
// 补全模�?�

`include "Parameters.v"

module ALU (
    input  wire [31:0] op1,
    input  wire [31:0] op2,
    input  wire [ 3:0] ALU_func,
    output reg  [31:0] ALU_out
);

  // TODO                   : Complete this module

  always @(*) begin
    case (ALU_func)
      `ADD:  ALU_out = op1 + op2;
      `SUB:  ALU_out = op1 - op2;
      `SLL:  ALU_out = op1 << op2[4:0];
      `SLTU: ALU_out = (op1 < op2) ? 32'd1 : 32'd0;
      `SLT:  ALU_out = ($signed(op1) < $signed(op2)) ? 32'd1 : 32'd0;
      `SRL:  ALU_out = op1 >> op2[4:0];
      `SRA:  ALU_out = ($signed(op1)) >>> op2[4:0];
      `LUI:  ALU_out = op2;
      `XOR:  ALU_out = op1 ^ op2;
      `OR:   ALU_out = op1 | op2;
      `AND:  ALU_out = op1 & op2;
      `OP1:  ALU_out = op1;
      `OP2:  ALU_out = ~op1 & op2;
      /* FIXME          : Write your code here... */

      default: ALU_out = 32'b0;
    endcase
  end
endmodule

