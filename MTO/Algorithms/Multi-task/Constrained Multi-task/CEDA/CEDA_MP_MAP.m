classdef CEDA_MP_MAP < Algorithm
% <Multi-task> <Single-objective> <Constrained>
%
% Mapping-focused variant of CEDA_MP.
% The main loop is kept intact, while the transfer mapping is made more
% conservative by:
% 1) building source/target statistics from elite subsets,
% 2) using covariance shrinkage for more stable whitening/coloring, and
% 3) blending mapped vectors with the original vectors.

properties (SetAccess = public)
    EC_Top = 0.2
    EC_Tc = 0.8
    EC_Cp = 5
    MuC = 2
    MuM = 5
    RMP1 = 0.15
    RMP2 = 0
    MapTop = 0.3
    MapBlend = 0.5
    MapShrink = 0.2
    MapMinSize = 8
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'RMP1', num2str(Algo.RMP1), ...
                'RMP2', num2str(Algo.RMP2), ...
                'MapTop', num2str(Algo.MapTop), ...
                'MapBlend', num2str(Algo.MapBlend), ...
                'MapShrink', num2str(Algo.MapShrink), ...
                'MapMinSize', num2str(Algo.MapMinSize)};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.EC_Top = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Tc = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Cp = str2double(Parameter{i}); i = i + 1;
        Algo.RMP1 = str2double(Parameter{i}); i = i + 1;
        Algo.RMP2 = str2double(Parameter{i}); i = i + 1;
        Algo.MapTop = str2double(Parameter{i}); i = i + 1;
        Algo.MapBlend = str2double(Parameter{i}); i = i + 1;
        Algo.MapShrink = str2double(Parameter{i}); i = i + 1;
        Algo.MapMinSize = str2double(Parameter{i}); i = i + 1;
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
            for t = 1:Prob.T
                k = randi(Prob.T);
                while k == t
                    k = randi(Prob.T);
                end
                offspring1 = Algo.Generation1(population1{t}, mating_pool1{t}, population1{k}(mating_pool1{k}));
                offspring2 = Algo.Generation2(population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));
                offspring = [offspring1, offspring2];
                offspring = Algo.Evaluation(offspring, Prob, t);
                population1{t} = Selection_Elit(population1{t}, offspring, Ep);
                population2{t} = Selection_Elit(population2{t}, offspring, 0);
            end
        end
    end

    function offspring = Generation1(Algo, population, pool, transpop)
        population = population(pool);
        [temp_Dec, temp_Dec2] = Algo.BuildMappedPools(population, transpop);
        for i = 1:length(population)
            if rand() < Algo.RMP1
                if rand() < 0.5
                    population(i).Dec = temp_Dec(randi(size(temp_Dec, 1)), :);
                else
                    population(i).Dec = temp_Dec2(randi(size(temp_Dec2, 1)), :);
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
        [temp_Dec, temp_Dec2] = Algo.BuildMappedPools(population, transpop);
        for i = 1:length(population)
            if rand() < Algo.RMP2
                if rand() < 0.5
                    population(i).Dec = temp_Dec(randi(size(temp_Dec, 1)), :);
                else
                    population(i).Dec = temp_Dec2(randi(size(temp_Dec2, 1)), :);
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

    function [mapped_from_trans, mapped_from_pop] = BuildMappedPools(Algo, population, transpop)
        src_elite = Algo.SelectMapSubset(transpop);
        dst_elite = Algo.SelectMapSubset(population);
        mapped_from_trans = Algo.MapDecs(src_elite, dst_elite, transpop.Decs, Algo.MapBlend);
        mapped_from_pop = Algo.MapDecs(dst_elite, src_elite, population.Decs, Algo.MapBlend);
    end

    function subset = SelectMapSubset(Algo, pop)
        n = length(pop);
        take = min(n, max(Algo.MapMinSize, ceil(Algo.MapTop * n)));
        cv = [pop.CV];
        obj = [pop.Obj];
        feasible_idx = find(cv <= 0);
        if numel(feasible_idx) >= take
            [~, local_order] = sort(obj(feasible_idx), 'ascend');
            idx = feasible_idx(local_order(1:take));
        else
            [~, idx] = sortrows([cv(:), obj(:)], [1, 2]);
            idx = idx(1:take);
        end
        subset = pop(idx);
    end

    function mapped = MapDecs(Algo, Ds, Dt, D, blend)
        Ds_Dec = Ds.Decs;
        Dt_Dec = Dt.Decs;
        mus = mean(Ds_Dec, 1);
        mut = mean(Dt_Dec, 1);

        Xs = Ds_Dec - mus;
        Xt = Dt_Dec - mut;
        X = D - mus;

        Cs = Algo.StableCov(Xs);
        Ct = Algo.StableCov(Xt);
        Ws = Algo.MatrixInvSqrt(Cs);
        Wt = Algo.MatrixSqrt(Ct);

        mapped = X * Ws * Wt + mut;
        mapped = blend * mapped + (1 - blend) * D;
    end

    function C = StableCov(Algo, X)
        if size(X, 1) <= 1
            C = eye(size(X, 2));
            return;
        end
        C0 = cov(X, 1);
        scale = mean(diag(C0));
        if ~isfinite(scale) || scale <= 0
            scale = 1;
        end
        C = (1 - Algo.MapShrink) * C0 + Algo.MapShrink * scale * eye(size(C0));
    end

    function A = MatrixSqrt(~, C)
        C = (C + C') / 2;
        [V, E] = eig(C);
        e = max(diag(E), 1e-12);
        A = V * diag(sqrt(e)) * V';
    end

    function A = MatrixInvSqrt(~, C)
        C = (C + C') / 2;
        [V, E] = eig(C);
        e = max(diag(E), 1e-12);
        A = V * diag(1 ./ sqrt(e)) * V';
    end
end
end
