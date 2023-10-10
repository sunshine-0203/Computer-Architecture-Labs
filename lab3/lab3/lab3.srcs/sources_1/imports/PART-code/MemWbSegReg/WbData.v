//`timescale 1ns / 1ps
////  功能说明
//    // MEM\WB的写回寄存器内容
//    // 为了数据同步，Data Extension和Data Cache集成在其中
//// 输入
//    // clk               时钟信号
//    // wb_select         选择写回寄存器的数据：如果为0，写回ALU计算结果，如果为1，写回Memory读取的内容
//    // load_type         load指令类型
//    // write_en          Data Cache写使能
//    // debug_write_en    Data Cache debug写使能
//    // addr              Data Cache的写地址，也是ALU的计算结果
//    // debug_addr        Data Cache的debug写地址
//    // in_data           Data Cache的写入数据
//    // debug_in_data     Data Cache的debug写入数据
//    // bubbleW           WB阶段的bubble信号
//    // flushW            WB阶段的flush信号
//// 输出
//    // debug_out_data    Data Cache的debug读出数据
//    // data_WB           传给下一流水段的写回寄存器内容
//// 实验要求  
//    // 无需修改

//`include "D:\experiment_Vivado\Grade3_spring\Lab3\lab3\lab3.srcs\sources_1\imports\PART-code\Parameters.v"
//module WB_Data_WB(
//    input wire clk, rst, bubbleW, flushW,
//    input wire wb_select,
//    input wire [2:0] load_type,
//    input  [3:0] write_en, debug_write_en,
//    input  [31:0] addr,
//    input  [31:0] debug_addr,
//    input  [31:0] in_data, debug_in_data,
//    output wire [31:0] debug_out_data,
//    output wire [31:0] data_WB,
//    output wire cache_miss
//    );

//    wire [31:0] data_raw;
//    wire [31:0] data_WB_raw;

//    reg  [31:0] miss_count;
//    reg  [31:0] hit_count;

//    // DataCache DataCache1(
//    //     .clk(clk),
//    //     .write_en(write_en << addr[1:0]),
//    //     .debug_write_en(debug_write_en),
//    //     .addr(addr[31:2]),
//    //     .debug_addr(debug_addr[31:2]),
//    //     .in_data(in_data << (8 * addr[1:0])),
//    //     .debug_in_data(debug_in_data),
//    //     .out_data(data_raw),
//    //     .debug_out_data(debug_out_data)
//    // );
//    cache #(
//        .LINE_ADDR_LEN(3),
//        .SET_ADDR_LEN(3),
//        .TAG_ADDR_LEN(6),
//        .WAY_CNT(1),
//        .STRATEGY(`LRU)
//    ) Cache1(
//        .clk(clk),
//        .rst(rst),
//        .addr(addr),
//        .rd_req(wb_select),
//        .wr_req(write_en),
//        .wr_data(in_data),
//        .miss(cache_miss),
//        .rd_data(data_raw)
//    );
    
//    // Add flush and bubble support
//    // if chip not enabled, output output last read result
//    // else if chip clear, output 0
//    // else output values from cache

//    reg bubble_ff = 1'b0;
//    reg flush_ff = 1'b0;
//    reg wb_select_old = 0;
//    reg [31:0] data_WB_old = 32'b0;
//    reg [31:0] addr_old;
//    reg [2:0] load_type_old;

//    DataExtend DataExtend1(
//        .data(data_raw),
//        .addr(addr_old[1:0]),
//        .load_type(load_type_old),
//        .dealt_data(data_WB_raw)
//    );

//    always@(posedge clk)
//    begin
//        bubble_ff <= bubbleW;
//        flush_ff <= flushW;
//        data_WB_old <= data_WB;
//        addr_old <= addr;
//        wb_select_old <= wb_select;
//        load_type_old <= load_type;
//    end

