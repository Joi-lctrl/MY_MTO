classdef CEDA_MP_COPULA < Algorithm
% <Multi-task> <Single-objective> <Constrained>

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
        % Initialization
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
                CV = population1{t}.CVs; CV(CV < Ep) = 0;
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
                % Evaluation
                offspring = Algo.Evaluation(offspring, Prob, t);
                % Selection
                population1{t} = Selection_Elit(population1{t}, offspring, Ep);
                population2{t} = Selection_Elit(population2{t}, offspring, 0);
            end
        end
    end

    function offspring = Generation1(Algo, population, pool, transpop)
        population = population(pool);
        population_temp = population;
        temp_Dec = Algo.Copula_trans(transpop, population_temp, transpop.Decs);
        temp_Dec2 = Algo.Copula_trans(population_temp, transpop, population.Decs);
        for i = 1:length(population)
            if rand() < Algo.RMP1
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
            % variable swap (uniform X)
            swap_indicator = (rand(1, length(population(i).Dec)) >= 0.5);
            offspring(i).Dec(swap_indicator) = tempDec(swap_indicator);

            offspring(i).Dec(offspring(i).Dec > 1) = 1;
            offspring(i).Dec(offspring(i).Dec < 0) = 0;
        end
    end

    function offspring = Generation2(Algo, population, pool, transpop)
        population = population(pool);
        population_temp = population;
        temp_Dec = Algo.Copula_trans(transpop, population_temp, transpop.Decs);
        temp_Dec2 = Algo.Copula_trans(population_temp, transpop, population.Decs);
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
            % variable swap (uniform X)
            swap_indicator = (rand(1, length(population(i).Dec)) >= 0.5);
            offspring(i).Dec(swap_indicator) = tempDec(swap_indicator);

            offspring(i).Dec(offspring(i).Dec > 1) = 1;
            offspring(i).Dec(offspring(i).Dec < 0) = 0;
        end
    end

    function trans = Copula_trans(~, Ds, Dt, D)
        % Copula-based domain adaptation:
        % 1. Gaussianize marginals via rank transform + norminv
        % 2. Whitening-coloring in Gaussianized space
        % 3. Inverse transform back to target's original space
        Ds_Dec = Ds.Decs;
        Dt_Dec = Dt.Decs;
        [Ns, dim] = size(Ds_Dec);
        Nt = size(Dt_Dec, 1);

        Ds_gauss = zeros(size(Ds_Dec));
        Dt_gauss = zeros(size(Dt_Dec));
        D_gauss = zeros(size(D));
        sorted_t = zeros(Nt, dim);

        for j = 1:dim
            % Source: ranks -> Gaussian
            [~, ord] = sort(Ds_Dec(:, j));
            r = zeros(Ns, 1); r(ord) = (1:Ns)';
            Ds_gauss(:, j) = sqrt(2) * erfinv(2 * r / (Ns + 1) - 1);

            % Target: ranks -> Gaussian, store sorted values for inverse
            [sorted_t(:, j), ord] = sort(Dt_Dec(:, j));
            r = zeros(Nt, 1); r(ord) = (1:Nt)';
            Dt_gauss(:, j) = sqrt(2) * erfinv(2 * r / (Nt + 1) - 1);

            % D: interpolate into source's rank space -> Gaussian
            sorted_s = sort(Ds_Dec(:, j));
            u_grid = (1:Ns)' / (Ns + 1);
            u = interp1(sorted_s, u_grid, D(:, j), 'linear', 'extrap');
            u = max(min(u, Ns / (Ns + 1)), 1 / (Ns + 1));
            D_gauss(:, j) = sqrt(2) * erfinv(2 * u - 1);
        end

        % Whitening-coloring in Gaussianized space
        mus = mean(Ds_gauss);
        mut = mean(Dt_gauss);

        D_c = D_gauss - mus;
        Ds_c = Ds_gauss - mus;
        Dt_c = Dt_gauss - mut;

        Cs = cov(Ds_c) + eye(dim);
        Ct = cov(Dt_c) + eye(dim);

        trans_gauss = D_c * Cs^(-1 / 2) * Ct^(1 / 2) + mut;

        % Inverse transform: Gaussian -> uniform -> target's original space
        trans = zeros(size(trans_gauss));
        u_grid_t = (1:Nt)' / (Nt + 1);
        for j = 1:dim
            u = 0.5 * erfc(-trans_gauss(:, j) / sqrt(2)); % normcdf
            u = max(min(u, Nt / (Nt + 1)), 1 / (Nt + 1));
            trans(:, j) = interp1(u_grid_t, sorted_t(:, j), u, 'linear', 'extrap');
        end
    end
end
end
