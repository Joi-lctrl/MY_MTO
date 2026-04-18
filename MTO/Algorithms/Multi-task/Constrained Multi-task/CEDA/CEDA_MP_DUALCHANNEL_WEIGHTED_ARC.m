classdef CEDA_MP_DUALCHANNEL_WEIGHTED_ARC < Algorithm
% <Multi-task> <Single-objective> <Constrained>
%
% Archive-enhanced weighted dual-channel variant of CEDA_MP:
% 1) feasible individuals use a feasible-only mapping channel;
% 2) infeasible individuals use an infeasible-only mapping channel;
% 3) channel statistics are estimated with weighted samples;
% 4) an adaptive archive preserves high-quality infeasible solutions that
%    would otherwise be lost when epsilon shrinks, and feeds them into the
%    infeasible channel to improve cross-task mapping quality.

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
    % ----- Archive parameters -----
    ArcRate = 1.0       % Archive capacity per task = ArcRate * N
    ArcMaxAge = 20      % Max generations before an archive member expires
    ArcAlpha = 0.5      % Ranking weight: score = norm(Obj) + ArcAlpha * norm(CV)
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
                'MapReg', num2str(Algo.MapReg), ...
                'ArcRate', num2str(Algo.ArcRate), ...
                'ArcMaxAge', num2str(Algo.ArcMaxAge), ...
                'ArcAlpha', num2str(Algo.ArcAlpha)};
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
        Algo.ArcRate = str2double(Parameter{i}); i = i + 1;
        Algo.ArcMaxAge = str2double(Parameter{i}); i = i + 1;
        Algo.ArcAlpha = str2double(Parameter{i}); i = i + 1;
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

        % --- Initialize per-task archive ---
        ArcCap = ceil(Algo.ArcRate * Prob.N);
        Archive = cell(1, Prob.T);   % Archive{t} = Individual array
        ArcAge  = cell(1, Prob.T);   % ArcAge{t}  = integer age per member
        for t = 1:Prob.T
            Archive{t} = Individual.empty();
            ArcAge{t}  = [];
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
                % Pass archives to Generation1 for infeasible channel augmentation
                offspring1 = Algo.Generation1( ...
                    population1{t}, mating_pool1{t}, ...
                    population1{k}(mating_pool1{k}), ...
                    Archive{t}, Archive{k});
                offspring2 = Algo.Generation2( ...
                    population2{t}, mating_pool2{t}, ...
                    population2{k}(mating_pool2{k}));
                offspring = [offspring1, offspring2];
                offspring = Algo.Evaluation(offspring, Prob, t);

                % Update archive BEFORE selection so good infeasible
                % offspring are captured before being eliminated
                [Archive{t}, ArcAge{t}] = Algo.UpdateArchive( ...
                    Archive{t}, ArcAge{t}, offspring, ...
                    population2{t}, Ep0{t}, ArcCap);

                population1{t} = Selection_Elit(population1{t}, offspring, Ep_vals(t));
                population2{t} = Selection_Elit(population2{t}, offspring, 0);
            end
        end
    end

    %% ============ Generation (Pop1): dual-channel + archive ============
    function offspring = Generation1(Algo, population, pool, transpop, arc_local, arc_source)
        population = population(pool);

        % Feasible channel: no archive augmentation
        [temp_Dec_feas, temp_Dec2_feas] = Algo.BuildChannelMaps( ...
            population, transpop, true, Individual.empty(), Individual.empty());
        % Infeasible channel: augment with archive
        [temp_Dec_infeas, temp_Dec2_infeas] = Algo.BuildChannelMaps( ...
            population, transpop, false, arc_local, arc_source);

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

    %% ============ Generation (Pop2): unchanged ============
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

    %% ============ Archive management ============
    function [arc, age] = UpdateArchive(Algo, arc, age, offspring, pop2, ep0, cap)
        % --- Determine entry threshold ---
        % Best feasible objective from Pop2 (strict feasibility population)
        feas_idx = find([pop2.CV] <= 0);
        if ~isempty(feas_idx)
            best_feas_obj = min([pop2(feas_idx).Obj]);
        else
            best_feas_obj = inf; % no feasible solution yet -> accept freely
        end

        % CV upper bound for archive entry: fixed at Ep0 (does not shrink)
        % This preserves the archive's ability to hold "near-feasible" solutions
        % even after epsilon has decayed to 0 in Pop1
        cv_threshold = max(ep0, 1e-6);

        % --- Screen offspring for archive candidates ---
        for i = 1:length(offspring)
            ind = offspring(i);
            % Entry criteria:
            %   1) must be infeasible (CV > 0)
            %   2) objective better than best known feasible solution
            %   3) constraint violation within initial epsilon range
            if ind.CV > 0 && ind.Obj < best_feas_obj && ind.CV <= cv_threshold
                arc = [arc, ind];
                age = [age, 0];
            end
        end

        % --- Age all members (new ones just got age=0, will become 1 next gen) ---
        age = age + 1;

        % --- Remove expired members ---
        alive = (age <= Algo.ArcMaxAge);
        arc = arc(alive);
        age = age(alive);

        % --- Trim to capacity ---
        if length(arc) > cap
            % Rank by normalized Obj + ArcAlpha * normalized CV
            obj_all = [arc.Obj]';
            cv_all  = [arc.CV]';
            score = Algo.NormalizeVector(obj_all) + Algo.ArcAlpha * Algo.NormalizeVector(cv_all);
            [~, order] = sort(score, 'ascend');
            arc = arc(order(1:cap));
            age = age(order(1:cap));
        end
    end

    %% ============ Dual-channel mapping with archive augmentation ============
    function [temp_Dec, temp_Dec2] = BuildChannelMaps(Algo, population, transpop, use_feasible_channel, arc_local, arc_source)
        dst_pop = Algo.SelectChannelPopulation(population, use_feasible_channel);
        src_pop = Algo.SelectChannelPopulation(transpop, use_feasible_channel);

        % Augment infeasible channel with archive individuals
        if ~use_feasible_channel
            if ~isempty(arc_local)
                dst_pop = [dst_pop, arc_local];
            end
            if ~isempty(arc_source)
                src_pop = [src_pop, arc_source];
            end
        end

        dst_w = Algo.BuildChannelWeights(dst_pop, use_feasible_channel);
        src_w = Algo.BuildChannelWeights(src_pop, use_feasible_channel);
        temp_Dec = Algo.WeightedTrans(src_pop.Decs, dst_pop.Decs, transpop.Decs, src_w, dst_w);
        temp_Dec2 = Algo.WeightedTrans(dst_pop.Decs, src_pop.Decs, population.Decs, dst_w, src_w);
    end

    %% ============ Channel population selection ============
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

    %% ============ Weighted statistics ============
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
