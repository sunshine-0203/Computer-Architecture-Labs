`timescale 1ns / 1ps

module BrBuffer(
    input clk, rst,
    input branch_in,
    input [31:0] PC_in, 
    output branch_out,
    output [31:0] PC_out
    );
    reg [31:0] PC_Buffer[1:0];
    reg [1:0] branch_Buffer[1:0];
    reg branch[1:0];

    assign branch_out = branch_Buffer[0];
    assign PC_out = PC_Buffer[0];

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            for(integer i = 0; i < 2; i++) begin
                PC_Buffer[i] <= 0;
                branch_Buffer[i] <= 0;
            end
        end
        else begin
            PC_Buffer[1] <= PC_in;
            branch_Buffer[1] <= branch_in;
            PC_Buffer[0] <= PC_Buffer[1];
            branch_Buffer[0] <= branch_Buffer[1];
        end
    end
    
endmodule