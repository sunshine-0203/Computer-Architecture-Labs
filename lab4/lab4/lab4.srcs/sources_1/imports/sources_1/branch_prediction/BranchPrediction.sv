`timescale 1ns / 1ps
`include "../imports/imports/PART-code/Parameters.v"
module BranchPrediction # (
    parameter SET_LEN = 12,
    parameter TAG_LEN = 20,
    parameter STRATEGY = `BHT
)
(
    input clk, rst,
    input [31:0] PC_search, PC_new, br_target,
    input is_br_type, branch,
    output reg branch_prediction_miss,
    output reg [31:0] NPC
    );

    wire [31:0] PC_4;
    assign PC_4 = PC_search + 4;

    wire BTB1_hit, BTB1_br, BTB2_hit, BTB2_br, BHT2_br; 
    wire [31:0] PC_pred_in1;
    wire [31:0] PC_pred_in2;
    BTB #(
        .SET_LEN(SET_LEN),
        .TAG_LEN(TAG_LEN)
    ) BTB1 (
        .clk(clk),
        .rst(rst),
        .PC_search(PC_search),
        .PC_new(PC_new),
        .predict_new(br_target),
        .update(is_br_type),
        .branch(branch),
        .BTB_hit(BTB1_hit),
        .BTB_br(BTB1_br),
        .PC_pred(PC_pred_in1)
    );

    BTB #(
        .SET_LEN(SET_LEN),
        .TAG_LEN(TAG_LEN)
    ) BTB2 (
        .clk(clk),
        .rst(rst),
        .PC_search(PC_search),
        .PC_new(PC_new),
        .predict_new(br_target),
        .update(is_br_type),
        .branch(branch),
        .BTB_hit(BTB2_hit),
        .BTB_br(BTB2_br),
        .PC_pred(PC_pred_in2)
    );

    BHT #(
        .SET_LEN(SET_LEN),
        .TAG_LEN(TAG_LEN)
    ) BHT2 (
        .clk(clk),
        .rst(rst),
        .PC_search(PC_search),
        .PC_new(PC_new),
        .update(is_br_type),
        .branch(branch),
        .BHT_br(BHT2_br)
    );

    wire branch_in;
    wire [31:0] PC_pred_in;

    assign branch_in = (STRATEGY == `BTB) ? BTB1_br : (BTB2_hit & BHT2_br);
    assign PC_pred_in = (STRATEGY == `BTB) ? PC_pred_in1 : PC_pred_in2;
    
    wire branch_out;
    wire [31:0] PC_out;
    BrBuffer BrBuffer1 (
        .clk(clk),
        .rst(rst),
        .branch_in(branch_in),
        .branch_out(branch_out),
        .PC_in(PC_4),
        .PC_out(PC_out)
    );
    always @(*) begin
        if(~is_br_type) begin
            NPC = branch_in ?  PC_pred_in: PC_4;
            branch_prediction_miss = 0;
        end
        else begin
            if(branch == branch_out) begin
                NPC = branch_in ?  PC_pred_in: PC_4;
                branch_prediction_miss = 0;
            end
            else begin
                // fail : go back
                NPC = branch ? br_target : PC_out;
                branch_prediction_miss = 1;
            end
        end
    end

    reg [31:0] br_count;
    reg [31:0] pred_success;
    reg [31:0] pred_fail;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            br_count <= 0;
            pred_success <= 0;
            pred_fail <= 0;
        end
        else begin
            if(is_br_type) begin
                br_count <= br_count + 1;
                if(branch == branch_out) begin
                    pred_success <= pred_success + 1;
                end
                else begin
                    pred_fail <= pred_fail + 1;
                end
            end
        end
    end
endmodule