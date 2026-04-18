classdef CEDA_MP_DUALCHANNEL_SUCCESSDIR < Algorithm
% <Multi-task> <Single-objective> <Constrained>
%
% Dual-channel variant of CEDA_MP with:
% 1) separate feasible/infeasible channels in Pop1;
% 2) channel-wise adaptive RMP driven by recent transfer success;
% 3) directional transfer that moves toward mapped solutions instead of
%    directly replacing the original decision vector.

properties (SetAccess = public)
    EC_Top = 0.2
    EC_Tc = 0.8
    EC_Cp = 5
    MuC = 2
    MuM = 5
    RMP2 = 0
    RMP_Feas_Init = 0.15
    RMP_Infeas_Init = 0.15
    RMP_Min = 0
    RMP_Max = 0.3
    RMP_Step = 0.02
    AdjGap = 20
    SuccessThresh = 0.5
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'RMP2', num2str(Algo.RMP2), ...
                'RMP_Feas_Init', num2str(Algo.RMP_Feas_Init), ...
                'RMP_Infeas_Init', num2str(Algo.RMP_Infeas_Init), ...
                'RMP_Min', num2str(Algo.RMP_Min), ...
                'RMP_Max', num2str(Algo.RMP_Max), ...
                'RMP_Step', num2str(Algo.RMP_Step), ...
                'AdjGap', num2str(Algo.AdjGap), ...
                'SuccessThresh', num2str(Algo.SuccessThresh)};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.EC_Top = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Tc = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Cp = str2double(Parameter{i}); i = i + 1;
        Algo.RMP2 = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_Feas_Init = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_Infeas_Init = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_Min = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_Max = str2double(Parameter{i}); i = i + 1;
        Algo.RMP_Step = str2double(Parameter{i}); i = i + 1;
        Algo.AdjGap = str2double(Parameter{i}); i = i + 1;
        Algo.SuccessThresh = str2double(Parameter{i}); i = i + 1;
    end

    function run(Algo, Prob)
        population1 = Initialization(Algo, Prob, Individual);
        population2 = Initialization(Algo, Prob, Individual);

        Ep0 = cell(1, Prob.T);
        rmp_feas = Algo.RMP_Feas_Init * ones(1, Prob.T);
        rmp_infeas = Algo.RMP_Infeas_Init * ones(1, Prob.T);
        feas_uses = cell(1, Prob.T);
        feas_succ = cell(1, Prob.T);
        infeas_uses = cell(1, Prob.T);
        infeas_succ = cell(1, Prob.T);

        for t = 1:Prob.T
            n = ceil(Algo.EC_Top * length(population1{t}));
            cv_temp = [population1{t}.CV];
            [~, idx] = sort(cv_temp);
            Ep0{t} = cv_temp(idx(n));
            feas_uses{t} = [];
            feas_succ{t} = [];
            infeas_uses{t} = [];
            infeas_succ{t} = [];
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

                [offspring1, channel_tag] = Algo.Generation1(population1{t}, mating_pool1{t}, population1{k}(mating_pool1{k}), rmp_feas(t), rmp_infeas(t));
                offspring2 = Algo.Generation2(population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));
                n_off1 = length(offspring1);
                offspring = [offspring1, offspring2];
                offspring = Algo.Evaluation(offspring, Prob, t);

                [feas_use, feas_hit, infeas_use, infeas_hit] = Algo.ChannelSuccessStats(offspring(1:n_off1), channel_tag);
                feas_uses{t}(end + 1) = feas_use;
                feas_succ{t}(end + 1) = feas_hit;
                infeas_uses{t}(end + 1) = infeas_use;
                infeas_succ{t}(end + 1) = infeas_hit;

                if mod(Algo.Gen, Algo.AdjGap) == 0
                    rmp_feas(t) = Algo.AdjustRMP(rmp_feas(t), feas_uses{t}, feas_succ{t});
                    rmp_infeas(t) = Algo.AdjustRMP(rmp_infeas(t), infeas_uses{t}, infeas_succ{t});
                end

                population1{t} = Selection_Elit(population1{t}, offspring, Ep_vals(t));
                population2{t} = Selection_Elit(population2{t}, offspring, 0);
            end
        end
    end

    function [offspring, channel_tag] = Generation1(Algo, population, pool, transpop, rmp_feas, rmp_infeas)
        population = population(pool);
        [temp_Dec_feas, temp_Dec2_feas] = Algo.BuildChannelMaps(population, transpop, true);
        [temp_Dec_infeas, temp_Dec2_infeas] = Algo.BuildChannelMaps(population, transpop, false);
        step_radius = Algo.EstimateStepRadius(population);
        transferred = zeros(1, length(population));

        for i = 1:length(population)
            if population(i).CV <= 0
                if rand() < rmp_feas
                    if rand() < 0.5
                        mapped_dec = temp_Dec_feas(randi(size(temp_Dec_feas, 1)), :);
                    else
                        mapped_dec = temp_Dec2_feas(randi(size(temp_Dec2_feas, 1)), :);
                    end
                    population(i).Dec = Algo.DirectionMove(population(i).Dec, mapped_dec, step_radius);
                    transferred(i) = 1;
                end
            else
                if rand() < rmp_infeas
                    if rand() < 0.5
                        mapped_dec = temp_Dec_infeas(randi(size(temp_Dec_infeas, 1)), :);
                    else
                        mapped_dec = temp_Dec2_infeas(randi(size(temp_Dec2_infeas, 1)), :);
                    end
                    population(i).Dec = Algo.DirectionMove(population(i).Dec, mapped_dec, step_radius);
                    transferred(i) = 2;
                end
            end
        end

        n_off = ceil(length(population) / 2);
        channel_tag = zeros(1, n_off);
        for i = 1:n_off
            offspring(i) = population(i);
            p2 = i + fix(length(population) / 2);
            channel_tag(i) = max(transferred(i), transferred(p2));

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

    function step_radius = EstimateStepRadius(~, population)
        decs = population.Decs;
        center = mean(decs, 1);
        dist = sqrt(sum((decs - center).^2, 2));
        step_radius = mean(dist);
        if ~isfinite(step_radius) || step_radius <= 0
            step_radius = 0.1 * sqrt(size(decs, 2));
        end
    end

    function dec = DirectionMove(~, origin_dec, mapped_dec, step_radius)
        vec = mapped_dec - origin_dec;
        norm_vec = norm(vec);
        if norm_vec <= 1e-12
            dec = origin_dec;
            return;
        end
        step = min(norm_vec, step_radius);
        dec = origin_dec + vec / norm_vec * step;
        dec(dec > 1) = 1;
        dec(dec < 0) = 0;
    end

    function [feas_use, feas_hit, infeas_use, infeas_hit] = ChannelSuccessStats(~, offspring, channel_tag)
        n = length(offspring);
        off_cv = offspring.CVs;
        off_obj = offspring.Objs;
        [~, sorted_idx] = sortrows([off_cv, off_obj], [1, 2]);
        top_half = false(1, n);
        top_half(sorted_idx(1:max(1, floor(n / 2)))) = true;

        feas_mask = (channel_tag == 1);
        infeas_mask = (channel_tag == 2);
        feas_use = sum(feas_mask);
        infeas_use = sum(infeas_mask);
        feas_hit = sum(top_half(feas_mask));
        infeas_hit = sum(top_half(infeas_mask));
    end

    function rmp = AdjustRMP(Algo, current_rmp, use_hist, succ_hist)
        take = min(Algo.AdjGap, length(use_hist));
        if take <= 0
            rmp = current_rmp;
            return;
        end

        uses = sum(use_hist(end - take + 1:end));
        hits = sum(succ_hist(end - take + 1:end));
        if uses <= 0
            rmp = current_rmp;
            return;
        end

        rate = hits / uses;
        if rate >= Algo.SuccessThresh
            rmp = min(Algo.RMP_Max, current_rmp + Algo.RMP_Step);
        else
            rmp = max(Algo.RMP_Min, current_rmp - Algo.RMP_Step);
        end
    end
end
end
