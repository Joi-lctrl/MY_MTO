classdef CEDA_MP_ARMP < Algorithm
% <Multi-task> <Single-objective> <Constrained>

% CEDA-MP with Adaptive RMP (ARMP)
% Improvement: RMP1 is dynamically adjusted per task based on transfer
% offspring quality feedback. Each generation, transferred and
% non-transferred offspring are ranked by feasibility-priority rule.
% If transferred offspring rank better on average, RMP1 increases;
% otherwise it decreases. Updated via exponential moving average.

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
    LP = 0.8        % Learning rate (inertia) for RMP1 update
    RMP1_Min = 0.05  % Lower bound of RMP1
    RMP1_Max = 0.5   % Upper bound of RMP1
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'MuC: Simulated Binary Crossover', num2str(Algo.MuC), ...
                'MuM: Polynomial Mutation', num2str(Algo.MuM), ...
                'RMP1_Init: Initial Transfer Probability', num2str(Algo.RMP1_Init), ...
                'RMP2', num2str(Algo.RMP2), ...
                'LP: RMP Learning Rate', num2str(Algo.LP), ...
                'RMP1_Min', num2str(Algo.RMP1_Min), ...
                'RMP1_Max', num2str(Algo.RMP1_Max)};
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
        Algo.LP = str2double(Parameter{i}); i = i + 1;
        Algo.RMP1_Min = str2double(Parameter{i}); i = i + 1;
        Algo.RMP1_Max = str2double(Parameter{i}); i = i + 1;
    end

    function run(Algo, Prob)
        % Initialization
        population1 = Initialization(Algo, Prob, Individual);
        population2 = Initialization(Algo, Prob, Individual);

        Ep0 = cell(1, Prob.T);
        for t = 1:Prob.T
            n = ceil(Algo.EC_Top * length(population1{t}));
            cv_temp = [population1{t}.CV];
            [~, idx] = sort(cv_temp);
            Ep0{t} = cv_temp(idx(n));
        end

        % Adaptive RMP1: one value per task
        RMP1 = ones(1, Prob.T) * Algo.RMP1_Init;

        while Algo.notTerminated(Prob, population2)
            for t = 1:Prob.T
                if Algo.FE < Algo.EC_Tc * Prob.maxFE
                    Ep = Ep0{t} * ((1 - Algo.FE / (Algo.EC_Tc * Prob.maxFE))^Algo.EC_Cp);
                else
                    Ep = 0;
                end
                CV = population1{t}.CVs; CV(CV < Ep) = 0;
                Obj = population1{t}.Objs;
                mating_pool1{t} = TournamentSelection(2, Prob.N, CV, Obj);
                mating_pool2{t} = TournamentSelection(2, Prob.N, population2{t}.CVs, population2{t}.Objs);
            end
            for t = 1:Prob.T
                k = randi(Prob.T);
                while k == t
                    k = randi(Prob.T);
                end

                % Generation with adaptive RMP1
                [offspring1, is_trans] = Algo.Generation1(population1{t}, mating_pool1{t}, population1{k}(mating_pool1{k}), RMP1(t));
                offspring2 = Algo.Generation2(population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));

                n_off1 = length(offspring1);
                offspring = [offspring1, offspring2];
                % Evaluation
                offspring = Algo.Evaluation(offspring, Prob, t);

                % --- Adaptive RMP1 Update ---
                n_trans = sum(is_trans);
                n_normal = sum(~is_trans);
                if n_trans >= 2 && n_normal >= 2
                    eval_off1 = offspring(1:n_off1);
                    off1_cv = eval_off1.CVs;
                    off1_obj = eval_off1.Objs;
                    % Rank by feasibility priority (CV first, then Obj)
                    [~, sorted_idx] = sortrows([off1_cv, off1_obj], [1, 2]);
                    rankings = zeros(n_off1, 1);
                    rankings(sorted_idx) = (1:n_off1)';

                    avg_rank_trans = mean(rankings(is_trans));
                    avg_rank_normal = mean(rankings(~is_trans));
                    % Positive delta means transfer offspring are better
                    delta = (avg_rank_normal - avg_rank_trans) / n_off1;
                    target_rmp = max(0, min(1, 0.5 + delta));

                    RMP1(t) = Algo.LP * RMP1(t) + (1 - Algo.LP) * target_rmp;
                    RMP1(t) = max(Algo.RMP1_Min, min(Algo.RMP1_Max, RMP1(t)));
                end

                % Selection
                population1{t} = Selection_Elit(population1{t}, offspring, Ep);
                population2{t} = Selection_Elit(population2{t}, offspring, 0);
            end
        end
    end

    function [offspring, is_trans] = Generation1(Algo, population, pool, transpop, rmp)
        population = population(pool);
        population_temp = population;
        temp_Dec = CEDA_trans(transpop, population_temp, transpop.Decs);
        temp_Dec2 = CEDA_trans(population_temp, transpop, population.Decs);

        % Apply domain adaptation transfer with probability rmp
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
            % Offspring is marked as transferred if either parent was transferred
            is_trans(i) = transferred(i) || transferred(p2);

            [offspring(i).Dec, tempDec] = GA_Crossover(population(i).Dec, population(p2).Dec, Algo.MuC);
            offspring(i).Dec = GA_Mutation(offspring(i).Dec, Algo.MuM);
            tempDec = GA_Mutation(tempDec, Algo.MuM);
            % variable swap (uniform X)
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
            % variable swap (uniform X)
            swap_indicator = (rand(1, length(population(i).Dec)) >= 0.5);
            offspring(i).Dec(swap_indicator) = tempDec(swap_indicator);

            offspring(i).Dec(offspring(i).Dec > 1) = 1;
            offspring(i).Dec(offspring(i).Dec < 0) = 0;
        end
    end
end
end
