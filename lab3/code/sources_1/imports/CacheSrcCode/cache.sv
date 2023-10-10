
`include "D:\experiment_Vivado\Grade3_spring\Lab3\lab3\lab3.srcs\sources_1\imports\PART-code\Parameters.v"
module cache #(
    parameter  LINE_ADDR_LEN = 2, // line内地址长度，决定了每个line具有2^3个word
    parameter  SET_ADDR_LEN  = 3, // 组地址长度，决定了一共有2^3=8组
    parameter  TAG_ADDR_LEN  = 7, // tag长度
    parameter  WAY_CNT       = 4,  // 组相连度，决定了每组中有多少路line，这里是直接映射型cache，因此该参数没用到
    parameter  STRATEGY      = `FIFO
)(
    input  clk, rst,
    output miss,               // 对CPU发出的miss信号
    input  [31:0] addr,        // 读写请求地址
    input  rd_req,             // 读请求信号
    output reg [31:0] rd_data, // 读出的数据，一次读一个word
    input  wr_req,             // 写请求信号
    input  [31:0] wr_data      // 要写入的数据，一次写一个word
);

localparam MEM_ADDR_LEN    = TAG_ADDR_LEN + SET_ADDR_LEN ; // 计算主存地址长度 MEM_ADDR_LEN，主存大小=2^MEM_ADDR_LEN个line
localparam UNUSED_ADDR_LEN = 32 - TAG_ADDR_LEN - SET_ADDR_LEN - LINE_ADDR_LEN - 2 ;       // 计算未使用的地址的长度

localparam LINE_SIZE       = 1 << LINE_ADDR_LEN  ;         // 计算 line 中 word 的数量，即 2^LINE_ADDR_LEN 个word 每 line
localparam SET_SIZE        = 1 << SET_ADDR_LEN   ;         // 计算一共有多少组，即 2^SET_ADDR_LEN 个组

reg [            31:0] cache_mem    [SET_SIZE][WAY_CNT][LINE_SIZE]; // SET_SIZE个line，每个line有LINE_SIZE个word
reg [TAG_ADDR_LEN-1:0] cache_tags   [SET_SIZE][WAY_CNT];            // SET_SIZE个TAG
reg                    valid        [SET_SIZE][WAY_CNT];            // SET_SIZE个valid(有效位)
reg                    dirty        [SET_SIZE][WAY_CNT];            // SET_SIZE个dirty(脏位)

wire [              2-1:0]   word_addr;                   // 将输入地址addr拆分成这5个部分
wire [  LINE_ADDR_LEN-1:0]   line_addr;
wire [   SET_ADDR_LEN-1:0]    set_addr;
reg  [        WAY_CNT-1:0]    way_addr;
wire [   TAG_ADDR_LEN-1:0]    tag_addr;
wire [UNUSED_ADDR_LEN-1:0] unused_addr;

enum  {IDLE, SWAP_OUT, SWAP_IN, SWAP_IN_OK} cache_stat;    // cache 状态机的状态定义
                                                           // IDLE代表就绪，SWAP_OUT代表正在换出，SWAP_IN代表正在换入，SWAP_IN_OK代表换入后进行一周期的写入cache操作。

reg  [   SET_ADDR_LEN-1:0] mem_rd_set_addr = 0;
reg  [   TAG_ADDR_LEN-1:0] mem_rd_tag_addr = 0;
wire [   MEM_ADDR_LEN-1:0] mem_rd_addr = {mem_rd_tag_addr, mem_rd_set_addr};
reg  [   MEM_ADDR_LEN-1:0] mem_wr_addr = 0;

reg  [31:0] mem_wr_line [LINE_SIZE];
wire [31:0] mem_rd_line [LINE_SIZE];

wire mem_gnt;      // 主存响应读写的握手信号

assign {unused_addr, tag_addr, set_addr, line_addr, word_addr} = addr;  // 拆分 32bit ADDR

reg cache_hit = 1'b0;
reg strategy;
reg [WAY_CNT:0] fifo [SET_SIZE][WAY_CNT];
reg [WAY_CNT:0] lru [SET_SIZE][WAY_CNT];
reg lru_vec [SET_SIZE][WAY_CNT];

