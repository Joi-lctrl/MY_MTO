classdef CEDA_MP_FEASCHANNEL < Algorithm
% <Multi-task> <Single-objective> <Constrained>
%
% Feasible-channel-only variant of CEDA_MP:
% 1) only feasible individuals in Pop1 use cross-task transfer;
% 2) the transfer channel is built from feasible subsets only;
% 3) infeasible individuals do not use cross-task transfer and keep local
%    search through the original variation pipeline.

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
        [temp_Dec_feas, temp_Dec2_feas] = Algo.BuildFeasibleChannel(population, transpop);

        for i = 1:length(population)
            if population(i).CV <= 0 && rand() < Algo.RMP1
                if rand() < 0.5
                    population(i).Dec = temp_Dec_feas(randi(size(temp_Dec_feas, 1)), :);
                else
                    population(i).Dec = temp_Dec2_feas(randi(size(temp_Dec2_feas, 1)), :);
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

    function [temp_Dec, temp_Dec2] = BuildFeasibleChannel(Algo, population, transpop)
        dst_pop = Algo.SelectFeasiblePopulation(population);
        src_pop = Algo.SelectFeasiblePopulation(transpop);
        temp_Dec = CEDA_trans(src_pop, dst_pop, transpop.Decs);
        temp_Dec2 = CEDA_trans(dst_pop, src_pop, population.Decs);
    end

    function chosen = SelectFeasiblePopulation(~, pop)
        cv = [pop.CV];
        idx = find(cv <= 0);
        if numel(idx) < 2
            [~, order] = sort(cv, 'ascend');
            take = min(length(pop), max(2, ceil(0.3 * length(pop))));
            idx = order(1:take);
        end
        chosen = pop(idx);
    end
end
end
