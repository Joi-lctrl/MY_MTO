classdef CEDA_MP_DUALCHANNEL_CB < Algorithm
% <Multi-task> <Single-objective> <Constrained>
%
% Dual-channel transfer variant with contribution-based dimension selection:
% Maintains per-dimension transfer probability learned from historical
% success/failure feedback. Only selected dimensions are replaced during
% cross-task transfer; the rest keep their original values.

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
    LR = 0.1
    DimProb_Min = 0.1
    DimProb_Max = 0.9
end

properties (Access = private)
    DimProb % cell{1, T}, per-dimension transfer probability for each task
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'RMP1', num2str(Algo.RMP1), ...
                'RMP2', num2str(Algo.RMP2), ...
                'LR (dim prob learning rate)', num2str(Algo.LR)};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.EC_Top = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Tc = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Cp = str2double(Parameter{i}); i = i + 1;
        Algo.RMP1 = str2double(Parameter{i}); i = i + 1;
        Algo.RMP2 = str2double(Parameter{i}); i = i + 1;
        Algo.LR = str2double(Parameter{i}); i = i + 1;
    end

    function run(Algo, Prob)
        population1 = Initialization(Algo, Prob, Individual);
        population2 = Initialization(Algo, Prob, Individual);

        % Initialize per-dimension transfer probabilities
        maxD = max(Prob.D);
        Algo.DimProb = cell(1, Prob.T);
        for t = 1:Prob.T
            Algo.DimProb{t} = 0.5 * ones(1, maxD);
        end

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
                N_old = length(population1{t});
                [offspring1, trans_info] = Algo.Generation1(population1{t}, mating_pool1{t}, population1{k}(mating_pool1{k}), t);
                offspring2 = Algo.Generation2(population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));
                offspring = [offspring1, offspring2];
                offspring = Algo.Evaluation(offspring, Prob, t);
                [population1{t}, rank] = Selection_Elit(population1{t}, offspring, Ep_vals(t));
                population2{t} = Selection_Elit(population2{t}, offspring, 0);

                % Update dimension probabilities based on transfer success
                Algo.UpdateDimProb(trans_info, rank, N_old, length(offspring1), t);
            end
        end
    end

    function [offspring, trans_info] = Generation1(Algo, population, pool, transpop, task_id)
        population = population(pool);
        population_temp = population;

        [temp_Dec_feas, temp_Dec2_feas] = Algo.BuildChannelMaps(population_temp, transpop, true);
        [temp_Dec_infeas, temp_Dec2_infeas] = Algo.BuildChannelMaps(population_temp, transpop, false);

        d = length(population(1).Dec);
        n_off = ceil(length(population) / 2);
        trans_info.transferred_idx = [];
        trans_info.masks = logical([]);

        for i = 1:length(population)
            if rand() < Algo.RMP1
                % Dimension mask based on learned probabilities
                mask = rand(1, d) < Algo.DimProb{task_id}(1:d);
                if ~any(mask)
                    mask(randi(d)) = true;
                end

                if population(i).CV <= 0
                    if rand() < 0.5
                        mapped_dec = temp_Dec_feas(randi(size(temp_Dec_feas, 1)), :);
                    else
                        mapped_dec = temp_Dec2_feas(randi(size(temp_Dec2_feas, 1)), :);
                    end
                else
                    if rand() < 0.5
                        mapped_dec = temp_Dec_infeas(randi(size(temp_Dec_infeas, 1)), :);
                    else
                        mapped_dec = temp_Dec2_infeas(randi(size(temp_Dec2_infeas, 1)), :);
                    end
                end

                % Partial dimension replacement
                population(i).Dec(mask) = mapped_dec(mask);

                % Track only first-parent transfers (directly map to offspring)
                if i <= n_off
                    trans_info.transferred_idx(end + 1) = i;
                    trans_info.masks = [trans_info.masks; mask];
                end
            end
        end

        for i = 1:n_off
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
        temp_Dec = CEDA_trans(src_pop, dst_pop, transpop.Decs);
        temp_Dec2 = CEDA_trans(dst_pop, src_pop, population.Decs);
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

    function UpdateDimProb(Algo, trans_info, rank, N_old, n_off1, task_id)
        if isempty(trans_info.transferred_idx)
            return;
        end

        survived_set = rank(:)';

        for ii = 1:length(trans_info.transferred_idx)
            idx = trans_info.transferred_idx(ii);
            pool_idx = N_old + idx; % offspring1(idx) position in combined pool
            mask = trans_info.masks(ii, :);

            if ismember(pool_idx, survived_set)
                % Success: increase probability for mapped dimensions
                Algo.DimProb{task_id}(mask) = Algo.DimProb{task_id}(mask) + ...
                    Algo.LR * (1 - Algo.DimProb{task_id}(mask));
            else
                % Failure: decrease probability for mapped dimensions
                Algo.DimProb{task_id}(mask) = Algo.DimProb{task_id}(mask) * (1 - Algo.LR);
            end
        end

        % Clamp to [DimProb_Min, DimProb_Max]
        Algo.DimProb{task_id} = max(Algo.DimProb_Min, min(Algo.DimProb_Max, Algo.DimProb{task_id}));
    end
end
end
