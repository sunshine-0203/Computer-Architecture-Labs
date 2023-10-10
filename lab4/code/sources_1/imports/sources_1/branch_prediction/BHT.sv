`timescale 1ns / 1ps

module BHT #(
    parameter SET_LEN = 12,
    parameter TAG_LEN = 20
)
(
    input clk, rst,
    input [31:0] PC_search, PC_new,
    input update, branch,
    output BHT_br
    );
    localparam SET_SIZE = 1 << SET_LEN;
    wire [SET_LEN-1: 0] addr_search;
    wire [TAG_LEN-1: 0] tag_search;
    assign {tag_search, addr_search} = PC_search;
    
    wire [SET_LEN-1: 0] addr_new;
    wire [TAG_LEN-1: 0] tag_new;
    assign {tag_new, addr_new} = PC_new;

    reg [1:0] state [0: SET_SIZE-1];

    assign BHT_br = (state[addr_search] >= 2'b10);

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            for (integer i = 0; i < SET_SIZE; i++) begin
                state[i] <= 0;
            end
        end
        else begin
            if(update) begin
                if(branch) begin
                    if(state[addr_new] != 2'b11)
                        state[addr_new] <= state[addr_new] + 1;
                    else 
                        state[addr_new] <= state[addr_new];
                end
                else begin
                    if(state[addr_new] != 0)
                        state[addr_new] <= state[addr_new] - 1;
                    else 
                        state[addr_new] <= state[addr_new];
                end
            end
        end
    end
    
endmodule