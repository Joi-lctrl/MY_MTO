classdef CEDA_MP_Diag < Algorithm
% <Multi-task> <Single-objective> <Constrained>

% Diagnostic version of CEDA-MP
% Records per-generation data for analysis: epsilon, population quality,
% feasibility rates, transfer quality, partner tasks, and diversity.
% Log is saved to 'CEDA_Diag_Log.mat' after run completes.

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
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'RMP1', num2str(Algo.RMP1), ...
                'RMP2', num2str(Algo.RMP2)};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.EC_Top = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Tc = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Cp = str2double(Parameter{i}); i = i + 1;
        Algo.RMP1 = str2double(Parameter{i}); i = i + 1;
        Algo.RMP2 = str2double(Parameter{i}); i = i + 1;
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

        % --- Initialize Diagnostic Log ---
        Log = struct();
        Log.T = Prob.T;
        gen = 0;

        while Algo.notTerminated(Prob, population2)
            gen = gen + 1;

            % Compute epsilon and mating pools
            Ep_vals = zeros(1, Prob.T);
            for t = 1:Prob.T
                if Algo.FE < Algo.EC_Tc * Prob.maxFE
                    Ep_vals(t) = Ep0{t} * ((1 - Algo.FE / (Algo.EC_Tc * Prob.maxFE))^Algo.EC_Cp);
                else
                    Ep_vals(t) = 0;
                end
                CV = population1{t}.CVs; CV(CV < Ep_vals(t)) = 0;
                Obj = population1{t}.Objs;
                mating_pool1{t} = TournamentSelection(2, Prob.N, CV, Obj);
                mating_pool2{t} = TournamentSelection(2, Prob.N, population2{t}.CVs, population2{t}.Objs);
            end

            % Log: epsilon
            Log.Epsilon(gen, :) = Ep_vals;
            % Log: FE progress
            Log.FE_ratio(gen) = Algo.FE / Prob.maxFE;

            for t = 1:Prob.T
                k = randi(Prob.T);
                while k == t
                    k = randi(Prob.T);
                end

                % Log: partner task
                Log.Partner(gen, t) = k;

                % --- Log population stats BEFORE generation ---
                % Population1
                pop1_obj = [population1{t}.Obj];
                pop1_cv = [population1{t}.CV];
                feasible_pop1_obj = pop1_obj(pop1_cv == 0);
                if isempty(feasible_pop1_obj)
                    % No feasible solution in this generation; fall back to the
                    % best objective value regardless of constraint violation.
                    Log.Pop1_BestObj(gen, t) = min(pop1_obj, [], 'omitnan');
                else
                    Log.Pop1_BestObj(gen, t) = min(feasible_pop1_obj, [], 'omitnan');
                end
                Log.Pop1_BestCV(gen, t) = min(pop1_cv);
                Log.Pop1_MeanObj(gen, t) = mean(pop1_obj);
                Log.Pop1_MeanCV(gen, t) = mean(pop1_cv);
                Log.Pop1_FeasRate(gen, t) = mean(pop1_cv == 0);
                Log.Pop1_Diversity(gen, t) = mean(std(population1{t}.Decs, 0, 1));

                % Population2
                pop2_obj = [population2{t}.Obj];
                pop2_cv = [population2{t}.CV];
                feasible_pop2_obj = pop2_obj(pop2_cv == 0);
                if isempty(feasible_pop2_obj)
                    Log.Pop2_BestObj(gen, t) = min(pop2_obj, [], 'omitnan');
                else
                    Log.Pop2_BestObj(gen, t) = min(feasible_pop2_obj, [], 'omitnan');
                end
                Log.Pop2_BestCV(gen, t) = min(pop2_cv);
                Log.Pop2_MeanCV(gen, t) = mean(pop2_cv);
                Log.Pop2_FeasRate(gen, t) = mean(pop2_cv == 0);
                Log.Pop2_Diversity(gen, t) = mean(std(population2{t}.Decs, 0, 1));

                % --- Generation with transfer tracking ---
                [offspring1, is_trans] = Algo.Generation1_Track(population1{t}, mating_pool1{t}, population1{k}(mating_pool1{k}));
                offspring2 = Algo.Generation2(population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));

                n_off1 = length(offspring1);
                offspring = [offspring1, offspring2];
                % Evaluation
                offspring = Algo.Evaluation(offspring, Prob, t);

                % --- Log transfer quality ---
                n_trans = sum(is_trans);
                n_normal = sum(~is_trans);
                Log.N_Trans(gen, t) = n_trans;
                Log.N_Normal(gen, t) = n_normal;

                if n_trans >= 1 && n_normal >= 1
                    eval_off1 = offspring(1:n_off1);
                    off1_cv = eval_off1.CVs;
                    off1_obj = eval_off1.Objs;
                    % Rank by feasibility priority
                    [~, sorted_idx] = sortrows([off1_cv, off1_obj], [1, 2]);
                    rankings = zeros(n_off1, 1);
                    rankings(sorted_idx) = (1:n_off1)';

                    % Average rank (lower is better)
                    Log.Trans_AvgRank(gen, t) = mean(rankings(is_trans));
                    Log.Normal_AvgRank(gen, t) = mean(rankings(~is_trans));

                    % Success count: in top half
                    top_half = sorted_idx(1:floor(n_off1 / 2));
                    is_top = false(1, n_off1);
                    is_top(top_half) = true;
                    Log.Trans_SuccRate(gen, t) = sum(is_top(is_trans)) / n_trans;
                    Log.Normal_SuccRate(gen, t) = sum(is_top(~is_trans)) / n_normal;

                    % Mean Obj and CV of transferred vs normal offspring
                    trans_off = eval_off1(is_trans);
                    normal_off = eval_off1(~is_trans);
                    Log.Trans_MeanObj(gen, t) = mean([trans_off.Obj]);
                    Log.Trans_MeanCV(gen, t) = mean([trans_off.CV]);
                    Log.Normal_MeanObj(gen, t) = mean([normal_off.Obj]);
                    Log.Normal_MeanCV(gen, t) = mean([normal_off.CV]);
                else
                    Log.Trans_AvgRank(gen, t) = NaN;
                    Log.Normal_AvgRank(gen, t) = NaN;
                    Log.Trans_SuccRate(gen, t) = NaN;
                    Log.Normal_SuccRate(gen, t) = NaN;
                    Log.Trans_MeanObj(gen, t) = NaN;
                    Log.Trans_MeanCV(gen, t) = NaN;
                    Log.Normal_MeanObj(gen, t) = NaN;
                    Log.Normal_MeanCV(gen, t) = NaN;
                end

                % Selection (same as original CEDA_MP)
                population1{t} = Selection_Elit(population1{t}, offspring, Ep_vals(t));
                population2{t} = Selection_Elit(population2{t}, offspring, 0);
            end
        end

        % --- Save Log ---
        Log.TotalGen = gen;
        Log.RMP1 = Algo.RMP1;
        Log.RMP2 = Algo.RMP2;
        Log.ProbName = Prob.Name;
        save('CEDA_Diag_Log.mat', 'Log');
        fprintf('[CEDA-MP-Diag] Log saved to CEDA_Diag_Log.mat (%d generations, %d tasks)\n', gen, Prob.T);
    end

    function [offspring, is_trans] = Generation1_Track(Algo, population, pool, transpop)
        % Same as original Generation1 but tracks which offspring come from transfer
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
end
end
