classdef CEDA_MP_DUALCHANNEL_COUPLED < Algorithm
% <Multi-task> <Single-objective> <Constrained>
%
% Dual-channel transfer with feasible-relaxed coupling:
% 1) strict feasible individuals (CV <= 0) use the feasible mapping channel;
% 2) relaxed/infeasible individuals (CV > 0) use the non-feasible channel;
% 3) strict feasible transfer can be biased toward the relaxed boundary band
%    (0 < CV <= Ep) to preserve feasible-to-relaxed directional information.

properties (SetAccess = public)
    EC_Top = 0.2
    EC_Tc = 0.8
    EC_Cp = 5
    MuC = 2
    MuM = 5
    RMP1 = 0.15
    RMP2 = 0
    CoupleProb = 0.5
    CoupleStep = 0.25
    RelaxTop = 0.3
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'RMP1', num2str(Algo.RMP1), ...
                'RMP2', num2str(Algo.RMP2), ...
                'CoupleProb', num2str(Algo.CoupleProb), ...
                'CoupleStep', num2str(Algo.CoupleStep), ...
                'RelaxTop', num2str(Algo.RelaxTop)};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.EC_Top = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Tc = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Cp = str2double(Parameter{i}); i = i + 1;
        Algo.RMP1 = str2double(Parameter{i}); i = i + 1;
        Algo.RMP2 = str2double(Parameter{i}); i = i + 1;
        Algo.CoupleProb = str2double(Parameter{i}); i = i + 1;
        Algo.CoupleStep = str2double(Parameter{i}); i = i + 1;
        Algo.RelaxTop = str2double(Parameter{i}); i = i + 1;
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
                offspring1 = Algo.Generation1(population1{t}, mating_pool1{t}, population1{k}(mating_pool1{k}), Ep_vals(t));
                offspring2 = Algo.Generation2(population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));
                offspring = [offspring1, offspring2];
                offspring = Algo.Evaluation(offspring, Prob, t);
                population1{t} = Selection_Elit(population1{t}, offspring, Ep_vals(t));
                population2{t} = Selection_Elit(population2{t}, offspring, 0);
            end
        end
    end

    function offspring = Generation1(Algo, population, pool, transpop, Ep)
        population = population(pool);
        [temp_Dec_feas, temp_Dec2_feas] = Algo.BuildChannelMaps(population, transpop, true);
        [temp_Dec_nonfeas, temp_Dec2_nonfeas] = Algo.BuildChannelMaps(population, transpop, false);
        couple_dir = Algo.EstimateCouplingDirection(population, Ep);
        couple_gain = Algo.EstimateCouplingGain(population, Ep, couple_dir);

        for i = 1:length(population)
            if rand() >= Algo.RMP1
                continue;
            end

            if population(i).CV <= 0
                if rand() < 0.5
                    mapped_dec = temp_Dec_feas(randi(size(temp_Dec_feas, 1)), :);
                else
                    mapped_dec = temp_Dec2_feas(randi(size(temp_Dec2_feas, 1)), :);
                end
                if couple_gain > 0 && rand() < Algo.CoupleProb
                    mapped_dec = mapped_dec + couple_gain * couple_dir;
                end
                population(i).Dec = Algo.BoundDec(mapped_dec);
            else
                if rand() < 0.5
                    population(i).Dec = temp_Dec_nonfeas(randi(size(temp_Dec_nonfeas, 1)), :);
                else
                    population(i).Dec = temp_Dec2_nonfeas(randi(size(temp_Dec2_nonfeas, 1)), :);
                end
                population(i).Dec = Algo.BoundDec(population(i).Dec);
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
            offspring(i).Dec = Algo.BoundDec(offspring(i).Dec);
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
                population(i).Dec = Algo.BoundDec(population(i).Dec);
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
            offspring(i).Dec = Algo.BoundDec(offspring(i).Dec);
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

    function relaxed = SelectRelaxedPopulation(Algo, pop, Ep)
        cv = [pop.CV];
        idx = find(cv > 0 & cv <= Ep);
        if numel(idx) < 2
            pos_idx = find(cv > 0);
            if isempty(pos_idx)
                relaxed = pop([]);
                return;
            end
            [~, local_order] = sort(cv(pos_idx), 'ascend');
            take = min(numel(pos_idx), max(2, ceil(Algo.RelaxTop * numel(pos_idx))));
            idx = pos_idx(local_order(1:take));
        end
        relaxed = pop(idx);
    end

    function dir = EstimateCouplingDirection(Algo, population, Ep)
        feas_pop = Algo.SelectChannelPopulation(population, true);
        relaxed_pop = Algo.SelectRelaxedPopulation(population, Ep);
        if isempty(relaxed_pop)
            dir = zeros(1, size(population.Decs, 2));
            return;
        end

        mu_feas = mean(feas_pop.Decs, 1);
        mu_relaxed = mean(relaxed_pop.Decs, 1);
        dir = mu_relaxed - mu_feas;
    end

    function gain = EstimateCouplingGain(Algo, population, Ep, dir)
        norm_dir = norm(dir);
        if norm_dir <= 1e-12
            gain = 0;
            return;
        end

        feas_pop = Algo.SelectChannelPopulation(population, true);
        relaxed_pop = Algo.SelectRelaxedPopulation(population, Ep);
        if isempty(relaxed_pop)
            gain = 0;
            return;
        end

        feas_center = mean(feas_pop.Decs, 1);
        feas_div = mean(sqrt(sum((feas_pop.Decs - feas_center).^2, 2)));
        relaxed_cv = mean([relaxed_pop.CV]);
        atten = 1 / (1 + max(relaxed_cv, 0));
        gain = Algo.CoupleStep * max(feas_div, 1e-3) * atten / norm_dir;
    end

    function dec = BoundDec(~, dec)
        dec(dec > 1) = 1;
        dec(dec < 0) = 0;
    end
end
end
