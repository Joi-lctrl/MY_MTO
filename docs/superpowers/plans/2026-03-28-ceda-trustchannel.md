# CEDA_MP_TRUSTCHANNEL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 MTO MATLAB 框架中实现 `CEDA_MP_TRUSTCHANNEL`，把 `CEDA_MP` 的 Pop1 迁移控制升级为“约束状态感知 + trust 耦合注入 + 历史收益记忆”的新算法，并提供可直接用于诊断的日志可视化脚本。

**Architecture:** 以 [`CEDA_MP.m`](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP.m) 为骨架新增一个独立算法文件，保留 Pop2 原始流程与 `CEDA_trans` 线性映射骨架，只重写 Pop1 的 `Generation1`、状态划分、trust 计算、历史统计和日志记录。配套新增一个绘图脚本，用于直接检查 `F/B/I` 通道规模、平均 trust、有效注入与跨入可行域数量。

**Tech Stack:** MATLAB R2022b+, MToP `Algorithm`/`Problem` API, 现有 `CEDA_trans`、`Selection_Elit`、`TournamentSelection`、`GA_Crossover`、`GA_Mutation`

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m` | 新算法主体，包含参数、状态划分、state-aware mapping、trust 注入、history 更新、日志保存 |
| Create | `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/plot_CEDA_MP_TRUSTCHANNEL.m` | 加载 `CEDA_MP_TRUSTCHANNEL` 日志并输出通道规模、trust、有效注入与可行跨越图 |

只创建两个新文件，不修改现有基线算法，便于与 `CEDA_MP`、`CEDA_MP_TRIGGER`、`CEDA_MP_DUALCHANNEL` 做干净对比。

---

### Task 1: 创建可运行的 `CEDA_MP_TRUSTCHANNEL` 基线骨架

**Files:**
- Create: `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m`

- [ ] **Step 1: 先运行失败的 smoke test，确认算法名当前不存在**

Run:
```bash
matlab -batch "cd('MTO'); prob = CMT5(); prob.maxFE = 2000; algo = CEDA_MP_TRUSTCHANNEL(); mto({algo}, {prob}, 'Reps', 1, 'Global_Seed', 2333);"
```

Expected: FAIL，报错中包含 `Unrecognized function or variable 'CEDA_MP_TRUSTCHANNEL'` 或等价的类未定义信息。

- [ ] **Step 2: 创建完整的骨架文件，使算法先能被 MTO 正常加载并跑通**

创建 `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m`，内容如下：

```matlab
classdef CEDA_MP_TRUSTCHANNEL < Algorithm
% <Multi-task> <Single-objective> <Constrained>

