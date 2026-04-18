classdef CEDA_MP_DUALCHANNEL_WM < Algorithm
% <Multi-task> <Single-objective> <Constrained>
%
% Dual-channel transfer variant with weighted mapping:
% 1) feasible channel: weights based on Obj rank;
% 2) infeasible channel: weights based on combined rank of CV and Obj.
%
% Weighted mean and covariance are used in domain adaptation mapping
% to bias transfer toward more promising regions.

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

properties (SetAccess = public)
    EC_Top = 0.2
    EC_Tc = 0.8
    EC_Cp = 5
    MuC = 2
    MuM = 5
    RMP1 = 0.15
    RMP2 = 0
    Alpha = 0.5
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'RMP1', num2str(Algo.RMP1), ...
                'RMP2', num2str(Algo.RMP2), ...
                'Alpha (CV/Obj rank weight)', num2str(Algo.Alpha)};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.EC_Top = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Tc = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Cp = str2double(Parameter{i}); i = i + 1;
        Algo.RMP1 = str2double(Parameter{i}); i = i + 1;
        Algo.RMP2 = str2double(Parameter{i}); i = i + 1;
        Algo.Alpha = str2double(Parameter{i}); i = i + 1;
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

        while Algo.notTerminated(Prob, population2)
            Ep_vals = zeros(1, Prob.T);
            for t = 1:Prob.T
                if Algo.FE < Algo.EC_Tc * Prob.maxFE
                    Ep = Ep0{t} * ((1 - Algo.FE / (Algo.EC_Tc * Prob.maxFE))^Algo.EC_Cp);
                else
                    Ep = 0;
                end
                Ep_vals(t) = Ep;
                CV = population1{t}.CVs;
                CV(CV < Ep) = 0;
                Obj = population1{t}.Objs;
                mating_pool1{t} = TournamentSelection(2, Prob.N, CV, Obj);
                mating_pool2{t} = TournamentSelection(2, Prob.N, population2{t}.CVs, population2{t}.Objs);
            end
            for t = 1:Prob.T
                k = randi(Prob.T);
                while k == t
                    k = randi(Prob.T);
                end
                offspring1 = Algo.Generation1(population1{t}, mating_pool1{t}, population1{k}(mating_pool1{k}));
                offspring2 = Algo.Generation2(population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));
                offspring = [offspring1, offspring2];
                offspring = Algo.Evaluation(offspring, Prob, t);
                population1{t} = Selection_Elit(population1{t}, offspring, Ep_vals(t));
                population2{t} = Selection_Elit(population2{t}, offspring, 0);
            end
        end
    end

    function offspring = Generation1(Algo, population, pool, transpop)
        population = population(pool);
        population_temp = population;

        [temp_Dec_feas, temp_Dec2_feas] = Algo.BuildChannelMaps(population_temp, transpop, true);
        [temp_Dec_infeas, temp_Dec2_infeas] = Algo.BuildChannelMaps(population_temp, transpop, false);

        for i = 1:length(population)
            if rand() < Algo.RMP1
                if population(i).CV <= 0
                    if rand() < 0.5
                        population(i).Dec = temp_Dec_feas(randi(size(temp_Dec_feas, 1)), :);
                    else
                        population(i).Dec = temp_Dec2_feas(randi(size(temp_Dec2_feas, 1)), :);
                    end
                else
                    if rand() < 0.5
                        population(i).Dec = temp_Dec_infeas(randi(size(temp_Dec_infeas, 1)), :);
                    else
                        population(i).Dec = temp_Dec2_infeas(randi(size(temp_Dec2_infeas, 1)), :);
                    end
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

    function [temp_Dec, temp_Dec2] = BuildChannelMaps(Algo, population, transpop, use_feasible_channel)
        dst_pop = Algo.SelectChannelPopulation(population, use_feasible_channel);
        src_pop = Algo.SelectChannelPopulation(transpop, use_feasible_channel);
        dst_w = Algo.ComputeWeights(dst_pop, use_feasible_channel);
        src_w = Algo.ComputeWeights(src_pop, use_feasible_channel);
        temp_Dec = Algo.WeightedTrans(src_pop, src_w, dst_pop, dst_w, transpop.Decs);
        temp_Dec2 = Algo.WeightedTrans(dst_pop, dst_w, src_pop, src_w, population.Decs);
    end

    function chosen = SelectChannelPopulation(~, pop, use_feasible_channel)
        cv = [pop.CV];
        if use_feasible_channel
            idx = find(cv <= 0);
        else
            idx = find(cv > 0);
        end

        if numel(idx) < 2
            [~, order] = sort(cv, 'ascend');
            take = min(length(pop), max(2, ceil(0.3 * length(pop))));
            if use_feasible_channel
                idx = order(1:take);
            else
                idx = order(max(1, length(pop) - take + 1):length(pop));
            end
        end
        chosen = pop(idx);
    end

    function w = ComputeWeights(Algo, pop, use_feasible_channel)
        N = length(pop);
        obj = [pop.Obj];
        [~, obj_order] = sort(obj, 'ascend');
        rank_obj = zeros(1, N);
        rank_obj(obj_order) = 1:N;

        if use_feasible_channel
            rank_combined = rank_obj;
        else
            cv = [pop.CV];
            [~, cv_order] = sort(cv, 'ascend');
            rank_cv = zeros(1, N);
            rank_cv(cv_order) = 1:N;
            rank_combined = Algo.Alpha * rank_cv + (1 - Algo.Alpha) * rank_obj;
        end

        w = max(0, log(N + 1) - log(rank_combined));
        w = w / sum(w);
    end

    function trans = WeightedTrans(~, src_pop, src_w, dst_pop, dst_w, D)
        Ds_Dec = src_pop.Decs;
        Dt_Dec = dst_pop.Decs;
        d = size(Ds_Dec, 2);

        mus = src_w * Ds_Dec;
        mut = dst_w * Dt_Dec;

        D_centered = D - mus;
        Ds_centered = Ds_Dec - mus;
        Dt_centered = Dt_Dec - mut;

        Cs = (Ds_centered' * diag(src_w) * Ds_centered) + eye(d);
        Ct = (Dt_centered' * diag(dst_w) * Dt_centered) + eye(d);

        trans = D_centered * Cs^(-1/2) * Ct^(1/2);
        trans = trans + mut;
    end
end
end