always @ (*) begin              // 判断 输入的address 是否在 cache 中命中
    cache_hit = 1'b0;
    for (integer i = 0; i < WAY_CNT; i++) begin
        if(valid[set_addr][i] && cache_tags[set_addr][i] == tag_addr) begin  // 如果 cache line有效，并且tag与输入地址中的tag相等，则命中
            cache_hit = 1'b1;
            way_addr = i;
            break;
        end
    end
    if(~cache_hit) begin
        if(strategy == `FIFO) begin
            way_addr = fifo[set_addr][WAY_CNT - 1];
        end
        else begin
            for (integer i = 0; i< WAY_CNT; i++) begin
                if(lru[set_addr][i] == 0) begin
                    way_addr = i;
                    break;
                end
            end
        end
    end
end


// reg [SET_SIZE-1:0] way_addr;


always @ (posedge clk or posedge rst) begin     // ?? cache ???
    if(rst) begin
        cache_stat <= IDLE;
        strategy   <= STRATEGY;
        // for(integer i = 0; i < WAY_CNT; i++) begin
        //     fifo[i] <= i;
        // end
        // for(integer i = 0; i < WAY_CNT; i++) begin
        //     lru_vec[set_addr][i] <= 0;
        //     for(integer j = 0; j < WAY_CNT; j++) begin
        //         lru[set_addr][i][j] <= 0;
        //     end
        // end
        for(integer i = 0; i < SET_SIZE; i++) begin
            for(integer j = 0; j < WAY_CNT; j++) begin
                dirty[i][j] = 1'b0;
                valid[i][j] = 1'b0;
                fifo[i][j]  <= j;
                lru[i][j]   <= j;
            end
        end
        for(integer k = 0; k < LINE_SIZE; k++)
            mem_wr_line[k] <= 0;
        mem_wr_addr <= 0;
        {mem_rd_tag_addr, mem_rd_set_addr} <= 0;
        rd_data <= 0;
    end else begin
        case(cache_stat)
        IDLE:       begin
                        if(cache_hit) begin
                            if(rd_req) begin    // 如果cache命中，并且是读请求，
                                rd_data <= cache_mem[set_addr][way_addr][line_addr];   //则直接从cache中取出要读的数据
                            end else if(wr_req) begin // 如果cache命中，并且是写请求，
                                cache_mem[set_addr][way_addr][line_addr] <= wr_data;   // 则直接向cache中写入数据
                                dirty[set_addr][way_addr] <= 1'b1;                     // 写数据的同时置脏位
                            end 
                            if(rd_req | wr_req)
                                for(integer i = 0; i < WAY_CNT; i++) begin
                                    if(way_addr != i) begin
                                        if(lru[set_addr][i] > lru[set_addr][way_addr])
                                        lru[set_addr][i] <= lru[set_addr][i] - 1;
                                    end
                                    else 
                                    lru[set_addr][i] <= WAY_CNT - 1;
                                end
                            // for (integer i = 0; i < WAY_CNT; i++) begin
                            //     lru_vec[set_addr][i] <= 0;
                            //     for(integer j = 0; j < WAY_CNT; j++) begin
                            //         lru_vec[set_addr][i] <= lru_vec[set_addr][i] | lru[set_addr][i][j];
                            //     end
                            // end
                        end else begin
                            if(wr_req | rd_req) begin   // 如果 cache 未命中，并且有读写请求，则需要进行换入
                                if(valid[set_addr][way_addr] & dirty[set_addr][way_addr]) begin    // 如果 要换入的cache line 本来有效，且脏，则需要先将它换出
                                    cache_stat  <= SWAP_OUT;
                                    mem_wr_addr <= {cache_tags[set_addr][way_addr], set_addr};
                                    mem_wr_line <= cache_mem[set_addr][way_addr];
                                end else begin                                   // 反之，不需要换出，直接换入
                                    cache_stat  <= SWAP_IN;
                                end
                                {mem_rd_tag_addr, mem_rd_set_addr} <= {tag_addr, set_addr};
                            end
                        end
                    end
        SWAP_OUT:   begin
                        if(mem_gnt) begin           // 如果主存握手信号有效，说明换出成功，跳到下一状态
                            cache_stat <= SWAP_IN;
                        end
                    end
        SWAP_IN:    begin
                        if(mem_gnt) begin           // 如果主存握手信号有效，说明换入成功，跳到下一状态
                            cache_stat <= SWAP_IN_OK;
                        end
                    end
        SWAP_IN_OK: begin           // 上一个周期换入成功，这周期将主存读出的line写入cache，并更新tag，置高valid，置低dirty
                        for(integer i=0; i<LINE_SIZE; i++)  cache_mem[mem_rd_set_addr][way_addr][i] <= mem_rd_line[i];
                        cache_tags[mem_rd_set_addr][way_addr] <= mem_rd_tag_addr;
                        valid     [mem_rd_set_addr][way_addr] <= 1'b1;
                        dirty     [mem_rd_set_addr][way_addr] <= 1'b0;
                        for (integer i = WAY_CNT - 1; i > 0; i--) begin
                            fifo[set_addr][i] = fifo[set_addr][i-1];
                        end
                        fifo[set_addr][0] = way_addr;
                        for(integer i = 0; i < WAY_CNT; i++) begin
                            if(lru[set_addr][i] > lru[set_addr][way_addr]) begin
                                lru[set_addr][i] <= lru[set_addr][i] - 1;
                            end
                        end
                        lru[set_addr][way_addr] <= WAY_CNT - 1;
                        cache_stat <= IDLE;        // 回到就绪状态
                    end
        endcase
    end
end

wire mem_rd_req = (cache_stat == SWAP_IN );
wire mem_wr_req = (cache_stat == SWAP_OUT);
wire [   MEM_ADDR_LEN-1 :0] mem_addr = mem_rd_req ? mem_rd_addr : ( mem_wr_req ? mem_wr_addr : 0);

assign miss = (rd_req | wr_req) & ~(cache_hit && cache_stat==IDLE) ;     // 当 有读写请求时，如果cache不处于就绪(IDLE)状态，或者未命中，则miss=1

main_mem #(     // 主存，每次读写以line 为单位
    .LINE_ADDR_LEN  ( LINE_ADDR_LEN          ),
    .ADDR_LEN       ( MEM_ADDR_LEN           )
) main_mem_instance (
    .clk            ( clk                    ),
    .rst            ( rst                    ),
    .gnt            ( mem_gnt                ),
    .addr           ( mem_addr               ),
    .rd_req         ( mem_rd_req             ),
    .rd_line        ( mem_rd_line            ),
    .wr_req         ( mem_wr_req             ),
    .wr_line        ( mem_wr_line            )
);

endmodule





// `include "D:\experiment_Vivado\Grade3_spring\Lab3\lab3\lab3.srcs\sources_1\imports\PART-code\Parameters.v"
// module cache #(
//     parameter  LINE_ADDR_LEN = 3, // line鍐呭湴锟�??�?垮害锛屽喅�?�氫簡姣忎釜line鍏锋�?2^3涓獁ord
//     parameter  SET_ADDR_LEN  = 3, // 缁勫湴锟�??�?垮害锛屽喅�?�氫簡锟�??鍏辨�?2^3=8锟�?
//     parameter  TAG_ADDR_LEN  = 6, // tag�?垮害
//     parameter  WAY_CNT       = 3, // 缁勭浉杩炲害锛屽喅�?�氫簡姣忕粍涓湁澶氬皯璺痩ine锛岃繖閲屾槸鐩存帴鏄犲皠鍨媍ache锛屽洜姝よ鍙傛暟娌＄敤锟�?
//     parameter  STRATEGY      = `LRU  // 0琛ㄧずFIFO绛栫暐锛�?1琛ㄧずLRU绛栫�?
// )(
//     input  clk, rst,
//     output miss,               // 瀵笴PU鍙戝嚭鐨刴iss淇�?�彿
//     input  [31:0] addr,        // 璇诲啓璇锋眰鍦板�?
//     input  rd_req,             // 璇昏姹備俊锟�?
//     output reg [31:0] rd_data, // 璇诲嚭鐨勬暟鎹紝锟�??娆¤锟�?涓獁ord
//     input  wr_req,             // 鍐欒姹備俊锟�?
//     input  [31:0] wr_data      // 瑕佸啓鍏ョ殑鏁版嵁锛屼竴娆�?�啓锟�?涓獁ord
// );

// localparam MEM_ADDR_LEN    = TAG_ADDR_LEN + SET_ADDR_LEN ; // 璁＄畻涓诲瓨鍦板潃闀垮害 MEM_ADDR_LEN锛屼富�?�樺ぇ锟�??=2^MEM_ADDR_LEN涓猯ine
// localparam UNUSED_ADDR_LEN = 32 - TAG_ADDR_LEN - SET_ADDR_LEN - LINE_ADDR_LEN - 2 ;       // 璁＄畻鏈娇鐢ㄧ殑鍦板潃鐨勯暱锟�??

// localparam LINE_SIZE       = 1 << LINE_ADDR_LEN  ;         // 璁＄�? line 锟�? word 鐨勬暟閲忥紝锟�? 2^LINE_ADDR_LEN 涓獁ord 锟�? line
// localparam SET_SIZE        = 1 << SET_ADDR_LEN   ;         // 璁＄畻锟�??鍏辨湁澶氬皯缁勶紝锟�?? 2^SET_ADDR_LEN 涓�?

// reg [            31:0] cache_mem    [SET_SIZE][WAY_CNT][LINE_SIZE]; // SET_SIZE涓猯ine锛屾瘡涓猯ine鏈塋INE_SIZE涓獁ord
// reg [TAG_ADDR_LEN-1:0] cache_tags   [SET_SIZE][WAY_CNT];            // SET_SIZE涓猅AG
// reg                    valid        [SET_SIZE][WAY_CNT];            // SET_SIZE涓獀alid(鏈夋晥锟�??)
// reg                    dirty        [SET_SIZE][WAY_CNT];            // SET_SIZE涓猟irty(鑴忎�?)

// wire [              2-1:0]   word_addr;                   // 灏嗚緭鍏ュ湴锟�?addr鎷嗗垎鎴愯繖5涓儴锟�??
// wire [  LINE_ADDR_LEN-1:0]   line_addr;
// wire [   SET_ADDR_LEN-1:0]    set_addr;
// wire [   TAG_ADDR_LEN-1:0]    tag_addr;
// wire [UNUSED_ADDR_LEN-1:0] unused_addr;

// enum  {IDLE, SWAP_OUT, SWAP_IN, SWAP_IN_OK} cache_stat;    // cache 鐘讹�??锟芥�?鐨勭姸鎬佸畾锟�?
//                                                            // IDLE浠ｈ〃灏辩华锛孲WAP_OUT浠ｈ〃姝ｅ湪鎹㈠嚭锛孲WAP_IN浠ｈ〃姝ｅ湪鎹㈠叆锛孲WAP_IN_OK浠ｈ〃鎹㈠叆鍚庤繘琛屼竴鍛ㄦ湡鐨勫啓鍏ache鎿嶄綔锟�??

// reg  [   SET_ADDR_LEN-1:0] mem_rd_set_addr = 0;
// reg  [   TAG_ADDR_LEN-1:0] mem_rd_tag_addr = 0;
// wire [   MEM_ADDR_LEN-1:0] mem_rd_addr = {mem_rd_tag_addr, mem_rd_set_addr};
// reg  [   MEM_ADDR_LEN-1:0] mem_wr_addr = 0;

// reg  [31:0] mem_wr_line [LINE_SIZE];
// wire [31:0] mem_rd_line [LINE_SIZE];

// wire mem_gnt;      // 涓诲瓨鍝嶅簲璇诲啓鐨勬彙鎵嬩俊锟�??

// assign {unused_addr, tag_addr, set_addr, line_addr, word_addr} = addr;  // 鎷嗗�? 32bit ADDR

// reg cache_hit = 1'b0;

// reg [WAY_CNT:0] hit_way;
// reg [WAY_CNT:0] out_way;
// reg [WAY_CNT:0] lru_r[SET_SIZE][WAY_CNT];
// reg [WAY_CNT:0] fifo_r[SET_SIZE];
// reg swap_strategy;

// always @ (*) begin              // 鍒ゆ�? 杈撳叆鐨刟ddress 鏄惁锟�?? cache 涓懡锟�??
//     cache_hit = 1'b0;
//     for(integer i = 0; i < WAY_CNT; i++) begin
//         if(valid[set_addr][i] && cache_tags[set_addr][i] == tag_addr) begin   // 濡傛�? cache line鏈夋晥锛屽苟涓攖ag涓庤緭鍏ュ湴锟�?涓殑tag鐩哥瓑锛屽垯鍛戒�?
//             cache_hit = 1'b1;
//             hit_way = i;
//             break;
//         end
//     end
// end

// always @ (*) begin
//     if(~cache_hit && (wr_req | rd_req)) begin
//         if(swap_strategy == `LRU) begin
//             for(integer i = 0; i < WAY_CNT; i++) begin
//                 if(lru_r[set_addr][i] == 0) begin
//                     out_way = i;
//                     break;
//                 end
//             end
//         end
//         else if(swap_strategy == `FIFO) begin
//             out_way = fifo_r[set_addr];
//         end
//     end
// end

// always @ (posedge clk or posedge rst) begin     // ?? cache ???
//     if(rst) begin
//         cache_stat <= IDLE;
//         swap_strategy <= STRATEGY;
//         for(integer i = 0; i < SET_SIZE; i++) begin
//             fifo_r[i] <= 0;
//             for(integer j = 0; j < WAY_CNT; j++) begin
//                 dirty[i][j] = 1'b0;
//                 valid[i][j] = 1'b0;
//                 lru_r[i][j] = j;
//             end
//         end
//         for(integer k = 0; k < LINE_SIZE; k++)
//             mem_wr_line[k] <= 0;
//         mem_wr_addr <= 0;
//         {mem_rd_tag_addr, mem_rd_set_addr} <= 0;
//         rd_data <= 0;
//     end else begin
//         case(cache_stat)
//         IDLE:       begin
//                         if(cache_hit) begin
//                             if(rd_req) begin    // 濡傛灉cache鍛戒腑锛屽苟涓旀槸璇昏姹傦�?
//                                 rd_data <= cache_mem[set_addr][hit_way][line_addr];   //鍒欑洿鎺ヤ粠cache涓彇鍑鸿璇荤殑鏁版嵁
//                             end else if(wr_req) begin // 濡傛灉cache鍛戒腑锛屽苟涓旀槸鍐欒姹傦�?
//                                 cache_mem[set_addr][hit_way][line_addr] <= wr_data;   // 鍒欑洿鎺ュ悜cache涓啓鍏ユ暟锟�?
//                                 dirty[set_addr][hit_way] <= 1'b1;                     // 鍐欐暟鎹殑鍚屾椂缃剰锟�?
//                             end 
//                             for(integer i = 0; i < WAY_CNT; i++) begin
//                                 if(lru_r[set_addr][i] > lru_r[set_addr][hit_way]) begin
//                                     lru_r[set_addr][i] <= lru_r[set_addr][i] - 1;
//                                 end
//                             end
//                             lru_r[set_addr][hit_way] <= WAY_CNT - 1;       //鏇存柊LRU淇℃�?
//                         end else begin
//                             if(wr_req | rd_req) begin   // 濡傛�? cache 鏈懡涓紝骞朵笖鏈夎鍐欒姹傦紝鍒欓渶瑕佽繘琛屾崲锟�??
//                                 if(valid[set_addr][out_way] & dirty[set_addr][out_way]) begin    // 濡傛�? 瑕佹崲鍏ョ殑cache line 鏈潵鏈夋晥锛屼笖鑴忥紝鍒欓渶瑕佸厛灏嗗畠鎹㈠嚭
//                                     cache_stat  <= SWAP_OUT;
//                                     mem_wr_addr <= {cache_tags[set_addr][out_way], set_addr};
//                                     mem_wr_line <= cache_mem[set_addr][out_way];
//                                 end else begin                                   // 鍙嶄箣锛屼笉锟�?瑕佹崲鍑猴紝鐩存帴鎹㈠叆
//                                     cache_stat  <= SWAP_IN;
//                                 end
//                                 {mem_rd_tag_addr, mem_rd_set_addr} <= {tag_addr, set_addr};
//                             end
//                         end
//                     end
//         SWAP_OUT:   begin
//                         if(mem_gnt) begin           // 濡傛灉涓诲瓨鎻℃墜淇″彿鏈夋晥锛岃鏄庢崲鍑烘垚鍔燂紝璺冲埌涓嬩竴鐘讹拷??
//                             cache_stat <= SWAP_IN;
//                         end
//                     end
//         SWAP_IN:    begin
//                         if(mem_gnt) begin           // 濡傛灉涓诲瓨鎻℃墜淇″彿鏈夋晥锛岃鏄庢崲鍏ユ垚鍔燂紝璺冲埌涓嬩竴鐘讹拷??
//                             cache_stat <= SWAP_IN_OK;
//                         end
//                     end
//         SWAP_IN_OK: begin           // 涓婁竴涓懆鏈熸崲鍏ユ垚鍔燂紝杩欏懆鏈熷皢涓诲瓨璇诲嚭鐨刲ine鍐欏叆cache锛屽苟鏇存柊tag锛岀疆楂榲alid锛岀疆浣巇irty
//                         for(integer i=0; i<LINE_SIZE; i++)  cache_mem[mem_rd_set_addr][out_way][i] <= mem_rd_line[i];
//                         cache_tags[mem_rd_set_addr][out_way] <= mem_rd_tag_addr;
//                         valid     [mem_rd_set_addr][out_way] <= 1'b1;
//                         dirty     [mem_rd_set_addr][out_way] <= 1'b0;
//                         for(integer i = 0; i < WAY_CNT; i++) begin
//                             if(lru_r[set_addr][i] > lru_r[set_addr][out_way]) begin
//                                 lru_r[set_addr][i] <= lru_r[set_addr][i] - 1;
//                             end
//                         end
//                         lru_r[set_addr][out_way] <= WAY_CNT - 1;    //鏇存柊LRU淇℃�?
//                         if(fifo_r[set_addr] == WAY_CNT - 1)
//                             fifo_r[set_addr] <= 0;
//                         else
//                             fifo_r[set_addr] <= fifo_r[set_addr] + 1;                   //鏇存柊FIFO淇℃�?
//                         cache_stat <= IDLE;        // 鍥炲埌灏辩华鐘讹�???
//                     end
//         endcase
//     end
// end

// wire mem_rd_req = (cache_stat == SWAP_IN );
// wire mem_wr_req = (cache_stat == SWAP_OUT);
// wire [   MEM_ADDR_LEN-1 :0] mem_addr = mem_rd_req ? mem_rd_addr : ( mem_wr_req ? mem_wr_addr : 0);

// assign miss = (rd_req | wr_req) & ~(cache_hit && cache_stat==IDLE) ;     // 锟�? 鏈夎鍐欒姹傛椂锛屽鏋渃ache涓嶅浜庡氨锟�?(IDLE)鐘讹�??锟斤紝鎴栵拷?锟芥湭鍛戒腑锛屽垯miss=1

// main_mem #(     // 涓诲瓨锛屾瘡娆¤鍐欎互line 涓哄崟锟�??
//     .LINE_ADDR_LEN  ( LINE_ADDR_LEN          ),
//     .ADDR_LEN       ( MEM_ADDR_LEN           )
// ) main_mem_instance (
//     .clk            ( clk                    ),
//     .rst            ( rst                    ),
//     .gnt            ( mem_gnt                ),
//     .addr           ( mem_addr               ),
//     .rd_req         ( mem_rd_req             ),
//     .rd_line        ( mem_rd_line            ),
//     .wr_req         ( mem_wr_req             ),
//     .wr_line        ( mem_wr_line            )
// );

// endmodule