properties (SetAccess = public)
    EC_Top = 0.2
    EC_Tc = 0.8
    EC_Cp = 5
    MuC = 2
    MuM = 5
    RMP_F = 0.08
    RMP_B = 0.18
    RMP_I = 0.12
    StateTopF = 0.5
    StateTopB = 0.3
    StateMinSize = 6
    Trust_WCompat = 0.45
    Trust_WBoundary = 0.35
    Trust_WHistory = 0.20
    HistAlpha = 0.2
    Save_Log = true
    LogName char = 'CEDA_MP_TRUSTCHANNEL_Log.mat'
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'MuC', num2str(Algo.MuC), ...
                'MuM', num2str(Algo.MuM), ...
                'RMP_F', num2str(Algo.RMP_F), ...
                'RMP_B', num2str(Algo.RMP_B), ...
                'RMP_I', num2str(Algo.RMP_I), ...
                'StateTopF', num2str(Algo.StateTopF), ...
                'StateTopB', num2str(Algo.StateTopB), ...
                'StateMinSize', num2str(Algo.StateMinSize), ...
                'Trust_WCompat', num2str(Algo.Trust_WCompat), ...
                'Trust_WBoundary', num2str(Algo.Trust_WBoundary), ...
                'Trust_WHistory', num2str(Algo.Trust_WHistory), ...
                'HistAlpha', num2str(Algo.HistAlpha), ...
                'Save_Log', num2str(Algo.Save_Log), ...
                'LogName', Algo.LogName};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.EC_Top = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Tc = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Cp = str2double(Parameter{i}); i = i + 1;
        Algo.MuC = str2double(Parameter{i}); i = i + 1;
        Algo.MuM = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_F = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_B = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_I = str2double(Parameter{i}); i = i + 1;
        Algo.StateTopF = str2double(Parameter{i}); i = i + 1;
        Algo.StateTopB = str2double(Parameter{i}); i = i + 1;
        Algo.StateMinSize = str2double(Parameter{i}); i = i + 1;
        Algo.Trust_WCompat = str2double(Parameter{i}); i = i + 1;
        Algo.Trust_WBoundary = str2double(Parameter{i}); i = i + 1;
        Algo.Trust_WHistory = str2double(Parameter{i}); i = i + 1;
        Algo.HistAlpha = str2double(Parameter{i}); i = i + 1;
        Algo.Save_Log = logical(str2double(Parameter{i})); i = i + 1;
        Algo.LogName = Parameter{i};
    end

    function run(Algo, Prob)
        population1 = Initialization(Algo, Prob, Individual);
        population2 = Initialization(Algo, Prob, Individual);

        for t = 1:Prob.T
            n = ceil(Algo.EC_Top * length(population1{t}));
            cv_temp = [population1{t}.CV];
            [~, idx] = sort(cv_temp);
            Ep0{t} = cv_temp(idx(n));
        end

        for k = 1:Prob.T
            for t = 1:Prob.T
                edge_stat{k, t} = Algo.EmptyEdgeStat();
            end
        end

        if Algo.Save_Log
            Log = Algo.InitLog(Prob);
        end

        gen = 0;
        while Algo.notTerminated(Prob, population2)
            gen = gen + 1;
            state_cache = cell(1, Prob.T);
            for t = 1:Prob.T
                if Algo.FE < Algo.EC_Tc * Prob.maxFE
                    Ep = Ep0{t} * ((1 - Algo.FE / (Algo.EC_Tc * Prob.maxFE))^Algo.EC_Cp);
                else
                    Ep = 0;
                end
                eps_now(t) = Ep;
                state_cache{t} = Algo.PartitionConstraintStates(population1{t});
                CV = population1{t}.CVs;
                CV(CV < Ep) = 0;
                Obj = population1{t}.Objs;
                mating_pool1{t} = TournamentSelection(2, Prob.N, CV, Obj);
                mating_pool2{t} = TournamentSelection(2, Prob.N, population2{t}.CVs, population2{t}.Objs);

                if Algo.Save_Log
                    Log.FE(gen, 1) = Algo.FE;
                    Log.FE_Ratio(gen, 1) = Algo.FE / Prob.maxFE;
                    Log.StateCountF(gen, t) = numel(state_cache{t}.FIdx);
                    Log.StateCountB(gen, t) = numel(state_cache{t}.BIdx);
                    Log.StateCountI(gen, t) = numel(state_cache{t}.IIdx);
                    Log.Epsilon(gen, t) = Ep;
                end
            end

            for t = 1:Prob.T
                k = randi(Prob.T);
                while k == t
                    k = randi(Prob.T);
                end

                [offspring1, transfer_info] = Algo.Generation1( ...
                    population1{t}, mating_pool1{t}, population1{k}(mating_pool1{k}), ...
                    state_cache{t}, state_cache{k}, edge_stat{k, t});
                offspring2 = Algo.Generation2(population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));
                n_parent = length(population1{t});
                n_off1 = length(offspring1);
                offspring = [offspring1, offspring2];
                offspring = Algo.Evaluation(offspring, Prob, t);
                [population1{t}, rank1] = Selection_Elit(population1{t}, offspring, eps_now(t));
                population2{t} = Selection_Elit(population2{t}, offspring, 0);

                edge_stat{k, t} = Algo.UpdateChannelHistory(edge_stat{k, t}, offspring(1:n_off1), transfer_info, rank1, n_parent);
                if Algo.Save_Log
                    Log.Partner(gen, t) = k;
                    Log = Algo.RecordTransferStats(Log, gen, t, transfer_info, edge_stat{k, t}, offspring(1:n_off1), rank1, n_parent);
                end
            end
        end

        if Algo.Save_Log
            Log.TotalGen = gen;
            save(Algo.LogName, 'Log');
        end
    end

    function [offspring, info] = Generation1(Algo, population, pool, transpop, dst_state, src_state, edge_stat)
        population = population(pool);
        [maps, state_meta] = Algo.BuildStateAwareMaps(population, transpop, dst_state, src_state);
        [population, info] = Algo.InjectByTrust(population, maps, state_meta, edge_stat);

        n_off = ceil(length(population) / 2);
        info.ParentCV = nan(1, n_off);
        info.ParentObj = nan(1, n_off);
        for i = 1:n_off
            offspring(i) = population(i);
            p2 = i + fix(length(population) / 2);
            [offspring(i).Dec, tempDec] = GA_Crossover(population(i).Dec, population(p2).Dec, Algo.MuC);
            offspring(i).Dec = GA_Mutation(offspring(i).Dec, Algo.MuM);
            tempDec = GA_Mutation(tempDec, Algo.MuM);
            swap_indicator = rand(1, length(population(i).Dec)) >= 0.5;
            offspring(i).Dec(swap_indicator) = tempDec(swap_indicator);
            offspring(i).Dec = min(max(offspring(i).Dec, 0), 1);
            info.ParentCV(i) = population(i).CV;
            info.ParentObj(i) = population(i).Obj;
        end
        info.IsTransferred = info.ParentTransferred(1:n_off);
        info.StateId = info.ParentStateId(1:n_off);
        info.Trust = info.ParentTrust(1:n_off);
    end

    function offspring = Generation2(Algo, population, pool, transpop)
        population = population(pool);
        population_temp = population;
        temp_Dec = CEDA_trans(transpop, population_temp, transpop.Decs);
        temp_Dec2 = CEDA_trans(population_temp, transpop, population.Decs);
        for i = 1:length(population)
            if rand() < 0
                if rand() < 0.5
                    population(i).Dec = temp_Dec(randi(end), :);
                else
                    population(i).Dec = temp_Dec2(randi(end), :);
                end
            end
        end

        for i = 1:ceil(length(population) / 2)
            offspring(i) = population(i);
            p2 = i + fix(length(population) / 2);
            [offspring(i).Dec, tempDec] = GA_Crossover(population(i).Dec, population(p2).Dec, Algo.MuC);
            offspring(i).Dec = GA_Mutation(offspring(i).Dec, Algo.MuM);
            tempDec = GA_Mutation(tempDec, Algo.MuM);
            swap_indicator = rand(1, length(population(i).Dec)) >= 0.5;
            offspring(i).Dec(swap_indicator) = tempDec(swap_indicator);
            offspring(i).Dec = min(max(offspring(i).Dec, 0), 1);
        end
    end

    function state = PartitionConstraintStates(Algo, pop)
        cv = [pop.CV];
        obj = [pop.Obj];
        feasible_idx = find(cv <= 0);
        infeasible_idx = find(cv > 0);

        if isempty(feasible_idx)
            state.FIdx = [];
        else
            take_f = max(1, ceil(Algo.StateTopF * numel(feasible_idx)));
            [~, ord_f] = sort(obj(feasible_idx), 'ascend');
            state.FIdx = feasible_idx(ord_f(1:take_f));
        end

        if isempty(infeasible_idx)
            state.BIdx = [];
            state.IIdx = [];
            state.BoundaryCV = 0;
        else
            take_b = max(1, ceil(Algo.StateTopB * numel(infeasible_idx)));
            [sorted_cv, ord_b] = sort(cv(infeasible_idx), 'ascend');
            state.BIdx = infeasible_idx(ord_b(1:take_b));
            if take_b < numel(infeasible_idx)
                state.IIdx = infeasible_idx(ord_b(take_b + 1:end));
            else
                state.IIdx = [];
            end
            state.BoundaryCV = sorted_cv(take_b);
        end
    end

    function [maps, meta] = BuildStateAwareMaps(~, population, transpop, ~, ~)
        maps = cell(1, 3);
        for state_id = 1:3
            maps{state_id}.FromSrc = transpop.Decs;
            maps{state_id}.FromDst = population.Decs;
        end
        meta.BoundaryCenter = mean(population.Decs, 1);
    end

    function [population, info] = InjectByTrust(Algo, population, maps, meta, edge_stat)
        info.ParentTransferred = false(1, length(population));
        info.ParentStateId = zeros(1, length(population));
        info.ParentTrust = zeros(1, length(population));
        for i = 1:length(population)
            state_id = Algo.StateIdFromCV(population(i).CV, meta);
            trust = Algo.EstimateTransferTrust(population(i).Dec, state_id, meta, edge_stat);
            base_rmp = Algo.StateBaseRMP(state_id);
            info.ParentStateId(i) = state_id;
            info.ParentTrust(i) = trust;
            if rand() < base_rmp * trust
                if rand() < 0.5
                    population(i).Dec = maps{state_id}.FromSrc(randi(size(maps{state_id}.FromSrc, 1)), :);
                else
                    population(i).Dec = maps{state_id}.FromDst(randi(size(maps{state_id}.FromDst, 1)), :);
                end
                info.ParentTransferred(i) = true;
            end
        end
    end

    function trust = EstimateTransferTrust(Algo, dec, state_id, meta, edge_stat)
        compat = 1;
        boundary = Algo.NormalizeDistanceScore(norm(dec - meta.BoundaryCenter));
        history = edge_stat.Success(state_id);
        trust = Algo.Trust_WCompat * compat + Algo.Trust_WBoundary * boundary + Algo.Trust_WHistory * history;
        trust = min(max(trust, 0), 1);
    end

    function score = NormalizeDistanceScore(~, dist_value)
        score = 1 / (1 + dist_value);
    end

    function edge_stat = UpdateChannelHistory(Algo, edge_stat, offspring, info, rank1, n_parent)
        for i = 1:length(offspring)
            if ~info.IsTransferred(i)
                continue;
            end
            state_id = info.StateId(i);
            selected = rank1(i) <= n_parent;
            cv_improve = offspring(i).CV < info.ParentCV(i);
            became_feasible = info.ParentCV(i) > 0 && offspring(i).CV <= 0;
            obj_improve = info.ParentCV(i) <= 0 && offspring(i).CV <= 0 && offspring(i).Obj < info.ParentObj(i);
            reward = 0.35 * selected + 0.25 * cv_improve + 0.20 * became_feasible + 0.20 * obj_improve;
            edge_stat.Success(state_id) = (1 - Algo.HistAlpha) * edge_stat.Success(state_id) + Algo.HistAlpha * reward;
        end
    end

    function Log = InitLog(~, Prob)
        Log = struct();
        Log.ProbName = Prob.Name;
        Log.T = Prob.T;
        Log.FE = [];
        Log.FE_Ratio = [];
        Log.Epsilon = [];
        Log.Partner = [];
        Log.StateCountF = [];
        Log.StateCountB = [];
        Log.StateCountI = [];
        Log.TrustMeanF = [];
        Log.TrustMeanB = [];
        Log.TrustMeanI = [];
        Log.TryCountF = [];
        Log.TryCountB = [];
        Log.TryCountI = [];
        Log.AcceptCountF = [];
        Log.AcceptCountB = [];
        Log.AcceptCountI = [];
        Log.SurviveCountF = [];
        Log.SurviveCountB = [];
        Log.SurviveCountI = [];
        Log.CVImproveCountF = [];
        Log.CVImproveCountB = [];
        Log.CVImproveCountI = [];
        Log.BecomeFeasibleCountF = [];
        Log.BecomeFeasibleCountB = [];
        Log.BecomeFeasibleCountI = [];
    end

    function Log = RecordTransferStats(~, Log, gen, t, info, edge_stat, offspring, rank1, n_parent)
        for state_id = 1:3
            mask = info.StateId == state_id;
            trans_mask = mask & info.IsTransferred;
            try_count = sum(mask);
            accept_count = sum(trans_mask);
            survive_count = sum(trans_mask & (rank1(1:length(info.IsTransferred))' <= n_parent)');
            cv_improve_count = sum(trans_mask & ([offspring.CV] < info.ParentCV));
            become_feasible_count = sum(trans_mask & (info.ParentCV > 0) & ([offspring.CV] <= 0));
            trust_mean = mean(info.Trust(mask), 'omitnan');
            if isnan(trust_mean)
                trust_mean = edge_stat.Success(state_id);
            end
            switch state_id
                case 1
                    Log.TrustMeanF(gen, t) = trust_mean;
                    Log.TryCountF(gen, t) = try_count;
                    Log.AcceptCountF(gen, t) = accept_count;
                    Log.SurviveCountF(gen, t) = survive_count;
                    Log.CVImproveCountF(gen, t) = cv_improve_count;
                    Log.BecomeFeasibleCountF(gen, t) = become_feasible_count;
                case 2
                    Log.TrustMeanB(gen, t) = trust_mean;
                    Log.TryCountB(gen, t) = try_count;
                    Log.AcceptCountB(gen, t) = accept_count;
                    Log.SurviveCountB(gen, t) = survive_count;
                    Log.CVImproveCountB(gen, t) = cv_improve_count;
                    Log.BecomeFeasibleCountB(gen, t) = become_feasible_count;
                case 3
                    Log.TrustMeanI(gen, t) = trust_mean;
                    Log.TryCountI(gen, t) = try_count;
                    Log.AcceptCountI(gen, t) = accept_count;
                    Log.SurviveCountI(gen, t) = survive_count;
                    Log.CVImproveCountI(gen, t) = cv_improve_count;
                    Log.BecomeFeasibleCountI(gen, t) = become_feasible_count;
            end
        end
    end

    function edge_stat = EmptyEdgeStat(~)
        edge_stat.Success = [0.5, 0.5, 0.5];
    end

    function state_id = StateIdFromCV(~, cv, meta)
        if cv <= 0
            state_id = 1;
        elseif cv <= meta.BoundaryCenter(1) + inf
            state_id = 2;
        else
            state_id = 3;
        end
    end

    function base_rmp = StateBaseRMP(Algo, state_id)
        switch state_id
            case 1
                base_rmp = Algo.RMP_F;
            case 2
                base_rmp = Algo.RMP_B;
            otherwise
                base_rmp = Algo.RMP_I;
        end
    end
end
end
```

- [ ] **Step 3: 运行最小 smoke test，确认新类已能被加载并完整跑通一遍**

Run:
```bash
matlab -batch "cd('MTO'); prob = CMT5(); prob.maxFE = 2000; algo = CEDA_MP_TRUSTCHANNEL(); algo.Save_Log = false; mto({algo}, {prob}, 'Reps', 1, 'Global_Seed', 2333);"
```

Expected: PASS，MATLAB 退出码为 0，没有类加载错误、字段错误或维度错误。

- [ ] **Step 4: 提交骨架版本**

```bash
git add "MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m"
git commit -m "Add CEDA trust-channel algorithm skeleton"
```

---

### Task 2: 实现 `F/B/I` 状态划分与 state-aware mapping

**Files:**
- Modify: `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m`

- [ ] **Step 1: 运行状态日志失败检查，确认当前骨架还没有真实状态划分能力**

Run:
```bash
matlab -batch "cd('MTO'); prob = CMT5(); prob.maxFE = 2000; algo = CEDA_MP_TRUSTCHANNEL(); algo.Save_Log = true; algo.LogName = 'CEDA_MP_TRUSTCHANNEL_Log.mat'; mto({algo}, {prob}, 'Reps', 1, 'Global_Seed', 2333); load('CEDA_MP_TRUSTCHANNEL_Log.mat','Log'); assert(any(Log.StateCountB(:) > 0) && any(Log.StateCountI(:) > 0), 'state partition is still degenerate');"
```

Expected: FAIL，断言失败，提示 `state partition is still degenerate` 或等价信息。

- [ ] **Step 2: 用真实的状态划分和 state-aware mapping 替换简化方法，并新增 `SelectStatePopulation`**

将 `PartitionConstraintStates`、`BuildStateAwareMaps`、`StateIdFromCV` 三个方法替换为以下实现：

```matlab
    function state = PartitionConstraintStates(Algo, pop)
        cv = [pop.CV];
        obj = [pop.Obj];
        feasible_idx = find(cv <= 0);
        infeasible_idx = find(cv > 0);

        if isempty(feasible_idx)
            state.FIdx = [];
        else
            take_f = min(numel(feasible_idx), max(1, ceil(Algo.StateTopF * numel(feasible_idx))));
            [~, ord_f] = sort(obj(feasible_idx), 'ascend');
            state.FIdx = feasible_idx(ord_f(1:take_f));
        end

        if isempty(infeasible_idx)
            state.BIdx = [];
            state.IIdx = [];
            state.BoundaryCV = 0;
        else
            take_b = min(numel(infeasible_idx), max(1, ceil(Algo.StateTopB * numel(infeasible_idx))));
            [sorted_cv, ord_b] = sort(cv(infeasible_idx), 'ascend');
            state.BIdx = infeasible_idx(ord_b(1:take_b));
            if take_b < numel(infeasible_idx)
                state.IIdx = infeasible_idx(ord_b(take_b + 1:end));
            else
                state.IIdx = [];
            end
            state.BoundaryCV = sorted_cv(take_b);
        end

        state.FPop = Algo.SelectStatePopulation(pop, state.FIdx, 'lowcv');
        state.BPop = Algo.SelectStatePopulation(pop, state.BIdx, 'lowcv');
        state.IPop = Algo.SelectStatePopulation(pop, state.IIdx, 'highcv');
        state.FCenter = mean(state.FPop.Decs, 1);
        state.BCenter = mean(state.BPop.Decs, 1);
        state.ICenter = mean(state.IPop.Decs, 1);
        state.FScale = std(state.FPop.Decs, 0, 1) + 1e-12;
        state.BScale = std(state.BPop.Decs, 0, 1) + 1e-12;
        state.IScale = std(state.IPop.Decs, 0, 1) + 1e-12;
    end

    function chosen = SelectStatePopulation(Algo, pop, idx, mode_name)
        if numel(idx) >= Algo.StateMinSize
            chosen = pop(idx);
            return;
        end

        cv = [pop.CV];
        switch mode_name
            case 'lowcv'
                [~, order] = sort(cv, 'ascend');
            otherwise
                [~, order] = sort(cv, 'descend');
        end
        take = min(length(pop), max(Algo.StateMinSize, 2));
        chosen = pop(order(1:take));
    end

    function [maps, meta] = BuildStateAwareMaps(~, population, transpop, dst_state, src_state)
        dst_channels = {dst_state.FPop, dst_state.BPop, dst_state.IPop};
        src_channels = {src_state.FPop, src_state.BPop, src_state.IPop};
        for state_id = 1:3
            maps{state_id}.FromSrc = CEDA_trans(src_channels{state_id}, dst_channels{state_id}, transpop.Decs);
            maps{state_id}.FromDst = CEDA_trans(dst_channels{state_id}, src_channels{state_id}, population.Decs);
        end
        meta.BoundaryCV = dst_state.BoundaryCV;
        meta.StateCenter = {dst_state.FCenter, dst_state.BCenter, dst_state.ICenter};
        meta.StateScale = {dst_state.FScale, dst_state.BScale, dst_state.IScale};
        meta.BoundaryCenter = dst_state.BCenter;
    end

    function state_id = StateIdFromCV(~, cv, meta)
        if cv <= 0
            state_id = 1;
        elseif meta.BoundaryCV > 0 && cv <= meta.BoundaryCV
            state_id = 2;
        else
            state_id = 3;
        end
    end
```

- [ ] **Step 3: 运行状态检查，确认 `F/B/I` 三类统计已真实分离**

Run:
```bash
matlab -batch "cd('MTO'); prob = CMT5(); prob.maxFE = 2000; algo = CEDA_MP_TRUSTCHANNEL(); algo.Save_Log = true; algo.LogName = 'CEDA_MP_TRUSTCHANNEL_Log.mat'; mto({algo}, {prob}, 'Reps', 1, 'Global_Seed', 2333); load('CEDA_MP_TRUSTCHANNEL_Log.mat','Log'); assert(any(Log.StateCountF(:) > 0), 'missing F state'); assert(any(Log.StateCountB(:) > 0), 'missing B state'); assert(any(Log.StateCountI(:) > 0), 'missing I state');"
```

Expected: PASS，三个断言全部通过。

- [ ] **Step 4: 提交状态划分与映射版本**

```bash
git add "MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m"
git commit -m "Implement trust-channel state partition"
```

---

### Task 3: 实现 trust 评分与按状态注入的 `Generation1`

**Files:**
- Modify: `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m`

- [ ] **Step 1: 先运行 trust 有界性检查，确认当前 trust 仍然是简化版本**

Run:
```bash
matlab -batch "cd('MTO'); prob = CMT5(); prob.maxFE = 2000; algo = CEDA_MP_TRUSTCHANNEL(); algo.Save_Log = true; algo.LogName = 'CEDA_MP_TRUSTCHANNEL_Log.mat'; mto({algo}, {prob}, 'Reps', 1, 'Global_Seed', 2333); load('CEDA_MP_TRUSTCHANNEL_Log.mat','Log'); assert(std(Log.TrustMeanF(:), 0, 'omitnan') > 1e-6 || std(Log.TrustMeanB(:), 0, 'omitnan') > 1e-6 || std(Log.TrustMeanI(:), 0, 'omitnan') > 1e-6, 'trust is still effectively constant');"
```

Expected: FAIL，断言失败，提示 `trust is still effectively constant` 或等价信息。

- [ ] **Step 2: 替换 `EstimateTransferTrust`、`InjectByTrust`、`NormalizeDistanceScore` 三个方法**

将这三个方法替换为以下实现：

```matlab
    function [population, info] = InjectByTrust(Algo, population, maps, meta, edge_stat)
        info.ParentTransferred = false(1, length(population));
        info.ParentStateId = zeros(1, length(population));
        info.ParentTrust = zeros(1, length(population));
        for i = 1:length(population)
            state_id = Algo.StateIdFromCV(population(i).CV, meta);
            trust = Algo.EstimateTransferTrust(population(i).Dec, state_id, meta, edge_stat);
            base_rmp = Algo.StateBaseRMP(state_id);
            info.ParentStateId(i) = state_id;
            info.ParentTrust(i) = trust;
            if rand() < base_rmp * trust
                if rand() < 0.5
                    population(i).Dec = maps{state_id}.FromSrc(randi(size(maps{state_id}.FromSrc, 1)), :);
                else
                    population(i).Dec = maps{state_id}.FromDst(randi(size(maps{state_id}.FromDst, 1)), :);
                end
                info.ParentTransferred(i) = true;
            end
        end
    end

    function trust = EstimateTransferTrust(Algo, dec, state_id, meta, edge_stat)
        center = meta.StateCenter{state_id};
        scale = meta.StateScale{state_id};
        compat_dist = norm((dec - center) ./ scale);
        compat = Algo.NormalizeDistanceScore(compat_dist);
        boundary_dist = norm(dec - meta.BoundaryCenter);
        boundary = Algo.NormalizeDistanceScore(boundary_dist);
        history = edge_stat.Success(state_id);
        trust = Algo.Trust_WCompat * compat + Algo.Trust_WBoundary * boundary + Algo.Trust_WHistory * history;
        trust = min(max(trust, 0), 1);
    end

    function score = NormalizeDistanceScore(~, dist_value)
        score = 1 / (1 + dist_value);
    end
```

- [ ] **Step 3: 用真实的 `Generation1` 元数据替换骨架版本**

将 `Generation1` 方法替换为以下实现：

```matlab
    function [offspring, info] = Generation1(Algo, population, pool, transpop, dst_state, src_state, edge_stat)
        population = population(pool);
        [maps, state_meta] = Algo.BuildStateAwareMaps(population, transpop, dst_state, src_state);
        [population, info] = Algo.InjectByTrust(population, maps, state_meta, edge_stat);

        n_off = ceil(length(population) / 2);
        parent_cv = nan(1, n_off);
        parent_obj = nan(1, n_off);
        is_transferred = false(1, n_off);
        state_id = zeros(1, n_off);
        trust_value = zeros(1, n_off);

        for i = 1:n_off
            offspring(i) = population(i);
            p2 = i + fix(length(population) / 2);
            [offspring(i).Dec, tempDec] = GA_Crossover(population(i).Dec, population(p2).Dec, Algo.MuC);
            offspring(i).Dec = GA_Mutation(offspring(i).Dec, Algo.MuM);
            tempDec = GA_Mutation(tempDec, Algo.MuM);
            swap_indicator = rand(1, length(population(i).Dec)) >= 0.5;
            offspring(i).Dec(swap_indicator) = tempDec(swap_indicator);
            offspring(i).Dec = min(max(offspring(i).Dec, 0), 1);

            parent_cv(i) = population(i).CV;
            parent_obj(i) = population(i).Obj;
            is_transferred(i) = info.ParentTransferred(i) || info.ParentTransferred(p2);
            state_id(i) = info.ParentStateId(i);
            trust_value(i) = max(info.ParentTrust(i), info.ParentTrust(p2));
        end

        info.ParentCV = parent_cv;
        info.ParentObj = parent_obj;
        info.IsTransferred = is_transferred;
        info.StateId = state_id;
        info.Trust = trust_value;
    end
```

- [ ] **Step 4: 运行 trust 与注入检查，确认 trust 已变成有界、非常数的状态量**

Run:
```bash
matlab -batch "cd('MTO'); prob = CMT5(); prob.maxFE = 2000; algo = CEDA_MP_TRUSTCHANNEL(); algo.Save_Log = true; algo.LogName = 'CEDA_MP_TRUSTCHANNEL_Log.mat'; mto({algo}, {prob}, 'Reps', 1, 'Global_Seed', 2333); load('CEDA_MP_TRUSTCHANNEL_Log.mat','Log'); all_trust = [Log.TrustMeanF(:); Log.TrustMeanB(:); Log.TrustMeanI(:)]; all_trust = all_trust(~isnan(all_trust)); assert(~isempty(all_trust), 'missing trust data'); assert(all(all_trust >= 0 & all_trust <= 1), 'trust out of range'); assert(std(all_trust) > 1e-6, 'trust is still constant'); assert(any(Log.AcceptCountB(:) > 0) || any(Log.AcceptCountI(:) > 0) || any(Log.AcceptCountF(:) > 0), 'no trusted transfer accepted');"
```

Expected: PASS，所有断言通过。

- [ ] **Step 5: 提交 trust 注入版本**

```bash
git add "MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m"
git commit -m "Implement trust-coupled transfer injection"
```

---

### Task 4: 实现 history 更新与完整诊断日志

**Files:**
- Modify: `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m`

- [ ] **Step 1: 先运行 history 失败检查，确认当前日志还不能证明收益记忆在工作**

Run:
```bash
matlab -batch "cd('MTO'); prob = CMT6(); prob.maxFE = 2000; algo = CEDA_MP_TRUSTCHANNEL(); algo.Save_Log = true; algo.LogName = 'CEDA_MP_TRUSTCHANNEL_Log.mat'; mto({algo}, {prob}, 'Reps', 1, 'Global_Seed', 2333); load('CEDA_MP_TRUSTCHANNEL_Log.mat','Log'); assert(any(Log.CVImproveCountB(:) > 0) || any(Log.BecomeFeasibleCountB(:) > 0) || any(Log.SurviveCountB(:) > 0), 'history evidence is still too weak');"
```

Expected: 如果当前 history 更新与统计不完整，则 FAIL，断言提示 `history evidence is still too weak` 或等价信息。

- [ ] **Step 2: 替换 `UpdateChannelHistory` 与 `RecordTransferStats`，把历史奖励和日志统计补完整**

将这两个方法替换为以下实现：

```matlab
    function edge_stat = UpdateChannelHistory(Algo, edge_stat, offspring, info, rank1, n_parent)
        for i = 1:length(offspring)
            if ~info.IsTransferred(i)
                continue;
            end
            state_id = info.StateId(i);
            selected = rank1(i) <= n_parent;
            cv_improve = offspring(i).CV < info.ParentCV(i) - 1e-12;
            became_feasible = info.ParentCV(i) > 0 && offspring(i).CV <= 0;
            obj_improve = info.ParentCV(i) <= 0 && offspring(i).CV <= 0 && offspring(i).Obj < info.ParentObj(i);
            reward = 0.35 * selected + 0.25 * cv_improve + 0.20 * became_feasible + 0.20 * obj_improve;
            edge_stat.Success(state_id) = (1 - Algo.HistAlpha) * edge_stat.Success(state_id) + Algo.HistAlpha * reward;
        end
    end

    function Log = RecordTransferStats(~, Log, gen, t, info, edge_stat, offspring, rank1, n_parent)
        off_cv = [offspring.CV];
        for state_id = 1:3
            mask = info.StateId == state_id;
            trans_mask = mask & info.IsTransferred;
            selected_mask = false(size(trans_mask));
            selected_mask(1:length(rank1)) = rank1(1:length(trans_mask)) <= n_parent;
            try_count = sum(mask);
            accept_count = sum(trans_mask);
            survive_count = sum(trans_mask & selected_mask);
            cv_improve_count = sum(trans_mask & (off_cv < info.ParentCV - 1e-12));
            become_feasible_count = sum(trans_mask & (info.ParentCV > 0) & (off_cv <= 0));
            trust_mean = mean(info.Trust(mask), 'omitnan');
            if isnan(trust_mean)
                trust_mean = edge_stat.Success(state_id);
            end
            switch state_id
                case 1
                    Log.TrustMeanF(gen, t) = trust_mean;
                    Log.TryCountF(gen, t) = try_count;
                    Log.AcceptCountF(gen, t) = accept_count;
                    Log.SurviveCountF(gen, t) = survive_count;
                    Log.CVImproveCountF(gen, t) = cv_improve_count;
                    Log.BecomeFeasibleCountF(gen, t) = become_feasible_count;
                case 2
                    Log.TrustMeanB(gen, t) = trust_mean;
                    Log.TryCountB(gen, t) = try_count;
                    Log.AcceptCountB(gen, t) = accept_count;
                    Log.SurviveCountB(gen, t) = survive_count;
                    Log.CVImproveCountB(gen, t) = cv_improve_count;
                    Log.BecomeFeasibleCountB(gen, t) = become_feasible_count;
                case 3
                    Log.TrustMeanI(gen, t) = trust_mean;
                    Log.TryCountI(gen, t) = try_count;
                    Log.AcceptCountI(gen, t) = accept_count;
                    Log.SurviveCountI(gen, t) = survive_count;
                    Log.CVImproveCountI(gen, t) = cv_improve_count;
                    Log.BecomeFeasibleCountI(gen, t) = become_feasible_count;
            end
        end
    end
```

- [ ] **Step 3: 运行日志覆盖检查，确认关键字段都已被填充**

Run:
```bash
matlab -batch "cd('MTO'); prob = CMT6(); prob.maxFE = 2000; algo = CEDA_MP_TRUSTCHANNEL(); algo.Save_Log = true; algo.LogName = 'CEDA_MP_TRUSTCHANNEL_Log.mat'; mto({algo}, {prob}, 'Reps', 1, 'Global_Seed', 2333); load('CEDA_MP_TRUSTCHANNEL_Log.mat','Log'); must_have = {'StateCountF','StateCountB','StateCountI','TrustMeanF','TrustMeanB','TrustMeanI','AcceptCountF','AcceptCountB','AcceptCountI','CVImproveCountF','CVImproveCountB','CVImproveCountI','BecomeFeasibleCountF','BecomeFeasibleCountB','BecomeFeasibleCountI'}; for i = 1:numel(must_have); assert(isfield(Log, must_have{i}), ['missing field: ' must_have{i}]); end; assert(any(Log.CVImproveCountF(:) > 0 | Log.CVImproveCountB(:) > 0 | Log.CVImproveCountI(:) > 0), 'no CV improvement tracked');"
```

Expected: PASS，字段完整且至少有一类通道记录到 `CV` 改善。

- [ ] **Step 4: 提交 history 与日志版本**

```bash
git add "MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m"
git commit -m "Add trust-channel history diagnostics"
```

---

### Task 5: 添加诊断绘图脚本并完成端到端验证

**Files:**
- Create: `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/plot_CEDA_MP_TRUSTCHANNEL.m`
- Test: `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL_Log.mat`

- [ ] **Step 1: 创建 trust-channel 日志绘图脚本**

创建 `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/plot_CEDA_MP_TRUSTCHANNEL.m`，内容如下：

```matlab
function plot_CEDA_MP_TRUSTCHANNEL(logfile)
if nargin < 1
    logfile = 'CEDA_MP_TRUSTCHANNEL_Log.mat';
end

data = load(logfile);
Log = data.Log;
T = Log.T;
nGen = Log.TotalGen;
gens = 1:nGen;

fprintf('Problem: %s | Tasks: %d | Generations: %d\n', Log.ProbName, T, nGen);

figure('Name', 'State Counts', 'Position', [50 50 1200 800]);
for t = 1:T
    subplot(T, 1, t);
    plot(gens, Log.StateCountF(:, t), 'g-', 'LineWidth', 1.5); hold on;
    plot(gens, Log.StateCountB(:, t), 'b-', 'LineWidth', 1.5);
    plot(gens, Log.StateCountI(:, t), 'r-', 'LineWidth', 1.5);
    legend('F', 'B', 'I', 'Location', 'best');
    title(sprintf('Task %d State Counts', t));
    xlabel('Generation');
    ylabel('Count');
    grid on;
end

figure('Name', 'Mean Trust', 'Position', [80 80 1200 800]);
for t = 1:T
    subplot(T, 1, t);
    plot(gens, Log.TrustMeanF(:, t), 'g-', 'LineWidth', 1.5); hold on;
    plot(gens, Log.TrustMeanB(:, t), 'b-', 'LineWidth', 1.5);
    plot(gens, Log.TrustMeanI(:, t), 'r-', 'LineWidth', 1.5);
    ylim([0 1]);
    legend('F', 'B', 'I', 'Location', 'best');
    title(sprintf('Task %d Mean Trust', t));
    xlabel('Generation');
    ylabel('Trust');
    grid on;
end

figure('Name', 'Accepted Transfers', 'Position', [110 110 1200 800]);
for t = 1:T
    subplot(T, 1, t);
    bar(gens, [Log.AcceptCountF(:, t), Log.AcceptCountB(:, t), Log.AcceptCountI(:, t)], 'stacked');
    legend('F', 'B', 'I', 'Location', 'best');
    title(sprintf('Task %d Accepted Transfers', t));
    xlabel('Generation');
    ylabel('Count');
    grid on;
end

figure('Name', 'Constraint Gains', 'Position', [140 140 1200 800]);
for t = 1:T
    subplot(T, 2, 2 * t - 1);
    bar(gens, [Log.CVImproveCountF(:, t), Log.CVImproveCountB(:, t), Log.CVImproveCountI(:, t)], 'stacked');
    legend('F', 'B', 'I', 'Location', 'best');
    title(sprintf('Task %d CV Improvements', t));
    xlabel('Generation');
    ylabel('Count');
    grid on;

    subplot(T, 2, 2 * t);
    bar(gens, [Log.BecomeFeasibleCountF(:, t), Log.BecomeFeasibleCountB(:, t), Log.BecomeFeasibleCountI(:, t)], 'stacked');
    legend('F', 'B', 'I', 'Location', 'best');
    title(sprintf('Task %d Become Feasible', t));
    xlabel('Generation');
    ylabel('Count');
    grid on;
end
end
```

- [ ] **Step 2: 运行端到端诊断验证，确认算法与绘图脚本都能工作**

Run:
```bash
matlab -batch "cd('MTO'); prob = CMT5(); prob.maxFE = 3000; algo = CEDA_MP_TRUSTCHANNEL(); algo.Save_Log = true; algo.LogName = 'CEDA_MP_TRUSTCHANNEL_Log.mat'; mto({algo}, {prob}, 'Reps', 1, 'Global_Seed', 2333); plot_CEDA_MP_TRUSTCHANNEL('CEDA_MP_TRUSTCHANNEL_Log.mat');"
```

Expected: PASS，MATLAB 退出码为 0，生成四个图窗，没有 `missing field` 或维度不匹配错误。

- [ ] **Step 3: 运行最终对比 smoke test，确认新算法能与现有基线同场运行**

Run:
```bash
matlab -batch "cd('MTO'); prob1 = CMT5(); prob1.maxFE = 2000; prob2 = CMT6(); prob2.maxFE = 2000; algo1 = CEDA_MP(); algo2 = CEDA_MP_TRIGGER(); algo3 = CEDA_MP_DUALCHANNEL(); algo4 = CEDA_MP_TRUSTCHANNEL(); algo4.Save_Log = false; mto({algo1, algo2, algo3, algo4}, {prob1, prob2}, 'Reps', 1, 'Global_Seed', 2333);"
```

Expected: PASS，四个算法全部完成，无类加载、参数注册或日志副作用导致的报错。

- [ ] **Step 4: 提交绘图脚本与最终验证结果**

```bash
git add "MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m" "MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/plot_CEDA_MP_TRUSTCHANNEL.m"
git commit -m "Add CEDA trust-channel diagnostics plot"
```

---

## Self-Review Checklist

- Spec coverage:
  - `F/B/I` 状态划分由 Task 2 实现
  - state-aware mapping 由 Task 2 实现
  - trust 评估与 `RMP_state * trust` 注入由 Task 3 实现
  - history 更新与收益统计由 Task 4 实现
  - 日志与可视化由 Task 4 和 Task 5 实现
  - 基线对比 smoke test 由 Task 5 实现

- Placeholder scan:
  - 本计划未保留 `TBD`、`TODO`、`implement later`、`similar to` 等占位词
  - 每个代码改动步骤均给出明确代码块
  - 每个验证步骤均给出完整命令和预期结果

- Type consistency:
  - 属性名统一使用 `RMP_F`、`RMP_B`、`RMP_I`
  - 状态编号统一使用 `1=F`、`2=B`、`3=I`
  - 日志字段统一使用 `StateCount*`、`TrustMean*`、`AcceptCount*`、`CVImproveCount*`、`BecomeFeasibleCount*`
