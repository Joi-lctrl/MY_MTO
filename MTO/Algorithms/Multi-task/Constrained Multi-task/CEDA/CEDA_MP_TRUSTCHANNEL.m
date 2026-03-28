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
        info.ParentATransferred = false(1, n_off);
        info.ParentAStateId = zeros(1, n_off);
        info.ParentACV = nan(1, n_off);
        info.ParentAObj = nan(1, n_off);
        info.ParentATrust = nan(1, n_off);
        info.ParentBTransferred = false(1, n_off);
        info.ParentBStateId = zeros(1, n_off);
        info.ParentBCV = nan(1, n_off);
        info.ParentBObj = nan(1, n_off);
        info.ParentBTrust = nan(1, n_off);
        info.IsTransferred = false(1, n_off);
        for i = 1:n_off
            offspring(i) = population(i);
            p2 = i + fix(length(population) / 2);
            [offspring(i).Dec, tempDec] = GA_Crossover(population(i).Dec, population(p2).Dec, Algo.MuC);
            offspring(i).Dec = GA_Mutation(offspring(i).Dec, Algo.MuM);
            tempDec = GA_Mutation(tempDec, Algo.MuM);
            swap_indicator = rand(1, length(population(i).Dec)) >= 0.5;
            offspring(i).Dec(swap_indicator) = tempDec(swap_indicator);
            offspring(i).Dec = min(max(offspring(i).Dec, 0), 1);
            info.ParentATransferred(i) = info.ParentTransferred(i);
            info.ParentAStateId(i) = info.ParentStateId(i);
            info.ParentACV(i) = population(i).CV;
            info.ParentAObj(i) = population(i).Obj;
            info.ParentATrust(i) = info.ParentTrust(i);
            info.ParentBTransferred(i) = info.ParentTransferred(p2);
            info.ParentBStateId(i) = info.ParentStateId(p2);
            info.ParentBCV(i) = population(p2).CV;
            info.ParentBObj(i) = population(p2).Obj;
            info.ParentBTrust(i) = info.ParentTrust(p2);
            info.IsTransferred(i) = info.ParentATransferred(i) || info.ParentBTransferred(i);
        end
    end

    function offspring = Generation2(Algo, population, pool, transpop)
        population = population(pool);
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

        state.FPop = Algo.SelectStatePopulation(pop, state.FIdx, 'F');
        state.BPop = Algo.SelectStatePopulation(pop, state.BIdx, 'B');
        state.IPop = Algo.SelectStatePopulation(pop, state.IIdx, 'I');
        [trust_f_pop, trust_has_compat(1)] = Algo.SelectTrustPopulation(pop, state.FIdx, 'F');
        [trust_b_pop, trust_has_compat(2)] = Algo.SelectTrustPopulation(pop, state.BIdx, 'B');
        [trust_i_pop, trust_has_compat(3)] = Algo.SelectTrustPopulation(pop, state.IIdx, 'I');
        state.FCenter = mean(state.FPop.Decs, 1);
        state.BCenter = mean(state.BPop.Decs, 1);
        state.ICenter = mean(state.IPop.Decs, 1);
        state.FScale = max(std(state.FPop.Decs, 0, 1), 1e-3);
        state.BScale = max(std(state.BPop.Decs, 0, 1), 1e-3);
        state.IScale = max(std(state.IPop.Decs, 0, 1), 1e-3);
        [state.TrustCenter{1}, state.TrustScale{1}] = Algo.SummarizePopulationStats(trust_f_pop);
        [state.TrustCenter{2}, state.TrustScale{2}] = Algo.SummarizePopulationStats(trust_b_pop);
        [state.TrustCenter{3}, state.TrustScale{3}] = Algo.SummarizePopulationStats(trust_i_pop);
        state.TrustHasCompat = trust_has_compat;
        state.TrustHasBoundary = numel(state.BIdx) >= Algo.StateMinSize;
        if ~state.TrustHasBoundary
            state.TrustBoundaryCenter = [];
        else
            state.TrustBoundaryCenter = mean(trust_b_pop.Decs, 1);
        end
    end

    function chosen = SelectStatePopulation(Algo, pop, idx, mode_name)
        [ordered_idx, same_state_fill, cross_state_fill] = Algo.RankStateCandidates(pop, idx, mode_name);
        target_size = min(length(pop), max(Algo.StateMinSize, 2));

        if numel(idx) >= Algo.StateMinSize
            chosen = pop(ordered_idx);
            return;
        end

        chosen_idx = ordered_idx;
        need = target_size - numel(chosen_idx);
        if need > 0
            take = min(need, numel(same_state_fill));
            chosen_idx = [chosen_idx, same_state_fill(1:take)];
            need = target_size - numel(chosen_idx);
        end
        if need > 0
            remaining_cross = setdiff(cross_state_fill, chosen_idx, 'stable');
            take = min(need, numel(remaining_cross));
            chosen_idx = [chosen_idx, remaining_cross(1:take)];
        end
        chosen = pop(chosen_idx);
    end

    function [chosen, has_compat] = SelectTrustPopulation(Algo, pop, idx, mode_name)
        [ordered_idx, ~] = Algo.RankStateCandidates(pop, idx, mode_name);
        chosen = pop(ordered_idx);
        has_compat = numel(ordered_idx) >= Algo.StateMinSize;
    end

    function [ordered_idx, same_state_fill, cross_state_fill] = RankStateCandidates(~, pop, idx, mode_name)
        cv = [pop.CV];
        obj = [pop.Obj];
        feasible_idx = find(cv <= 0);
        infeasible_idx = find(cv > 0);

        [~, infeasible_low_order] = sort(cv(infeasible_idx), 'ascend');
        infeasible_low_idx = infeasible_idx(infeasible_low_order);
        [~, infeasible_high_order] = sort(cv(infeasible_idx), 'descend');
        infeasible_high_idx = infeasible_idx(infeasible_high_order);
        [~, feasible_order] = sort(obj(feasible_idx), 'ascend');
        feasible_best_idx = feasible_idx(feasible_order);

        switch mode_name
            case 'F'
                ordered_idx = feasible_best_idx(ismember(feasible_best_idx, idx));
                same_state_fill = setdiff(feasible_best_idx, ordered_idx, 'stable');
                % Cross the feasibility boundary only as a last resort.
                cross_state_fill = infeasible_low_idx;
            case 'B'
                ordered_idx = infeasible_low_idx(ismember(infeasible_low_idx, idx));
                same_state_fill = setdiff(infeasible_low_idx, ordered_idx, 'stable');
                % Fall back to feasible solutions only after exhausting positive-CV candidates.
                cross_state_fill = feasible_best_idx;
            otherwise
                ordered_idx = infeasible_high_idx(ismember(infeasible_high_idx, idx));
                same_state_fill = setdiff(infeasible_high_idx, ordered_idx, 'stable');
                % Fall back to feasible solutions only after exhausting positive-CV candidates.
                cross_state_fill = feasible_best_idx;
        end
    end

    function [center, scale] = SummarizePopulationStats(~, pop)
        if isempty(pop)
            center = [];
            scale = [];
            return;
        end
        center = mean(pop.Decs, 1);
        scale = max(std(pop.Decs, 0, 1), 1e-3);
    end

    function [maps, meta] = BuildStateAwareMaps(~, ~, ~, dst_state, src_state)
        dst_channels = {dst_state.FPop, dst_state.BPop, dst_state.IPop};
        src_channels = {src_state.FPop, src_state.BPop, src_state.IPop};
        dst_candidate_sets = {dst_state.FPop.Decs, dst_state.BPop.Decs, dst_state.IPop.Decs};
        src_candidate_sets = {src_state.FPop.Decs, src_state.BPop.Decs, src_state.IPop.Decs};
        maps = cell(1, 3);
        for state_id = 1:3
            maps{state_id}.FromSrc = CEDA_trans(src_channels{state_id}, dst_channels{state_id}, src_candidate_sets{state_id});
            maps{state_id}.FromDst = CEDA_trans(dst_channels{state_id}, src_channels{state_id}, dst_candidate_sets{state_id});
        end
        meta.BoundaryCV = dst_state.BoundaryCV;
        meta.TrustCenter = dst_state.TrustCenter;
        meta.TrustScale = dst_state.TrustScale;
        meta.TrustHasCompat = dst_state.TrustHasCompat;
        meta.TrustBoundaryCenter = dst_state.TrustBoundaryCenter;
        meta.TrustHasBoundary = dst_state.TrustHasBoundary;
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
        if meta.TrustHasCompat(state_id)
            center = meta.TrustCenter{state_id};
            scale = meta.TrustScale{state_id};
            compat_dist = norm((dec - center) ./ scale);
            compat = Algo.NormalizeDistanceScore(compat_dist);
        else
            compat = 0.5;
        end
        if meta.TrustHasBoundary
            boundary_dist = norm(dec - meta.TrustBoundaryCenter);
            boundary = Algo.NormalizeDistanceScore(boundary_dist);
        else
            boundary = 0.5;
        end
        history = edge_stat.Success(state_id);
        trust = Algo.Trust_WCompat * compat + Algo.Trust_WBoundary * boundary + Algo.Trust_WHistory * history;
        trust = min(max(trust, 0), 1);
    end

    function score = NormalizeDistanceScore(~, dist_value)
        score = 1 / (1 + dist_value);
    end

    function edge_stat = UpdateChannelHistory(Algo, edge_stat, offspring, info, rank1, n_parent)
        for i = 1:length(offspring)
            selected = any(rank1 == (n_parent + i));

            if info.ParentATransferred(i)
                state_id = info.ParentAStateId(i);
                cv_improve = offspring(i).CV < info.ParentACV(i) - 1e-12;
                became_feasible = info.ParentACV(i) > 0 && offspring(i).CV <= 0;
                obj_improve = info.ParentACV(i) <= 0 && offspring(i).CV <= 0 && offspring(i).Obj < info.ParentAObj(i) - 1e-12;
                reward = 0.35 * selected + 0.25 * cv_improve + 0.20 * became_feasible + 0.20 * obj_improve;
                edge_stat.Success(state_id) = (1 - Algo.HistAlpha) * edge_stat.Success(state_id) + Algo.HistAlpha * reward;
            end
            if info.ParentBTransferred(i)
                state_id = info.ParentBStateId(i);
                cv_improve = offspring(i).CV < info.ParentBCV(i) - 1e-12;
                became_feasible = info.ParentBCV(i) > 0 && offspring(i).CV <= 0;
                obj_improve = info.ParentBCV(i) <= 0 && offspring(i).CV <= 0 && offspring(i).Obj < info.ParentBObj(i) - 1e-12;
                reward = 0.35 * selected + 0.25 * cv_improve + 0.20 * became_feasible + 0.20 * obj_improve;
                edge_stat.Success(state_id) = (1 - Algo.HistAlpha) * edge_stat.Success(state_id) + Algo.HistAlpha * reward;
            end
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
            try_count = 0;
            accept_count = 0;
            survive_count = 0;
            cv_improve_count = 0;
            become_feasible_count = 0;
            trust_samples = [];
            for i = 1:length(offspring)
                if info.ParentAStateId(i) == state_id
                    try_count = try_count + 1;
                    trust_samples(end + 1) = info.ParentATrust(i);
                    if info.ParentATransferred(i)
                        accept_count = accept_count + 1;
                        if any(rank1 == (n_parent + i))
                            survive_count = survive_count + 1;
                        end
                        if offspring(i).CV < info.ParentACV(i) - 1e-12
                            cv_improve_count = cv_improve_count + 1;
                        end
                        if info.ParentACV(i) > 0 && offspring(i).CV <= 0
                            become_feasible_count = become_feasible_count + 1;
                        end
                    end
                end
                if info.ParentBStateId(i) == state_id
                    try_count = try_count + 1;
                    trust_samples(end + 1) = info.ParentBTrust(i);
                    if info.ParentBTransferred(i)
                        accept_count = accept_count + 1;
                        if any(rank1 == (n_parent + i))
                            survive_count = survive_count + 1;
                        end
                        if offspring(i).CV < info.ParentBCV(i) - 1e-12
                            cv_improve_count = cv_improve_count + 1;
                        end
                        if info.ParentBCV(i) > 0 && offspring(i).CV <= 0
                            become_feasible_count = become_feasible_count + 1;
                        end
                    end
                end
            end
            if isempty(trust_samples)
                trust_mean = edge_stat.Success(state_id);
            else
                trust_mean = mean(trust_samples, 'omitnan');
                if isnan(trust_mean)
                    trust_mean = edge_stat.Success(state_id);
                end
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
        elseif meta.BoundaryCV > 0 && cv <= meta.BoundaryCV
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
