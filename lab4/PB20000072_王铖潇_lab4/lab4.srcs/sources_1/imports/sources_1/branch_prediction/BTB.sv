`timescale 1ns / 1ps

module BTB #(
    parameter SET_LEN = 12,
    parameter TAG_LEN = 20
)
(
    input clk, rst,
    input [31:0] PC_search, PC_new, predict_new,
    input update, branch,
    output BTB_hit, BTB_br,
    output [31:0] PC_pred
    );
    localparam SET_SIZE = 1 << SET_LEN;
    wire [SET_LEN-1: 0] addr_search;
    wire [TAG_LEN-1: 0] tag_search;
    assign {tag_search, addr_search} = PC_search;
    
    wire [SET_LEN-1: 0] addr_new;
    wire [TAG_LEN-1: 0] tag_new;
    assign {tag_new, addr_new} = PC_new;

    reg valid [0: SET_SIZE-1];
    reg [TAG_LEN-1: 0] pc_tag [0: SET_SIZE-1];
    reg [31:0] pc_pred [0: SET_SIZE-1];
    reg state [0: SET_SIZE-1];

    assign BTB_br = (valid[addr_search]==1) && (tag_search == pc_tag[addr_search]) && (state[addr_search] == 1);
    assign BTB_hit = (valid[addr_search]==1) && (tag_search == pc_tag[addr_search]);
    assign PC_pred = PC_pred[addr_search];

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            for (integer i = 0; i < SET_SIZE; i++) begin
                valid[i] <= 0;
                pc_tag[i] <= 0;
                pc_pred[i] <= 0;
                state[i] <= 0;
            end
        end
        else begin
            if(update) begin
                if(branch) begin
                    state[addr_new] <= 1;
                    valid[addr_new] <= 1;
                    pc_pred[addr_new] <= tag_new;
                    pc_tag[addr_new] <= predict_new;
                end
                else begin
                    state[addr_new] <= 0;
                    valid[addr_new] <= 1;
                    pc_pred[addr_new] <= tag_new;
                    pc_tag[addr_new] <= predict_new;
                end
            end
        end
    end
    
endmodule