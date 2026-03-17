classdef CEDA_MP_DUALCHANNEL_WEIGHTED < Algorithm
% <Multi-task> <Single-objective> <Constrained>
%
% Weighted dual-channel variant of CEDA_MP:
% 1) feasible individuals use a feasible-only mapping channel;
% 2) infeasible individuals use an infeasible-only mapping channel;
% 3) channel statistics are estimated with weighted samples.

properties (SetAccess = public)
    EC_Top = 0.2
    EC_Tc = 0.8
    EC_Cp = 5
    MuC = 2
    MuM = 5
    RMP1 = 0.15
    RMP2 = 0
    FeasBeta = 3
    InfeasBeta = 3
    InfeasObjGamma = 0.3
    MapReg = 1e-6
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'RMP1', num2str(Algo.RMP1), ...
                'RMP2', num2str(Algo.RMP2), ...
                'FeasBeta', num2str(Algo.FeasBeta), ...
                'InfeasBeta', num2str(Algo.InfeasBeta), ...
                'InfeasObjGamma', num2str(Algo.InfeasObjGamma), ...
                'MapReg', num2str(Algo.MapReg)};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.EC_Top = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Tc = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Cp = str2double(Parameter{i}); i = i + 1;
        Algo.RMP1 = str2double(Parameter{i}); i = i + 1;
        Algo.RMP2 = str2double(Parameter{i}); i = i + 1;
        Algo.FeasBeta = str2double(Parameter{i}); i = i + 1;
        Algo.InfeasBeta = str2double(Parameter{i}); i = i + 1;
        Algo.InfeasObjGamma = str2double(Parameter{i}); i = i + 1;
        Algo.MapReg = str2double(Parameter{i}); i = i + 1;
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

        [temp_Dec_feas, temp_Dec2_feas] = Algo.BuildChannelMaps(population, transpop, true);
        [temp_Dec_infeas, temp_Dec2_infeas] = Algo.BuildChannelMaps(population, transpop, false);

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
        dst_w = Algo.BuildChannelWeights(dst_pop, use_feasible_channel);
        src_w = Algo.BuildChannelWeights(src_pop, use_feasible_channel);
        temp_Dec = Algo.WeightedTrans(src_pop.Decs, dst_pop.Decs, transpop.Decs, src_w, dst_w);
        temp_Dec2 = Algo.WeightedTrans(dst_pop.Decs, src_pop.Decs, population.Decs, dst_w, src_w);
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

    function w = BuildChannelWeights(Algo, pop, use_feasible_channel)
        if use_feasible_channel
            obj = [pop.Obj]';
            score = Algo.NormalizeVector(obj);
            raw = exp(-Algo.FeasBeta * score);
        else
            cv = [pop.CV]';
            obj = [pop.Obj]';
            score = Algo.NormalizeVector(cv) + Algo.InfeasObjGamma * Algo.NormalizeVector(obj);
            raw = exp(-Algo.InfeasBeta * score);
        end
        if sum(raw) <= 0 || any(~isfinite(raw))
            w = ones(length(pop), 1) / length(pop);
        else
            w = raw / sum(raw);
        end
    end

    function trans = WeightedTrans(Algo, Ds_Dec, Dt_Dec, D, ws, wt)
        mus = Algo.WeightedMean(Ds_Dec, ws);
        mut = Algo.WeightedMean(Dt_Dec, wt);

        Xs = Ds_Dec - mus;
        Xt = Dt_Dec - mut;
        X = D - mus;

        Cs = Algo.WeightedCov(Xs, ws);
        Ct = Algo.WeightedCov(Xt, wt);

        trans = X * Algo.MatrixInvSqrt(Cs) * Algo.MatrixSqrt(Ct);
        trans = trans + mut;
    end

    function mu = WeightedMean(~, X, w)
        mu = (w' * X);
    end

    function C = WeightedCov(Algo, X, w)
        C = X' * (X .* w);
        C = (C + C') / 2 + Algo.MapReg * eye(size(C, 1));
    end

    function A = MatrixSqrt(~, C)
        [V, E] = eig((C + C') / 2);
        e = max(real(diag(E)), 1e-12);
        A = V * diag(sqrt(e)) * V';
    end

    function A = MatrixInvSqrt(~, C)
        [V, E] = eig((C + C') / 2);
        e = max(real(diag(E)), 1e-12);
        A = V * diag(1 ./ sqrt(e)) * V';
    end

    function y = NormalizeVector(~, x)
        xmin = min(x);
        xmax = max(x);
        if ~isfinite(xmin) || ~isfinite(xmax) || xmax - xmin <= 1e-12
            y = zeros(size(x));
        else
            y = (x - xmin) / (xmax - xmin);
        end
    end
end
end
