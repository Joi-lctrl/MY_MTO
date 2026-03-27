# CEDA Trust-Channel 设计说明

## 摘要

本文档提出一个面向论文创新的受约束多任务优化 CEDA-MP 变体，命名为 `CEDA_MP_TRUSTCHANNEL`。
核心观点是，跨任务迁移不应由单一的全局概率控制。在受约束多任务场景中，个体会处于不同的约束阶段，只有当迁移知识与目标任务当前的约束状态匹配时，迁移才真正有价值。因此，该方法将状态感知的迁移通道与轻量级迁移可信度评估器结合起来。

## 背景

当前仓库中已经存在多个 CEDA 扩展版本：

- 基础的全局 whitening-coloring 迁移实现见 [CEDA_MP.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP.m)
- 更换全局映射方式的版本见 [CEDA_MP_MAP.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP_MAP.m)、[CEDA_MP_OT.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP_OT.m)、[CEDA_MP_COPULA.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP_COPULA.m)
- 按可行性拆分迁移通道的版本见 [CEDA_MP_FEASCHANNEL.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP_FEASCHANNEL.m) 与 [CEDA_MP_DUALCHANNEL.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP_DUALCHANNEL.m)
- 基于触发信号自适应迁移的版本见 [CEDA_MP_TRIGGER.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP_TRIGGER.m)

因此，新方法不能只是再换一个 mapper，或再多加一个通道。它的创新点必须来自“迁移建模”和“约束处理”的统一耦合控制机制。

## 问题定义

现有 CEDA 类变体普遍默认：一旦选定源任务，迁移总体上就是有益的。即便迁移概率会自适应，最终决策也依然主要是全局性的。这会造成知识错配：

- 处于可行精炼阶段的个体，可能被过强的外部注入破坏
- 处于边界阶段的个体，需要的是能帮助其跨越可行边界的迁移
- 明显不可行的个体，需要的是探索型迁移，而不是精炼型可行知识

本设计的目标，是让迁移仅在“映射后的知识与目标任务当前约束阶段匹配且近期有收益证据”时发生。

## 目标

- 提出超越“更换映射器”的机制级创新
- 将迁移决策与约束状态信息显式耦合
- 保持 trust 模型轻量、可解释、便于消融
- 尽量复用当前 CEDA 代码结构与日志风格
- 保持与已有 CEDA 变体的对比关系清晰

## 非目标

- 不替换整个 CEDA 框架
- 不引入重型 surrogate 或深度模型
- 不为每条任务边手动设计独立参数表
- 不顺带重构无关的 CEDA 变体

## 方法概述

### 方法名称

`CEDA_MP_TRUSTCHANNEL`

### 核心思想

Pop1 的迁移不再由单一 `RMP1` 控制。相反，每个目标任务维护多个约束状态通道，每个映射后的迁移候选个体都会得到一个 trust score。最终注入决策由下式控制：

`transfer probability = base state RMP x trust score`

这使得 `RMP` 从“最终迁移概率”转变为“迁移先验意愿”，而真正的迁移行为由状态匹配程度和历史有效性共同决定。

## 约束状态划分

每个任务的 Pop1 按三种状态划分：

- `F`：可行且具有利用价值的个体
- `B`：靠近可行边界、最有希望跨入可行域的个体
- `I`：明显不可行、承担更广泛探索作用的个体

状态划分应基于种群相对统计量，而不是固定的全局阈值。

### `F` 状态

满足 `CV <= 0` 的个体属于可行个体。在这些个体中，再按目标值 `Obj` 取较优部分作为 `F` 通道。该通道代表可行域内部的精炼搜索。

### `B` 状态

`B` 通道包含违反程度最小的不可行个体。可接受的首版实现有两种：

- 在 `CV > 0` 的个体中取前 `rho_b` 比例
- 满足 `CV / (median(CV_infeasible) + eps) <= tau_b` 的个体

首版建议优先使用第一种，因为更简单、更稳定。

### `I` 状态

剩余个体全部归入 `I`。该通道用于保持探索能力，避免算法退化为只利用可行知识。

### 回退规则

当某一状态中的样本数量不足以支撑稳定映射时，算法应按该状态原本的偏好方向扩展样本：

- 对 `F`，回退到当前可获得的低 `CV` 优质个体
- 对 `B`，回退到当前违反程度最小的一批个体
- 对 `I`，回退到当前违反程度最大的一批个体

这样可以避免早期代数中因样本稀少导致映射不稳定。

## 状态感知映射

映射不再针对整个人群一次性建立，而是按状态通道分别建立。优先对齐顺序为：

- `F -> F`
- `B -> B`
- `I -> I`

首版实现建议继续复用当前线性 `CEDA_trans` 风格的映射方式，使方法的主要贡献集中在控制逻辑，而不是 mapper 本身。

对每个源任务到目标任务的任务边 `(k -> t)`，算法基于同状态的源/目标子集构造映射候选池，从而让迁移分布更接近目标任务当前所处的优化阶段。

## 迁移可信度评估器

每个映射候选个体都会得到一个 `[0, 1]` 区间内的 trust score：

`trust = w1 * compat + w2 * boundary + w3 * history`

其中 3 个分量定义如下。

### `compat`

`compat` 用于衡量映射后的候选个体是否与目标状态分布相容。首版可采用候选点到目标状态统计模型的归一化距离，例如马氏距离或 whitening 空间下的欧氏距离，再将其映射到有界分数。

