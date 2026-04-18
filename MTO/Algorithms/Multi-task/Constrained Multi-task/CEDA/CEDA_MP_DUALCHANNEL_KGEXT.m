classdef CEDA_MP_DUALCHANNEL_KGEXT < Algorithm
% <Multi-task> <Single-objective> <Constrained>
%
% Dual-channel transfer with knowledge-guided external mapped sampling:
% 1) normal offspring are generated without directly overwriting parents;
% 2) cross-task mapping is only used to create a few external candidates;
% 3) the number of external candidates is adapted by recent survival rate.

properties (SetAccess = public)
    EC_Top = 0.2
    EC_Tc = 0.8
    EC_Cp = 5
    MuC = 2
    MuM = 5
    RMP2 = 0
    Tau0 = 4
    TauMax = 8
    AdjGap = 20
    SuccThresh = 0.35
    StepScale = 1
    FeasBias = 0.7
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'RMP2', num2str(Algo.RMP2), ...
                'Tau0', num2str(Algo.Tau0), ...
                'TauMax', num2str(Algo.TauMax), ...
                'AdjGap', num2str(Algo.AdjGap), ...
                'SuccThresh', num2str(Algo.SuccThresh), ...
                'StepScale', num2str(Algo.StepScale), ...
                'FeasBias', num2str(Algo.FeasBias)};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.EC_Top = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Tc = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Cp = str2double(Parameter{i}); i = i + 1;
        Algo.RMP2 = str2double(Parameter{i}); i = i + 1;
        Algo.Tau0 = str2double(Parameter{i}); i = i + 1;
        Algo.TauMax = str2double(Parameter{i}); i = i + 1;
        Algo.AdjGap = str2double(Parameter{i}); i = i + 1;
        Algo.SuccThresh = str2double(Parameter{i}); i = i + 1;
        Algo.StepScale = str2double(Parameter{i}); i = i + 1;
        Algo.FeasBias = str2double(Parameter{i}); i = i + 1;
    end

    function run(Algo, Prob)
        population1 = Initialization(Algo, Prob, Individual);
        population2 = Initialization(Algo, Prob, Individual);

        tau_init = min(max(0, round(Algo.Tau0)), max(0, round(Algo.TauMax)));
        tau = tau_init * ones(1, Prob.T);
        numExS = cell(1, Prob.T);
        sucExS = cell(1, Prob.T);
        Ep0 = cell(1, Prob.T);

        for t = 1:Prob.T
            n = ceil(Algo.EC_Top * length(population1{t}));
            cv_temp = [population1{t}.CV];
            [~, idx] = sort(cv_temp);
            Ep0{t} = cv_temp(idx(n));
            numExS{t} = [];
            sucExS{t} = [];
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

                offspring1 = Algo.Generation1(population1{t}, mating_pool1{t});
                transfer1 = Algo.GenerateExternalCandidates(population1{t}, mating_pool1{t}, population1{k}(mating_pool1{k}), tau(t));
                offspring2 = Algo.Generation2(population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));

                n_off1 = length(offspring1);
                n_ext = length(transfer1);
                offspring = [offspring1, transfer1, offspring2];
                offspring = Algo.Evaluation(offspring, Prob, t);

                [population1{t}, rank1] = Selection_Elit(population1{t}, offspring, Ep_vals(t));
                population2{t} = Selection_Elit(population2{t}, offspring, 0);

                numExS{t}(Algo.Gen) = n_ext;
                sucExS{t}(Algo.Gen) = Algo.CountSelectedExternal(rank1, length(population1{t}), n_off1, n_ext);

                if mod(Algo.Gen, Algo.AdjGap) == 0
                    tau(t) = Algo.AdjustTau(tau(t), numExS{t}, sucExS{t}, Algo.Gen);
                end
            end
        end
    end

    function offspring = Generation1(Algo, population, pool)
        population = population(pool);
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

    function transfer_pop = GenerateExternalCandidates(Algo, population, pool, transpop, tau)
        tau = max(0, round(tau));
        transfer_pop = Individual.empty();
        if tau <= 0
            return;
        end

        population = population(pool);
        [temp_Dec_feas, temp_Dec2_feas] = Algo.BuildChannelMaps(population, transpop, true);
        [temp_Dec_nonfeas, temp_Dec2_nonfeas] = Algo.BuildChannelMaps(population, transpop, false);

        feas_idx = find([population.CV] <= 0);
        nonfeas_idx = find([population.CV] > 0);
        step_feas = Algo.EstimateStepRadius(population, true);
        step_nonfeas = Algo.EstimateStepRadius(population, false);

        for i = 1:tau
            use_feas = Algo.SelectExternalChannel(feas_idx, nonfeas_idx);
            if use_feas
                anchor = population(feas_idx(randi(numel(feas_idx))));
                step_radius = step_feas;
                if rand() < 0.5
                    mapped_dec = temp_Dec_feas(randi(size(temp_Dec_feas, 1)), :);
                else
                    mapped_dec = temp_Dec2_feas(randi(size(temp_Dec2_feas, 1)), :);
                end
            else
                anchor = population(nonfeas_idx(randi(numel(nonfeas_idx))));
                step_radius = step_nonfeas;
                if rand() < 0.5
                    mapped_dec = temp_Dec_nonfeas(randi(size(temp_Dec_nonfeas, 1)), :);
                else
                    mapped_dec = temp_Dec2_nonfeas(randi(size(temp_Dec2_nonfeas, 1)), :);
                end
            end

            c = Individual();
            c.Dec = Algo.StepMove(anchor.Dec, mapped_dec, step_radius);
            transfer_pop = [transfer_pop, c];
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

    function use_feas = SelectExternalChannel(Algo, feas_idx, nonfeas_idx)
        if isempty(feas_idx) && isempty(nonfeas_idx)
            use_feas = true;
        elseif isempty(feas_idx)
            use_feas = false;
        elseif isempty(nonfeas_idx)
            use_feas = true;
        else
            use_feas = rand() < Algo.FeasBias;
        end
    end

    function step_radius = EstimateStepRadius(Algo, population, use_feasible_channel)
        pop = Algo.SelectChannelPopulation(population, use_feasible_channel);
        decs = pop.Decs;
        center = mean(decs, 1);
        dist = sqrt(sum((decs - center).^2, 2));
        step_radius = Algo.StepScale * mean(dist);
        if ~isfinite(step_radius) || step_radius <= 0
            step_radius = Algo.StepScale * 0.1 * sqrt(size(population.Decs, 2));
        end
    end

    function dec = StepMove(Algo, origin_dec, mapped_dec, step_radius)
        vec = mapped_dec - origin_dec;
        norm_vec = norm(vec);
        if norm_vec <= 1e-12
            dec = origin_dec;
            return;
        end
        step = min(norm_vec, max(step_radius, 1e-3));
        dec = origin_dec + vec / norm_vec * step;
        dec = Algo.BoundDec(dec);
    end

    function succ_num = CountSelectedExternal(~, rank, pop_size, n_off1, n_ext)
        if n_ext <= 0
            succ_num = 0;
            return;
        end
        ext_start = pop_size + n_off1 + 1;
        ext_end = ext_start + n_ext - 1;
        succ_num = sum(rank >= ext_start & rank <= ext_end);
    end

    function tau = AdjustTau(Algo, tau, num_hist, suc_hist, gen)
        left = max(1, gen - Algo.AdjGap + 1);
        numAll = sum(num_hist(left:gen));
        sucAll = sum(suc_hist(left:gen));
        if numAll == 0
            tau = min(max(0, round(Algo.TauMax)), tau + 1);
        elseif sucAll / numAll > Algo.SuccThresh
            tau = min(max(0, round(Algo.TauMax)), tau + 1);
        else
            tau = max(0, tau - 1);
        end
    end

    function dec = BoundDec(~, dec)
        dec(dec > 1) = 1;
        dec(dec < 0) = 0;
    end
end
end
