# Lab3 实验报告

PB20000072 王铖潇



## 实验目的

1. 权衡cache size增大带来的命中率提升收益和存储资源电路面积的开销
2. 权衡选择合适的组相连度（相连度增大cache size也会增大，但是冲突miss会减低）
3. 体会使用复杂电路实现复杂替换策略带来的收益和简单替换策略的优势（有时候简单策略比复杂策略效果不差很多甚至可能更好）
4. 理解写回法的优劣



## 实验内容

### 实现替换策略

#### FIFO

FIFO每次替换出最早使用的块，对于每个SET，维护一个大小为`WAY_CNT`的数组，第`i`个数组元素表示“已经存在于内存中的时间为`i`的块”。每次需要换出存在内存中时间最长的块，即标号为`WAY_CNT - 1 `的块。

```verilog
if(strategy == `FIFO) begin
	way_addr = fifo[set_addr][WAY_CNT - 1];
end
```

换入新的块时，“已经存在于内存中的时间为`i - 1`的块” 变成 “已经存在于内存中的时间为`i`的块”， “已经存在于内存中的时间为`0`的块” 是新换入的块。 

```verilog
for (integer i = WAY_CNT - 1; i > 0; i--) begin
    fifo[set_addr][i] = fifo[set_addr][i-1];
end
fifo[set_addr][0] = way_addr;
```



#### LRU

LRU每次替换出最长没有使用的块，对于每个SET，维护一个大小为WAY_CNT的数组标记每个块“距离换出的时间”。

换入或使用一个新的块时，其余的块中“距离换出的时间”比该块大的，说明是本来要在这个块之后换出，现在这个块被使用，换出的时间后移，所以要将那些块的“距离换出的时间”减一；并且将这个块的值设为`WAY_CNT`（最大值）。

```
for(integer i = 0; i < WAY_CNT; i++) begin
    if(way_addr != i) begin
        if(lru[set_addr][i] > lru[set_addr][way_addr])
        lru[set_addr][i] <= lru[set_addr][i] - 1;
    end
    else 
    	lru[set_addr][i] <= WAY_CNT - 1;
end
```

当一个块的“距离换出的时间”为0时，将它换出：

```
for (integer i = 0; i< WAY_CNT; i++) begin
	if(lru[set_addr][i] == 0) begin
        way_addr = i;
        break;
    end