直观解释：这个映射后的点，看起来像不像目标任务该状态下“合理”的个体。

### `boundary`

`boundary` 用于衡量候选个体是否朝着有前景的约束边界区域移动，特别对 `B` 和 `I` 通道更重要。一个简单做法是计算候选点到目标任务边界状态中心的距离，或到 `F/B` 混合包络的距离。

直观解释：它是否在向目标任务的可行边界推进，而不是落在一个统计上可接受、但优化上无意义的区域。

### `history`

`history` 表示该任务边、该状态通道最近是否真实产生过收益。它按任务边和状态通道维护低维滑动统计，记录近期迁移样本是否：

- 存活进入下一代
- 改善 `CV`
- 从不可行变为可行
- 在可行后继续改善目标值

直观解释：这条迁移路线最近到底有没有用。

## Trust 耦合注入机制

为每个状态通道设置一个基础迁移率：

- `RMP_F`
- `RMP_B`
- `RMP_I`

建议的大小关系为：

- `RMP_B` 最大
- `RMP_I` 居中
- `RMP_F` 最小

真正的注入规则改为：

`if rand < RMP_state * trust`

这样既保留了紧凑的参数结构，也使迁移强度同时受到约束阶段和任务关系质量的控制。

## 算法流程

在每一代中，Pop1 的流程变为：

1. 对每个目标任务种群划分 `F`、`B`、`I`
2. 为当前目标任务选择伙伴任务，并构造状态感知的源/目标子集
3. 基于状态匹配映射构造候选迁移池
4. 对每个映射候选个体计算 trust
5. 按 `RMP_state * trust` 决定是否向父代中注入迁移
6. 继续执行现有交叉、变异、变量交换流程
7. 评估 offspring 并执行选择
8. 更新每条任务边、每个状态通道的历史统计

Pop2 在首版实现中明确不改动，保持与当前基线一致。

## 实现结构

建议以新增算法文件的方式实现，而不是直接修改现有基线类。

推荐新增文件：

- `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m`

推荐在类内拆分的辅助函数：

- `PartitionConstraintStates(pop, state_cfg)`
- `SelectStatePopulation(pop, state_id, state_info)`
- `BuildStateAwareMaps(dst_pop, src_pop, state_info_dst, state_info_src)`
- `EstimateTransferTrust(mapped_dec, dst_model, hist_stat, state_id)`
- `InjectByTrust(pop, mapped_pool, trust_score, base_rmp, state_id)`
- `UpdateChannelHistory(edge_stat, offspring_stat, state_id)`

首版建议先把这些逻辑保留在单个算法文件内，等方法验证稳定后再考虑抽成共享工具函数。

## 日志与诊断

该方法应记录过程性证据，风格可直接延续 `CEDA_MP_TRIGGER`：

- `F`、`B`、`I` 三个通道的规模
- 各通道的迁移尝试次数
- 各通道的有效注入次数
- 各任务边、各状态下的平均 trust
- 迁移 offspring 的存活数量
- 迁移 offspring 带来的 `CV` 改善数量
- 迁移 offspring 跨入可行域的数量

这些日志既用于调试，也用于论文中的过程性图表与机制证据。

## 实验设计

### 主要对比基线

- `CEDA_MP`
- `CEDA_MP_TRIGGER`
- `CEDA_MP_DUALCHANNEL`
- `CEDA_MP_TRUSTCHANNEL`

若计算预算允许，可加入：

- `CEDA_MP_MAP`
- `CEDA_MP_OT`

### 必要消融

- `w/o state partition`：不划分 `F/B/I`，仅保留 trust
- `w/o trust`：保留状态通道，但迁移使用固定 `RMP`
- `w/o history`：trust 中只保留 `compat` 与 `boundary`
- `B-only trust`：只对 `B` 通道启用 trust

### 重点分析指标

- 最终优化效果
- 收敛过程
- 可行率演化过程
- 各通道迁移有效性
- 由迁移引起的 `B/I -> F` 转化比例

## 参数策略

为了避免方法显得过度工程化，新增超参数应控制在三组以内：

- 状态划分参数，例如 `rho_f`、`rho_b`
- trust 权重 `w1`、`w2`、`w3`
- 状态基础迁移率 `RMP_F`、`RMP_B`、`RMP_I`

不应再为每个任务、每条任务边或每个代数阶段额外引入手调参数。那些差异应由历史统计自行体现，而不是显式人工调参。

## 风险与缓解

### 风险 1：状态划分在不同问题上不稳定

缓解方式：
使用相对排序或比例，而不是绝对 `CV` 阈值。

### 风险 2：trust 与环境选择作用重复

缓解方式：
让 trust 只负责注入前筛选，并通过过程日志证明它在环境选择之前就已经提高了迁移质量。

### 风险 3：模块过多削弱论文说服力

缓解方式：
保持 trust 结构线性、轻量，并控制状态基础参数数量。

## 结论建议

建议将 `CEDA_MP_TRUSTCHANNEL` 实现为一个新的 CEDA 变体，保留现有 CEDA 的变异流程和基础映射骨架，只改动 Pop1 的迁移控制逻辑。这样可以用最小的结构偏移，得到最完整的论文叙事：

- 通道结构负责表达约束阶段
- trust 负责决定映射知识是否值得注入
- history 负责在不引入重型学习器的前提下稳定迁移决策

该设计足够聚焦，适合作为单个 implementation plan 的输入，也便于后续基线比较与消融实验展开。
