classdef CEDA_MP_DUALCHANNEL_ADAPRMP < Algorithm
% <Multi-task> <Single-objective> <Constrained>
%
% Dual-channel exploration-oriented variant of CEDA_MP:
% 1) feasible individuals use a feasible-only mapping channel;
% 2) infeasible individuals use an infeasible-only mapping channel;
% 3) feasible and infeasible channels have separate RMP schedules;
% 4) infeasible individuals are split by CV into light and heavy groups;
% 5) heavy infeasible individuals can be kept out of transfer entirely.

properties (SetAccess = public)
    EC_Top = 0.2
    EC_Tc = 0.8
    EC_Cp = 5
    MuC = 2
    MuM = 5
    RMP2 = 0
    RMP_Feas_Min = 0.05
    RMP_Feas_Max = 0.20
    RMP_Infeas_Min = 0.00
    RMP_Infeas_Max = 0.12
    InfeasCVQuantile = 0.5
    HeavyInfeasRMPScale = 0
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'RMP2', num2str(Algo.RMP2), ...
                'RMP_Feas_Min', num2str(Algo.RMP_Feas_Min), ...
                'RMP_Feas_Max', num2str(Algo.RMP_Feas_Max), ...
                'RMP_Infeas_Min', num2str(Algo.RMP_Infeas_Min), ...
                'RMP_Infeas_Max', num2str(Algo.RMP_Infeas_Max), ...
                'InfeasCVQuantile', num2str(Algo.InfeasCVQuantile), ...
                'HeavyInfeasRMPScale', num2str(Algo.HeavyInfeasRMPScale)};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.EC_Top = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Tc = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Cp = str2double(Parameter{i}); i = i + 1;
        Algo.RMP2 = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_Feas_Min = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_Feas_Max = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_Infeas_Min = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_Infeas_Max = str2double(Parameter{i}); i = i + 1;
        Algo.InfeasCVQuantile = str2double(Parameter{i}); i = i + 1;
        Algo.HeavyInfeasRMPScale = str2double(Parameter{i}); i = i + 1;
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
            stage_ratio = min(max(Algo.FE / Prob.maxFE, 0), 1);
            rmp_feas = Algo.StageRMP(Algo.RMP_Feas_Min, Algo.RMP_Feas_Max, stage_ratio);
            rmp_infeas = Algo.StageRMP(Algo.RMP_Infeas_Min, Algo.RMP_Infeas_Max, stage_ratio);

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
                offspring1 = Algo.Generation1(population1{t}, mating_pool1{t}, population1{k}(mating_pool1{k}), rmp_feas, rmp_infeas);
                offspring2 = Algo.Generation2(population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));
                offspring = [offspring1, offspring2];
                offspring = Algo.Evaluation(offspring, Prob, t);
                population1{t} = Selection_Elit(population1{t}, offspring, Ep_vals(t));
                population2{t} = Selection_Elit(population2{t}, offspring, 0);
            end
        end
    end

    function offspring = Generation1(Algo, population, pool, transpop, rmp_feas, rmp_infeas)
        population = population(pool);
        [temp_Dec_feas, temp_Dec2_feas] = Algo.BuildChannelMaps(population, transpop, true);
        [temp_Dec_infeas, temp_Dec2_infeas] = Algo.BuildChannelMaps(population, transpop, false);
        infeas_split = Algo.GetInfeasibleSplit(population);

        for i = 1:length(population)
            if population(i).CV <= 0
                use_transfer = rand() < rmp_feas;
                if use_transfer
                    if rand() < 0.5
                        population(i).Dec = temp_Dec_feas(randi(size(temp_Dec_feas, 1)), :);
                    else
                        population(i).Dec = temp_Dec2_feas(randi(size(temp_Dec2_feas, 1)), :);
                    end
                end
            else
                indiv_rmp = rmp_infeas;
                if population(i).CV > infeas_split
                    indiv_rmp = indiv_rmp * Algo.HeavyInfeasRMPScale;
                end
                use_transfer = rand() < indiv_rmp;
                if use_transfer
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
        temp_Dec = CEDA_trans(transpop, population, transpop.Decs);
        temp_Dec2 = CEDA_trans(population, transpop, population.Decs);
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

    function split_value = GetInfeasibleSplit(Algo, population)
        infeas_cv = [population([population.CV] > 0).CV];
        if isempty(infeas_cv)
            split_value = inf;
            return;
        end

        infeas_cv = sort(infeas_cv, 'ascend');
        q = min(max(Algo.InfeasCVQuantile, 0), 1);
        pos = max(1, min(length(infeas_cv), ceil(q * length(infeas_cv))));
        split_value = infeas_cv(pos);
    end

    function rmp = StageRMP(~, min_val, max_val, stage_ratio)
        % Low in early search, higher in mid search, lower again in late search.
        if stage_ratio <= 0.3
            local_ratio = stage_ratio / 0.3;
            rmp = min_val + 0.5 * (max_val - min_val) * local_ratio;
        elseif stage_ratio <= 0.7
            local_ratio = (stage_ratio - 0.3) / 0.4;
            rmp = min_val + (0.5 + 0.5 * local_ratio) * (max_val - min_val);
        else
            local_ratio = (stage_ratio - 0.7) / 0.3;
            rmp = max_val - 0.5 * (max_val - min_val) * local_ratio;
        end
    end
end
end
