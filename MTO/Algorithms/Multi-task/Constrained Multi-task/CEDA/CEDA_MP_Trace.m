classdef CEDA_MP_Trace < Algorithm
% <Multi-task> <Single-objective> <Constrained>

% Traceable version of CEDA_MP.
% This class keeps the original algorithm logic unchanged, while recording
% per-generation diagnostics for mechanism analysis.

%------------------------------- Reference --------------------------------
% @Article{Zhang2024CEDA,
%   author     = {Tingyu Zhang and Dongcheng Li and Yanchi Li and Wenyin Gong},
%   journal    = {Swarm and Evolutionary Computation},
%   title      = {Constrained Multitasking Optimization Via Co-Evolution and Domain Adaptation},
%   year       = {2024},
%   issn       = {2210-6502},
%   pages      = {101570},
%   volume     = {87},
%   doi        = {https://doi.org/10.1016/j.swevo.2024.101570},
% }
%--------------------------------------------------------------------------

%------------------------------- Copyright --------------------------------
% Copyright (c) Yanchi Li. You are free to use the MToP for research
% purposes. All publications which use this platform should acknowledge
% the use of MToP and cite as "Y. Li, W. Gong, T. Zhang, F. Ming,
% S. Li, Q. Gu, and Y.-S. Ong, MToP: A MATLAB Benchmarking Platform for
% Evolutionary Multitasking, 2023, arXiv:2312.08134"
%--------------------------------------------------------------------------

properties (SetAccess = public)
    EC_Top = 0.2
    EC_Tc = 0.8
    EC_Cp = 5
    MuC = 2
    MuM = 5
    RMP1 = 0.15
    RMP2 = 0
    LogName char = 'CEDA_MP_Trace_Log.mat'
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'RMP1', num2str(Algo.RMP1), ...
                'RMP2', num2str(Algo.RMP2), ...
                'LogName', Algo.LogName};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.EC_Top = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Tc = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Cp = str2double(Parameter{i}); i = i + 1;
        Algo.RMP1 = str2double(Parameter{i}); i = i + 1;
        Algo.RMP2 = str2double(Parameter{i}); i = i + 1;
        Algo.LogName = Parameter{i};
    end

    function run(Algo, Prob)
        population1 = Initialization(Algo, Prob, Individual);
        population2 = Initialization(Algo, Prob, Individual);

        Ep0 = cell(1, Prob.T);
        for t = 1:Prob.T
            n = ceil(Algo.EC_Top * length(population1{t}));
            cv_temp = [population1{t}.CV];
            [~, idx] = sort(cv_temp);
            Ep0{t} = cv_temp(idx(n));
        end

        Log = struct();
        Log.ProbName = Prob.Name;
        Log.T = Prob.T;
        Log.RMP1 = Algo.RMP1;
        Log.RMP2 = Algo.RMP2;
        Log.EC_Top = Algo.EC_Top;
        Log.EC_Tc = Algo.EC_Tc;
        Log.EC_Cp = Algo.EC_Cp;

        gen = 0;
        while Algo.notTerminated(Prob, population2)
            gen = gen + 1;
            Log.FE(gen, 1) = Algo.FE;
            Log.FE_ratio(gen, 1) = Algo.FE / Prob.maxFE;

            for t = 1:Prob.T
                if Algo.FE < Algo.EC_Tc * Prob.maxFE
                    Ep = Ep0{t} * ((1 - Algo.FE / (Algo.EC_Tc * Prob.maxFE))^Algo.EC_Cp);
                else
                    Ep = 0;
                end
                Ep_vals(t) = Ep;
                CV = population1{t}.CVs;
                CV(CV < Ep_vals(t)) = 0;
                Obj = population1{t}.Objs;
                mating_pool1{t} = TournamentSelection(2, Prob.N, CV, Obj);
                mating_pool2{t} = TournamentSelection(2, Prob.N, population2{t}.CVs, population2{t}.Objs);

                Log.Epsilon(gen, t) = Ep_vals(t);
                pre1 = Algo.getPopulationStats(population1{t});
                pre2 = Algo.getPopulationStats(population2{t});
                Log = Algo.writePopulationStats(Log, gen, t, 'Pop1_Pre', pre1);
                Log = Algo.writePopulationStats(Log, gen, t, 'Pop2_Pre', pre2);
            end

            % Preserve original CEDA_MP behavior exactly:
            % Ep used in selection is the last scalar value left from the
            % previous loop, not the task-wise Ep_vals(t).
            Log.EpSelectionScalar(gen, 1) = Ep;

            for t = 1:Prob.T
                k = randi(Prob.T);
                while k == t
                    k = randi(Prob.T);
                end
                Log.Partner(gen, t) = k;

                [offspring1, is_trans] = Algo.Generation1_Track( ...
                    population1{t}, mating_pool1{t}, population1{k}(mating_pool1{k}));
                offspring2 = Algo.Generation2( ...
                    population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));

                n_parent = length(population1{t});
                n_off1 = length(offspring1);
                offspring = [offspring1, offspring2];
                offspring = Algo.Evaluation(offspring, Prob, t);

                off1_eval = offspring(1:n_off1);
                off2_eval = offspring(n_off1 + 1:end);

                Log = Algo.writeOffspringStats(Log, gen, t, off1_eval, is_trans, Ep_vals(t), pre1.BestFeasibleObj);
                Log = Algo.writePopulationStats(Log, gen, t, 'Off2', Algo.getPopulationStats(off2_eval));

                [population1{t}, rank1] = Selection_Elit(population1{t}, offspring, Ep);
                [population2{t}, rank2] = Selection_Elit(population2{t}, offspring, 0);

                post1 = Algo.getPopulationStats(population1{t});
                post2 = Algo.getPopulationStats(population2{t});
                Log = Algo.writePopulationStats(Log, gen, t, 'Pop1_Post', post1);
                Log = Algo.writePopulationStats(Log, gen, t, 'Pop2_Post', post2);
                Log = Algo.writeImprovementStats(Log, gen, t, pre1, pre2, post1, post2);
                Log = Algo.writeBestSourceStats(Log, gen, t, rank1(1), rank2(1), n_parent, n_off1, is_trans);

                Log = Algo.writeSelectionStats(Log, gen, t, rank1, n_parent, n_off1, is_trans, 'Pop1');
                Log = Algo.writeSelectionStats(Log, gen, t, rank2, n_parent, n_off1, is_trans, 'Pop2');
            end
        end

        Log.TotalGen = gen;
        save(Algo.LogName, 'Log');
        fprintf('[CEDA-MP-Trace] Log saved to %s (%d generations, %d tasks)\n', ...
            Algo.LogName, gen, Prob.T);
    end

    function [offspring, is_trans] = Generation1_Track(Algo, population, pool, transpop)
        population = population(pool);
        population_temp = population;
        temp_Dec = CEDA_trans(transpop, population_temp, transpop.Decs);
        temp_Dec2 = CEDA_trans(population_temp, transpop, population.Decs);

        transferred = false(1, length(population));
        for i = 1:length(population)
            if rand() < Algo.RMP1
                transferred(i) = true;
                if rand() < 0.5
                    population(i).Dec = temp_Dec(randi(end), :);
                else
                    population(i).Dec = temp_Dec2(randi(end), :);
                end
            end
        end

        n_off = ceil(length(population) / 2);
        is_trans = false(1, n_off);
        for i = 1:n_off
            offspring(i) = population(i);
            p2 = i + fix(length(population) / 2);
            is_trans(i) = transferred(i) || transferred(p2);

            [offspring(i).Dec, tempDec] = GA_Crossover(population(i).Dec, population(p2).Dec, Algo.MuC);
            offspring(i).Dec = GA_Mutation(offspring(i).Dec, Algo.MuM);
            tempDec = GA_Mutation(tempDec, Algo.MuM);
            swap_indicator = (rand(1, length(population(i).Dec)) >= 0.5);
            offspring(i).Dec(swap_indicator) = tempDec(swap_indicator);

            offspring(i).Dec(offspring(i).Dec > 1) = 1;
            offspring(i).Dec(offspring(i).Dec < 0) = 0;
        end
    end

    function offspring = Generation2(Algo, population, pool, transpop)
        population = population(pool);
        population_temp = population;
        temp_Dec = CEDA_trans(transpop, population_temp, transpop.Decs);
        temp_Dec2 = CEDA_trans(population_temp, transpop, population.Decs);
        for i = 1:length(population)
            if rand() < Algo.RMP2
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
            swap_indicator = (rand(1, length(population(i).Dec)) >= 0.5);
            offspring(i).Dec(swap_indicator) = tempDec(swap_indicator);

            offspring(i).Dec(offspring(i).Dec > 1) = 1;
            offspring(i).Dec(offspring(i).Dec < 0) = 0;
        end
    end

    function stats = getPopulationStats(~, population)
        obj = [population.Obj];
        cv = [population.CV];
        feasible_obj = obj(cv == 0);

        if isempty(feasible_obj)
            best_feasible_obj = min(obj, [], 'omitnan');
        else
            best_feasible_obj = min(feasible_obj, [], 'omitnan');
        end

        stats.BestFeasibleObj = best_feasible_obj;
        stats.BestCV = min(cv, [], 'omitnan');
        stats.MeanObj = mean(obj, 'omitnan');
        stats.MeanCV = mean(cv, 'omitnan');
        stats.FeasRate = mean(cv == 0);
        stats.Diversity = mean(std(population.Decs, 0, 1), 'omitnan');
    end

    function Log = writePopulationStats(~, Log, gen, t, prefix, stats)
        Log.([prefix, '_BestFeasibleObj'])(gen, t) = stats.BestFeasibleObj;
        Log.([prefix, '_BestCV'])(gen, t) = stats.BestCV;
        Log.([prefix, '_MeanObj'])(gen, t) = stats.MeanObj;
        Log.([prefix, '_MeanCV'])(gen, t) = stats.MeanCV;
        Log.([prefix, '_FeasRate'])(gen, t) = stats.FeasRate;
        Log.([prefix, '_Diversity'])(gen, t) = stats.Diversity;
    end

    function Log = writeOffspringStats(Algo, Log, gen, t, offspring, is_trans, Ep, pre_best_feasible_obj)
        obj = offspring.Objs;
        cv = offspring.CVs;
        relaxed_cv = cv;
        relaxed_cv(relaxed_cv <= Ep) = 0;

        strict_rank = Algo.getRankVector(cv, obj);
        relaxed_rank = Algo.getRankVector(relaxed_cv, obj);
        top_count = floor(length(offspring) / 2);

        trans_idx = find(is_trans);
        normal_idx = find(~is_trans);

        Log.Off1_TransCount(gen, t) = numel(trans_idx);
        Log.Off1_NormalCount(gen, t) = numel(normal_idx);

        [Log.Off1_Trans_AvgRankStrict(gen, t), Log.Off1_Trans_TopHalfStrict(gen, t), ...
            Log.Off1_Trans_MeanObj(gen, t), Log.Off1_Trans_MeanCV(gen, t), ...
            Log.Off1_Trans_FeasRate(gen, t)] = ...
            Algo.getSubsetStats(trans_idx, strict_rank, obj, cv, top_count);

        [Log.Off1_Normal_AvgRankStrict(gen, t), Log.Off1_Normal_TopHalfStrict(gen, t), ...
            Log.Off1_Normal_MeanObj(gen, t), Log.Off1_Normal_MeanCV(gen, t), ...
            Log.Off1_Normal_FeasRate(gen, t)] = ...
            Algo.getSubsetStats(normal_idx, strict_rank, obj, cv, top_count);

        [Log.Off1_Trans_AvgRankRelaxed(gen, t), Log.Off1_Trans_TopHalfRelaxed(gen, t), ...
            ~, ~, ~] = ...
            Algo.getSubsetStats(trans_idx, relaxed_rank, obj, relaxed_cv, top_count);

        [Log.Off1_Normal_AvgRankRelaxed(gen, t), Log.Off1_Normal_TopHalfRelaxed(gen, t), ...
            ~, ~, ~] = ...
            Algo.getSubsetStats(normal_idx, relaxed_rank, obj, relaxed_cv, top_count);

        trans_best = Algo.getSubsetBestStats(trans_idx, obj, cv, relaxed_cv);
        normal_best = Algo.getSubsetBestStats(normal_idx, obj, cv, relaxed_cv);
        Log = Algo.writeSubsetBestStats(Log, gen, t, 'Off1_Trans', trans_best, pre_best_feasible_obj);
        Log = Algo.writeSubsetBestStats(Log, gen, t, 'Off1_Normal', normal_best, pre_best_feasible_obj);
    end

    function Log = writeSelectionStats(~, Log, gen, t, rank, n_parent, n_off1, is_trans, prefix)
        selected_offspring = rank(rank > n_parent) - n_parent;
        selected_from_off1 = selected_offspring(selected_offspring <= n_off1);
        selected_from_off2 = selected_offspring(selected_offspring > n_off1) - n_off1;

        Log.([prefix, '_SelectedParentCount'])(gen, t) = sum(rank <= n_parent);
        Log.([prefix, '_SelectedOff1Count'])(gen, t) = numel(selected_from_off1);
        Log.([prefix, '_SelectedOff2Count'])(gen, t) = numel(selected_from_off2);
        Log.([prefix, '_SelectedTransCount'])(gen, t) = sum(is_trans(selected_from_off1));
        Log.([prefix, '_SelectedNormalCount'])(gen, t) = sum(~is_trans(selected_from_off1));

        if any(is_trans)
            Log.([prefix, '_TransSurvivalRate'])(gen, t) = ...
                sum(is_trans(selected_from_off1)) / sum(is_trans);
        else
            Log.([prefix, '_TransSurvivalRate'])(gen, t) = NaN;
        end

        if any(~is_trans)
            Log.([prefix, '_NormalSurvivalRate'])(gen, t) = ...
                sum(~is_trans(selected_from_off1)) / sum(~is_trans);
        else
            Log.([prefix, '_NormalSurvivalRate'])(gen, t) = NaN;
        end
    end

    function rank = getRankVector(~, cv, obj)
        n = numel(obj);
        [~, sorted_idx] = sortrows([cv(:), obj(:)], [1, 2]);
        rank = zeros(1, n);
        rank(sorted_idx) = 1:n;
    end

    function [avg_rank, top_rate, mean_obj, mean_cv, feas_rate] = ...
            getSubsetStats(~, idx, rank, obj, cv, top_count)
        if isempty(idx)
            avg_rank = NaN;
            top_rate = NaN;
            mean_obj = NaN;
            mean_cv = NaN;
            feas_rate = NaN;
            return;
        end

        avg_rank = mean(rank(idx), 'omitnan');
        top_rate = mean(rank(idx) <= top_count);
        mean_obj = mean(obj(idx), 'omitnan');
        mean_cv = mean(cv(idx), 'omitnan');
        feas_rate = mean(cv(idx) == 0);
    end

    function stats = getSubsetBestStats(~, idx, obj, cv, relaxed_cv)
        if isempty(idx)
            stats.BestObjStrict = NaN;
            stats.BestCVStrict = NaN;
            stats.BestObjRelaxed = NaN;
            stats.BestCVRelaxed = NaN;
            stats.BestFeasibleObj = NaN;
            stats.HasFeasible = false;
            return;
        end

        sub_obj = obj(idx);
        sub_cv = cv(idx);
        sub_relaxed_cv = relaxed_cv(idx);

        [~, strict_idx] = sortrows([sub_cv(:), sub_obj(:)], [1, 2]);
        [~, relaxed_idx] = sortrows([sub_relaxed_cv(:), sub_obj(:)], [1, 2]);

        stats.BestObjStrict = sub_obj(strict_idx(1));
        stats.BestCVStrict = sub_cv(strict_idx(1));
        stats.BestObjRelaxed = sub_obj(relaxed_idx(1));
        stats.BestCVRelaxed = sub_relaxed_cv(relaxed_idx(1));

        feasible_obj = sub_obj(sub_cv == 0);
        stats.HasFeasible = ~isempty(feasible_obj);
        if stats.HasFeasible
            stats.BestFeasibleObj = min(feasible_obj, [], 'omitnan');
        else
            stats.BestFeasibleObj = min(sub_obj, [], 'omitnan');
        end
    end

    function Log = writeSubsetBestStats(~, Log, gen, t, prefix, stats, pre_best_feasible_obj)
        Log.([prefix, '_BestObjStrict'])(gen, t) = stats.BestObjStrict;
        Log.([prefix, '_BestCVStrict'])(gen, t) = stats.BestCVStrict;
        Log.([prefix, '_BestObjRelaxed'])(gen, t) = stats.BestObjRelaxed;
        Log.([prefix, '_BestCVRelaxed'])(gen, t) = stats.BestCVRelaxed;
        Log.([prefix, '_BestFeasibleObj'])(gen, t) = stats.BestFeasibleObj;
        Log.([prefix, '_HasFeasible'])(gen, t) = stats.HasFeasible;
        Log.([prefix, '_BeatPop1PreBestFeasible'])(gen, t) = ...
            stats.HasFeasible && stats.BestFeasibleObj < pre_best_feasible_obj;
    end

    function Log = writeImprovementStats(~, Log, gen, t, pre1, pre2, post1, post2)
        Log.Pop1_PostBetterThanPre(gen, t) = post1.BestFeasibleObj < pre1.BestFeasibleObj;
        Log.Pop2_PostBetterThanPre(gen, t) = post2.BestFeasibleObj < pre2.BestFeasibleObj;
        Log.Pop1_ImprovementDelta(gen, t) = pre1.BestFeasibleObj - post1.BestFeasibleObj;
        Log.Pop2_ImprovementDelta(gen, t) = pre2.BestFeasibleObj - post2.BestFeasibleObj;
    end

    function Log = writeBestSourceStats(Algo, Log, gen, t, best_rank1, best_rank2, n_parent, n_off1, is_trans)
        Log.Pop1_BestSourceCode(gen, t) = Algo.getSourceCode(best_rank1, n_parent, n_off1, is_trans);
        Log.Pop2_BestSourceCode(gen, t) = Algo.getSourceCode(best_rank2, n_parent, n_off1, is_trans);
    end

    function code = getSourceCode(~, selected_rank, n_parent, n_off1, is_trans)
        if selected_rank <= n_parent
            code = 0; % parent
            return;
        end

        offspring_idx = selected_rank - n_parent;
        if offspring_idx <= n_off1
            if is_trans(offspring_idx)
                code = 1; % offspring1 transferred
            else
                code = 2; % offspring1 normal
            end
        else
            code = 3; % offspring2
        end
    end
end
end