end
```



### Cache资源消耗评估

修改 Cache 的参数（组数、组相连度、line大小等）进行综合得到资源占用报告，其中 LUT 和 FF 两个参数的使用量代表 Cache 所占用电路的资源量，可用的资源分别是63400（LUT）和3061（FF），多次修改参数得到下表：

#### LRU

| 组数 | 组相联度 | line大小 | LUT  | FF    |
| ---- | -------- | -------- | ---- | ----- |
| 8    | 1        | 8        | 1144 | 3061  |
| 8    | 2        | 8        | 1989 | 5228  |
| 8    | 4        | 8        | 3860 | 9561  |
| 4    | 4        | 8        | 3377 | 5270  |
| 16   | 4        | 8        | 7744 | 18114 |
| 8    | 4        | 4        | 2131 | 5109  |
| 8    | 4        | 16       | 7952 | 18495 |

按照行顺序的截图如下：

![image-20230518103231112](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518103231112.png)

![image-20230518101952280](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518101952280.png)

![image-20230518102726496](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518102726496.png)

![image-20230518105837828](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518105837828.png)

![image-20230518105447617](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518105447617.png)

![image-20230518141124953](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518141124953.png)

![image-20230518141642821](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518141642821.png)



#### FIFO

| 组数 | 组相联度 | line大小 | LUT  | FF    |
| ---- | -------- | -------- | ---- | ----- |
| 8    | 1        | 8        | 1144 | 3058  |
| 8    | 2        | 8        | 2122 | 5183  |
| 8    | 4        | 8        | 3900 | 9455  |
| 4    | 4        | 8        | 4652 | 5218  |
| 16   | 4        | 8        | 7344 | 17914 |
| 8    | 4        | 4        | 2263 | 5011  |
| 8    | 4        | 16       | 8394 | 18404 |

按照行顺序的截图如下：

![image-20230518142103792](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518142103792.png)

![image-20230518142347740](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518142347740.png)

![image-20230518142726134](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518142726134.png)

![image-20230518143059795](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518143059795.png)

![image-20230518143446912](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518143446912.png)

![image-20230518143739387](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518143739387.png)

![image-20230518144122525](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518144122525.png)

### Cache性能评估

快速排序规模是256，矩阵乘法规模是16*16 ，对LRU和FIFO分别进行测试。

#### LRU

##### 快速排序

| 组数 | 组相联度 | line大小 | 未命中 | 命中 | 命中率 | 周期数 |
| ---- | -------- | -------- | ------ | ---- | ------ | ------ |
| 8    | 1        | 8        | 339    | 5413 | 94.1%  | 59910  |
| 8    | 2        | 8        | 184    | 6082 | 97.1%  | 48938  |
| 8    | 4        | 8        | 104    | 6721 | 98.5%  | 46973  |
| 4    | 4        | 8        | 221    | 6604 | 96.8%  | 56931  |
| 16   | 4        | 8        | 42     | 6783 | 99.4%  | 40245  |
| 8    | 4        | 4        | 412    | 6413 | 94.0%  | 71561  |
| 8    | 4        | 16       | 21     | 6804 | 99.7%  | 39111  |

按照行顺序的截图如下：

![image-20230518163531394](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518163531394.png)

![image-20230518163227053](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518163227053.png)

![image-20230518163059163](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518163059163.png)

![image-20230518162952682](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518162952682.png)

![image-20230518162606145](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518162606145.png)

![image-20230518162339398](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518162339398.png)

![image-20230518162441523](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518162441523.png)



##### 矩阵乘法

| 组数 | 组相联度 | line大小 | 未命中 | 命中 | 命中率 | 周期数 |
| ---- | -------- | -------- | ------ | ---- | ------ | ------ |
| 8    | 1        | 8        | 5120   | 3584 | 41.2%  | 354602 |
| 8    | 2        | 8        | 4696   | 4008 | 46.0%  | 331706 |
| 8    | 4        | 8        | 1752   | 6952 | 79.9%  | 160942 |
| 4    | 4        | 8        | 4511   | 4193 | 48.2%  | 313568 |
| 16   | 4        | 8        | 153    | 8551 | 98.2%  | 73868  |
| 8    | 4        | 4        | 4668   | 4036 | 46.4%  | 326310 |
| 8    | 4        | 16       | 90     | 8614 | 99.0%  | 70102  |

按照行的顺序截图如下：

![image-20230518181517749](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518181517749.png)

![image-20230518181753978](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518181753978.png)

![image-20230518181940831](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518181940831.png)

![image-20230518182140344](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518182140344.png)

![image-20230518182331496](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518182331496.png)

![image-20230518182558199](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518182558199.png)

![image-20230518182849027](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518182849027.png)



#### FIFO

##### 快速排序

| 组数 | 组相联度 | line大小 | 未命中 | 命中 | 命中率 | 周期数 |
| ---- | -------- | -------- | ------ | ---- | ------ | ------ |
| 8    | 1        | 8        | 339    | 5413 | 94.1%  | 59910  |
| 8    | 2        | 8        | 160    | 6035 | 97.4%  | 46964  |
| 8    | 4        | 8        | 89     | 6736 | 98.6％ | 42363  |
| 4    | 4        | 8        | 222    | 6529 | 96.7%  | 56346  |
| 16   | 4        | 8        | 42     | 6783 | 99.3%  | 40245  |
| 8    | 4        | 4        | 409    | 6356 | 94.0%  | 71080  |
| 8    | 4        | 16       | 21     | 6804 | 99.7%  | 39111  |

按顺序的仿真截图如下：

![image-20230518163851856](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518163851856.png)

![image-20230518163940881](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518163940881.png)

![image-20230518164041721](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518164041721.png)

![image-20230518165453229](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518165453229.png)

![image-20230518165816095](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518165816095.png)

![image-20230518170002036](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518170002036.png)

![image-20230518170113308](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518170113308.png)



##### 矩阵乘法

| 组数 | 组相联度 | line大小 | 未命中 | 命中  | 命中率 | 周期数 |
| ---- | -------- | -------- | ------ | ----- | ------ | ------ |
| 8    | 1        | 8        | 5120   | 3584  | 41.2%  | 354602 |
| 8    | 2        | 8        | 4864   | 3840  | 44.1%  | 340778 |
| 8    | 4        | 8        | 1739   | 6965  | 80.0%  | 171976 |
| 4    | 4        | 8        | 4800   | 3,904 | 44.9%  | 337322 |
| 16   | 4        | 8        | 144    | 8560  | 98.3%  | 73430  |
| 8    | 4        | 4        | 4760   | 3944  | 45.3%  | 335170 |
| 8    | 4        | 16       | 72     | 8632  | 99.2%  | 69128  |

按照行的顺序截图如下：

![image-20230518172243883](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518172243883.png)

![image-20230518172735019](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518172735019.png)

![image-20230518172524972](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518172524972.png)

![image-20230518180055546](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518180055546.png)

![image-20230518180208086](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518180208086.png)

![image-20230518181202302](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518181202302.png)

![image-20230518180330709](D:\experiment_Vivado\Grade3_spring\Lab3\report\image-20230518180330709.png)



### 结果总结

1. 对于矩阵乘法：

   组数和line大小相同时， LRU 优于 FIFO；

   组相连度相同时，组数/line大小较小时LRU更优，较大时FIFO更优。

2. 对于快速排序：

   组数和line大小相同时， FIFO 优于 LRU；

   组相连度相同时， LRU 与 FIFO 的性能几乎相同。

3. 增加组相联度能显著提升 Cache 的命中率，提高运行性能。增加组数和line大小也可以有同样的效果，但是需要较大的Cache空间代价。

4. 同时考虑性能和资源消耗，对于矩阵乘法，应选择组数为8，line大小为8，块数为，组相联度为 4 的 LRU 策略 Cache；对于快速排序，应选择组数为8，line大小为8，组相联度为 4 的 FIFO 策略 Cache 。



## 实验难点

1. 模块实例化名称出错

   在`WbData`中实例化`cache`时，写成了`Cache`，导致报错很奇怪（并不是“没有找到相应模块”之类的报错），找了很久才发现这里出了问题。

2. FIFO策略的实现

   我的想法是维护一个队列，每次需要换出的时候就将队头的块换出，队尾加入新的块。出错的点在于我只维护了一个队列，实际上应该给每个组维护一个队列。并且队列中每个块应该用WAY的编号，而不是SET的编号来标识，这样方便查询。

3. 对Cache性能的测试

   在测试资源消耗的时候，记得将Simulation文件中的cache_tb.sv设为顶层模块，但是忘了把Source文件中的cache.sv设为顶层模块。导致测出来的LUT和FF利用率超过了百分之百，找了很久才发现这里有问题。

   

## 实验总结及收获

本次实验实现了Cache，通过测试大量样例测试，比较了不同替换策略以及Cache参数大小不同的性能差异，对缓存机制有了更加深入的了解。

另外，本次实验文档非常详细！照着上面的提示来做实验并不难完成。