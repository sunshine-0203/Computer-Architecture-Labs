
`include "D:\experiment_Vivado\Grade3_spring\Lab3\lab3\lab3.srcs\sources_1\imports\PART-code\Parameters.v"

module cache #(
    parameter  LINE_ADDR_LEN = 3, // line内地址长度，决定了每个line具有2^3个word
    parameter  SET_ADDR_LEN  = 3, // 组地址长度，决定了一共有2^3=8组
    parameter  TAG_ADDR_LEN  = 6, // tag长度
    parameter  WAY_CNT       = 4,  // 组相连度，决定了每组中有多少路line，这里是直接映射型cache，因此该参数没用到
    parameter  STRATEGY      = `LRU
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

reg [            31:0] cache_mem    [SET_SIZE][WAY_CNT][LINE_SIZE]; // SET_SIZE个组，每个组有WAY_CNT个line，每个line有LINE_SIZE个word
reg [TAG_ADDR_LEN-1:0] cache_tags   [SET_SIZE][WAY_CNT];            // SET_SIZE*WAY_CNT个TAG
reg                    valid        [SET_SIZE][WAY_CNT];            // SET_SIZE*WAY_CNT个valid(有效位)
reg                    dirty        [SET_SIZE][WAY_CNT];            // SET_SIZE*WAY_CNT个dirty(脏位)

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


reg [WAY_CNT:0] out_way;
reg [WAY_CNT:0] lru_r[SET_SIZE][WAY_CNT];
reg [WAY_CNT:0] fifo_r[SET_SIZE];
reg swap_strategy;

always @ (*) begin              // 判断 输入的address 是否在 cache 中命中
    cache_hit = 1'b0;
    for(integer i = 0; i < WAY_CNT; i++) begin
        if(valid[set_addr][i] && cache_tags[set_addr][i] == tag_addr) begin   // 如果 cache line有效，并且tag与输入地址中的tag相等，则命中
            cache_hit = 1'b1;
            way_addr = i;
            break;
        end
    end
end

always @ (*) begin
    if(~cache_hit && (wr_req | rd_req)) begin
        if(swap_strategy == `LRU) begin
            for(integer i = 0; i < WAY_CNT; i++) begin
                if(lru_r[set_addr][i] == 0) begin
                    out_way = i;
                    break;
                end
            end
        end
        else if(swap_strategy == `FIFO) begin
            out_way = fifo_r[set_addr];
        end
    end
end

always @ (posedge clk or posedge rst) begin     // ?? cache ???
    if(rst) begin
        cache_stat <= IDLE;
        swap_strategy <= STRATEGY;
        for(integer i = 0; i < SET_SIZE; i++) begin
            fifo_r[i] <= 0;
            for(integer j = 0; j < WAY_CNT; j++) begin
                dirty[i][j] = 1'b0;
                valid[i][j] = 1'b0;
                lru_r[i][j] = j;
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
                            if(rd_req) begin    // 瞈∪��ache����撅質�瘨�瑽貊��憪孵蝝?
                                rd_data <= cache_mem[set_addr][way_addr][line_addr];   //��瘣輸�斤�cache瘨�敶�曏遴�畾���
                            end else if(wr_req) begin // 瞈∪��ache����撅質�瘨�瑽賊�甈憪孵蝝?
                                cache_mem[set_addr][way_addr][line_addr] <= wr_data;   // ��瘣輸�交�cache瘨����行��蕭?
                                dirty[set_addr][way_addr] <= 1'b1;                     // ����暹��掛璊��踹�蕭?
                            end 
                            for(integer i = 0; i < WAY_CNT; i++) begin
                                if(lru_r[set_addr][i] > lru_r[set_addr][way_addr]) begin
                                    lru_r[set_addr][i] <= lru_r[set_addr][i] - 1;
                                end
                            end
                            lru_r[set_addr][way_addr] <= WAY_CNT - 1;       //���RU瘛�隡?
                        end else begin
                            if(wr_req | rd_req) begin   // 瞈∪��? cache ���⊥��函�撉蝚�憭���砍完�衣���皜嗥�雿賜��掛撏脤�嚙??
                                if(valid[set_addr][out_way] & dirty[set_addr][out_way]) begin    // 瞈∪��? �蝴撏脤��扳�cache line ��瞏菟�憭�掉蝚敹亦���皜嗥�雿詨�����
                                    cache_stat  <= SWAP_OUT;
                                    mem_wr_addr <= {cache_tags[set_addr][out_way], set_addr};
                                    mem_wr_line <= cache_mem[set_addr][out_way];
                                end else begin                                   // ��蝞��撅潛��蕭?�蝴撏脤��渡��拙�撣湧��
                                    cache_stat  <= SWAP_IN;
                                end
                                {mem_rd_tag_addr, mem_rd_set_addr} <= {tag_addr, set_addr};
                            end
                        end
                    end
        SWAP_OUT:   begin
                        if(mem_gnt) begin           // 瞈∪���霂脩�領�憓��喳蝙���仿�撗�滯撏脤�����蝝�脣�瘨洸蝡湧�霈寞??
                            cache_stat <= SWAP_IN;
                        end
                    end
        SWAP_IN:    begin
                        if(mem_gnt) begin           // 瞈∪���霂脩�領�憓��喳蝙���仿�撗�滯撏脤��血���蝝�脣�瘨洸蝡湧�霈寞??
                            cache_stat <= SWAP_IN_OK;
                        end
                    end
        SWAP_IN_OK: begin           // 瘨�蝡湔����撏脤��血���蝝甈���Ｘ�霂脩�租�剝�烹ne���ache�掃��摮�tag����璁淮lid���童撌rty
                        for(integer i=0; i<LINE_SIZE; i++)  cache_mem[mem_rd_set_addr][out_way][i] <= mem_rd_line[i];
                        cache_tags[mem_rd_set_addr][out_way] <= mem_rd_tag_addr;
                        valid     [mem_rd_set_addr][out_way] <= 1'b1;
                        dirty     [mem_rd_set_addr][out_way] <= 1'b0;
                        for(integer i = 0; i < WAY_CNT; i++) begin
                            if(lru_r[set_addr][i] > lru_r[set_addr][out_way]) begin
                                lru_r[set_addr][i] <= lru_r[set_addr][i] - 1;
                            end
                        end
                        lru_r[set_addr][out_way] <= WAY_CNT - 1;    //���RU瘛�隡?
                        if(fifo_r[set_addr] == WAY_CNT - 1)
                            fifo_r[set_addr] <= 0;
                        else
                            fifo_r[set_addr] <= fifo_r[set_addr] + 1;                   //���IFO瘛�隡?
                        cache_stat <= IDLE;        // �亦��颲拙��捆�???
                    end
        endcase
    end
end

wire mem_rd_req = (cache_stat == SWAP_IN );
wire mem_wr_req = (cache_stat == SWAP_OUT);
wire [   MEM_ADDR_LEN-1 :0] mem_addr = mem_rd_req ? mem_rd_addr : ( mem_wr_req ? mem_wr_addr : 0);

assign miss = (rd_req | wr_req) & ~(cache_hit && cache_stat==IDLE) ;     // �蕭? ���圈�甈憪孵�璊�撅踐��ache瘨��拇�摨⊥馬�蕭?(IDLE)�捆�??�蝝�菜?�皝剝����掃�痂iss=1

main_mem #(     // 瘨租�券�撅曄憡止��鈭ine 瘨�撏�嚙??
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