//    assign data_WB = bubble_ff ? data_WB_old :
//                                 (flush_ff ? 32'b0 : 
//                                             (wb_select_old ? data_WB_raw : addr_old));
//    always @(posedge clk or posedge rst) begin
//        if(rst) begin
//            hit_count <= 0;
//            miss_count <= 0;
//        end
//        else begin
//            if((wb_select || write_en != 0) && bubble_ff == 0) begin
//                if(cache_miss) miss_count <= miss_count + 1;
//                else hit_count <= hit_count + 1;
//            end
//        end
//    end                                                      

//endmodule
`timescale 1ns / 1ps
//  功能说明
    // MEM\WB的写回寄存器内容
    // 为了数据同步，Data Extension和Data Cache集成在其�??
// 输入
    // clk               时钟信号
    // wb_select         选择写回寄存器的数据：如果为0，写回ALU计算结果，如果为1，写回Memory读取的内�??
    // load_type         load指令类型
    // write_en          Data Cache写使�??
    // debug_write_en    Data Cache debug写使�??
    // addr              Data Cache的写地址，也是ALU的计算结�??
    // debug_addr        Data Cache的debug写地�??
    // in_data           Data Cache的写入数�??
    // debug_in_data     Data Cache的debug写入数据
    // bubbleW           WB阶段的bubble信号
    // flushW            WB阶段的flush信号
// 输出
    // debug_out_data    Data Cache的debug读出数据
    // data_WB           传给下一流水段的写回寄存器内�??
// 实验要求  
    // 无需修改

module WB_Data_WB(
    input wire clk, rst, bubbleW, flushW,
    input wire wb_select,
    input wire [2:0] load_type,
    input  [3:0] write_en, debug_write_en,
    input  [31:0] addr,
    input  [31:0] debug_addr,
    input  [31:0] in_data, debug_in_data,
    output wire [31:0] debug_out_data,
    output wire [31:0] data_WB,
    output wire cache_miss
    );

    wire [31:0] data_raw;
    wire [31:0] data_WB_raw;
    reg [31:0] miss_cnt, hit_cnt;

    cache #(
        .LINE_ADDR_LEN  ( 3          ),
        .SET_ADDR_LEN   ( 3          ),
        .TAG_ADDR_LEN   ( 6          ),
        .WAY_CNT        ( 2          ),
        .STRATEGY       ( `FIFO     )
    ) cache_test_instance (
        .clk            ( clk        ),
        .rst            ( rst        ),
        .miss           ( cache_miss ),
        .addr           ( addr       ),
        .rd_req         ( wb_select  ),
        .rd_data        ( data_raw   ),
        .wr_req         ( write_en   ),
        .wr_data        ( in_data    )
    );

    // Add flush and bubble support
    // if chip not enabled, output output last read result
    // else if chip clear, output 0
    // else output values from cache

    reg bubble_ff = 1'b0;
    reg flush_ff = 1'b0;
    reg wb_select_old = 0;
    reg [31:0] data_WB_old = 32'b0;
    reg [31:0] addr_old;
    reg [2:0] load_type_old;

    DataExtend DataExtend1(
        .data(data_raw),
        .addr(addr_old[1:0]),
        .load_type(load_type_old),
        .dealt_data(data_WB_raw)
    );

    always@(posedge clk)
    begin
        bubble_ff <= bubbleW;
        flush_ff <= flushW;
        data_WB_old <= data_WB;
        addr_old <= addr;
        wb_select_old <= wb_select;
        load_type_old <= load_type;
    end

    assign data_WB = bubble_ff ? data_WB_old :
                                 (flush_ff ? 32'b0 : 
                                             (wb_select_old ? data_WB_raw :
                                                          addr_old));

    always@(posedge clk or posedge rst) begin
        if(rst) begin
            hit_cnt <= 0;
            miss_cnt <= 0;
        end
        else if(bubble_ff == 0 && (wb_select == 1 || write_en == 4'b1111)) begin
            if(cache_miss)
                miss_cnt <= miss_cnt + 1;
            else
                hit_cnt <= hit_cnt + 1;
        end
    end

endmodule