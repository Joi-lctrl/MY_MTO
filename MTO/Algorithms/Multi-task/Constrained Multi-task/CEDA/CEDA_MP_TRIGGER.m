classdef CEDA_MP_TRIGGER < Algorithm
% <Multi-task> <Single-objective> <Constrained>

% CEDA-MP with trigger-based adaptive RMP.
% The update does not rely on average transfer rank. Instead, it rewards
% transfer only when it contributes useful search events, such as becoming
% the best selected source or producing a feasible improvement.

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
    RMP1_Init = 0.15
    RMP2 = 0
    RMP1_Min = 0.02
    RMP1_Max = 0.25
    RMP_Window = 20
    RMP_Alpha = 0.1
    Bonus_BestSource = 1.0
    Bonus_BeatBest = 0.6
    Weight_Survival = 0.2
    Penalty_NoTransfer = 0.15
    Save_Log = true
    LogName char = 'CEDA_MP_TRIGGER_Log.mat'
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'MuC: Simulated Binary Crossover', num2str(Algo.MuC), ...
                'MuM: Polynomial Mutation', num2str(Algo.MuM), ...
                'RMP1_Init', num2str(Algo.RMP1_Init), ...
                'RMP2', num2str(Algo.RMP2), ...
                'RMP1_Min', num2str(Algo.RMP1_Min), ...
                'RMP1_Max', num2str(Algo.RMP1_Max), ...
                'RMP_Window', num2str(Algo.RMP_Window), ...
                'RMP_Alpha', num2str(Algo.RMP_Alpha), ...
                'Bonus_BestSource', num2str(Algo.Bonus_BestSource), ...
                'Bonus_BeatBest', num2str(Algo.Bonus_BeatBest), ...
                'Weight_Survival', num2str(Algo.Weight_Survival), ...
                'Penalty_NoTransfer', num2str(Algo.Penalty_NoTransfer), ...
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
        Algo.RMP1_Init = str2double(Parameter{i}); i = i + 1;
        Algo.RMP2 = str2double(Parameter{i}); i = i + 1;
        Algo.RMP1_Min = str2double(Parameter{i}); i = i + 1;
        Algo.RMP1_Max = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_Window = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_Alpha = str2double(Parameter{i}); i = i + 1;
        Algo.Bonus_BestSource = str2double(Parameter{i}); i = i + 1;
        Algo.Bonus_BeatBest = str2double(Parameter{i}); i = i + 1;
        Algo.Weight_Survival = str2double(Parameter{i}); i = i + 1;
        Algo.Penalty_NoTransfer = str2double(Parameter{i}); i = i + 1;
        Algo.Save_Log = logical(str2double(Parameter{i})); i = i + 1;
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

        RMP1 = ones(1, Prob.T) * Algo.RMP1_Init;
        signal_hist = zeros(0, Prob.T);
        Log = struct();
        Log.ProbName = Prob.Name;
        Log.T = Prob.T;
        Log.RMP1_Init = Algo.RMP1_Init;
        Log.RMP1_Min = Algo.RMP1_Min;
        Log.RMP1_Max = Algo.RMP1_Max;
        Log.RMP_Window = Algo.RMP_Window;
        Log.RMP_Alpha = Algo.RMP_Alpha;

        while Algo.notTerminated(Prob, population2)
            for t = 1:Prob.T
                if Algo.FE < Algo.EC_Tc * Prob.maxFE
                    Ep = Ep0{t} * ((1 - Algo.FE / (Algo.EC_Tc * Prob.maxFE))^Algo.EC_Cp);
                else
                    Ep = 0;
                end
                CV = population1{t}.CVs;
                CV(CV < Ep) = 0;
                Obj = population1{t}.Objs;
                mating_pool1{t} = TournamentSelection(2, Prob.N, CV, Obj);
                mating_pool2{t} = TournamentSelection(2, Prob.N, population2{t}.CVs, population2{t}.Objs);
            end

            signal_hist(end + 1, :) = 0;
            gen = size(signal_hist, 1);
            Log.FE(gen, 1) = Algo.FE;
            Log.FE_ratio(gen, 1) = Algo.FE / Prob.maxFE;
            Log.RMP1_Before(gen, :) = RMP1;

            for t = 1:Prob.T
                k = randi(Prob.T);
                while k == t
                    k = randi(Prob.T);
                end
                Log.Partner(gen, t) = k;

                pre_best_feasible = Algo.getBestFeasibleObj(population1{t});
                [offspring1, is_trans] = Algo.Generation1(population1{t}, mating_pool1{t}, ...
                    population1{k}(mating_pool1{k}), RMP1(t));
                offspring2 = Algo.Generation2(population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));

                n_parent = length(population1{t});
                n_off1 = length(offspring1);
                offspring = [offspring1, offspring2];
                offspring = Algo.Evaluation(offspring, Prob, t);

                [population1{t}, rank1] = Selection_Elit(population1{t}, offspring, Ep);
                [population2{t}, rank2] = Selection_Elit(population2{t}, offspring, 0);

                signal_hist(gen, t) = Algo.getTriggerSignal( ...
                    offspring(1:n_off1), is_trans, rank1, rank2, n_parent, n_off1, pre_best_feasible);
                Log.TriggerSignal(gen, t) = signal_hist(gen, t);
                Log.TransferCount(gen, t) = sum(is_trans);
                Log.NormalCount(gen, t) = sum(~is_trans);
                RMP1(t) = Algo.updateRMP(RMP1(t), signal_hist(:, t));
                Log.RMP1_After(gen, t) = RMP1(t);
            end
        end

        if Algo.Save_Log
            Log.TotalGen = size(signal_hist, 1);
            save(Algo.LogName, 'Log');
            fprintf('[CEDA-MP-TRIGGER] Log saved to %s (%d generations, %d tasks)\n', ...
                Algo.LogName, Log.TotalGen, Prob.T);
        end
    end

    function [offspring, is_trans] = Generation1(Algo, population, pool, transpop, rmp)
        population = population(pool);
        population_temp = population;
        temp_Dec = CEDA_trans(transpop, population_temp, transpop.Decs);
        temp_Dec2 = CEDA_trans(population_temp, transpop, population.Decs);

        transferred = false(1, length(population));
        for i = 1:length(population)
            if rand() < rmp
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

    function best_obj = getBestFeasibleObj(~, population)
        obj = [population.Obj];
        cv = [population.CV];
        feasible_obj = obj(cv == 0);
        if isempty(feasible_obj)
            best_obj = min(obj, [], 'omitnan');
        else
            best_obj = min(feasible_obj, [], 'omitnan');
        end
    end

    function signal = getTriggerSignal(Algo, off1, is_trans, rank1, rank2, n_parent, n_off1, pre_best_feasible)
        signal = 0;
        if isempty(off1)
            signal = -Algo.Penalty_NoTransfer;
            return;
        end

        if ~any(is_trans)
            signal = -Algo.Penalty_NoTransfer;
            return;
        end

        off1_obj = off1.Objs;
        off1_cv = off1.CVs;
        trans_idx = find(is_trans);
        normal_idx = find(~is_trans);

        trans_feasible_obj = off1_obj(trans_idx(off1_cv(trans_idx) == 0));
        if ~isempty(trans_feasible_obj) && min(trans_feasible_obj, [], 'omitnan') < pre_best_feasible
            signal = signal + Algo.Bonus_BeatBest;
        end

        if Algo.getSourceCode(rank1(1), n_parent, n_off1, is_trans) == 1
            signal = signal + Algo.Bonus_BestSource;
        end
        if Algo.getSourceCode(rank2(1), n_parent, n_off1, is_trans) == 1
            signal = signal + Algo.Bonus_BestSource;
        end

        if ~isempty(normal_idx)
            selected_off1 = rank1(rank1 > n_parent) - n_parent;
            selected_off1 = selected_off1(selected_off1 <= n_off1);
            trans_survival = sum(is_trans(selected_off1)) / numel(trans_idx);
            normal_survival = sum(~is_trans(selected_off1)) / numel(normal_idx);
            signal = signal + Algo.Weight_Survival * (trans_survival - normal_survival);
        end
    end

    function rmp = updateRMP(Algo, curr_rmp, signal_hist)
        window_len = min(Algo.RMP_Window, numel(signal_hist));
        window_signal = mean(signal_hist(end - window_len + 1:end), 'omitnan');
        target_rmp = curr_rmp + window_signal * Algo.RMP_Alpha;
        target_rmp = max(Algo.RMP1_Min, min(Algo.RMP1_Max, target_rmp));
        rmp = (1 - Algo.RMP_Alpha) * curr_rmp + Algo.RMP_Alpha * target_rmp;
        rmp = max(Algo.RMP1_Min, min(Algo.RMP1_Max, rmp));
    end

    function code = getSourceCode(~, selected_rank, n_parent, n_off1, is_trans)
        if selected_rank <= n_parent
            code = 0;
            return;
        end

        offspring_idx = selected_rank - n_parent;
        if offspring_idx <= n_off1
            if is_trans(offspring_idx)
                code = 1;
            else
                code = 2;
            end
        else
            code = 3;
        end
    end
end
end
