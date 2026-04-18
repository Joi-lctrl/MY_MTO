classdef IMODE < Algorithm
% <Single-task> <Single-objective> <None/Constrained>

%------------------------------- Reference --------------------------------
% @InProceedings{Sallam2020IMODE,
%   author    = {Sallam, Khalid M. and Elsayed, Seham M. and
%                Chakrabortty, Rajib K. and Ryan, Michael J.},
%   booktitle = {2020 IEEE Congress on Evolutionary Computation},
%   title     = {Improved Multi-operator Differential Evolution Algorithm
%                for Solving Unconstrained Problems},
%   year      = {2020},
%   pages     = {1-8},
%   doi       = {10.1109/CEC48606.2020.9185761},
% }
%--------------------------------------------------------------------------

%------------------------------- Copyright --------------------------------
% Copyright (c) Yanchi Li. You are free to use the MToP for research
% purposes. All publications which use this platform should acknowledge
% the use of MToP and cite as "Y. Li, W. Gong, T. Zhang, F. Ming,
% S. Li, Q. Gu, and Y.-S. Ong, MToP: A MATLAB Benchmarking Platform for
% Evolutionary Multitasking, 2023, arXiv:2312.08134"
%--------------------------------------------------------------------------

properties (SetAccess = public)
    minN = 4
    aRate = 2.6
    AdaptSigma = sqrt(0.1)
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'minN: minimum population size', num2str(Algo.minN), ...
                'aRate: archive size ratio', num2str(Algo.aRate), ...
                'AdaptSigma: parameter sampling scale', num2str(Algo.AdaptSigma)};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.minN = str2double(Parameter{i}); i = i + 1;
        Algo.aRate = str2double(Parameter{i}); i = i + 1;
        Algo.AdaptSigma = str2double(Parameter{i}); i = i + 1;
    end

    function run(Algo, Prob)
        population = Initialization(Algo, Prob, Individual_DE);
        for t = 1:Prob.T
            initN(t) = length(population{t}); %#ok<AGROW>
            memSize = max(1, 20 * Prob.D(t));
            Hidx{t} = 1; %#ok<AGROW>
            MF{t} = 0.2 .* ones(memSize, 1); %#ok<AGROW>
            MCR{t} = 0.2 .* ones(memSize, 1); %#ok<AGROW>
            MOP{t} = ones(1, 3) ./ 3; %#ok<AGROW>
            archive{t} = Individual_DE.empty(); %#ok<AGROW>
        end

        while Algo.notTerminated(Prob, population)
            for t = 1:Prob.T
                targetN = ceil((Algo.minN - initN(t)) / Prob.maxFE * Algo.FE + initN(t));
                targetN = max(Algo.minN, min(initN(t), targetN));
                if length(population{t}) > targetN
                    [~, rank] = sortrows([population{t}.CVs, population{t}.Objs], [1, 2]);
                    population{t} = population{t}(rank(1:targetN));
                end

                archiveCap = max(1, ceil(Algo.aRate * length(population{t})));
                if length(archive{t}) > archiveCap
                    archive{t} = archive{t}(randperm(length(archive{t}), archiveCap));
                end

                [offspring, opIdx] = Algo.Generation(population{t}, archive{t}, MCR{t}, MF{t}, MOP{t});
                offspring = Algo.Evaluation(offspring, Prob, t);

                parentFitness = Algo.SingleFitness(population{t});
                offspringFitness = Algo.SingleFitness(offspring);
                improvement = max(0, parentFitness - offspringFitness);

                [~, replace] = Selection_Tournament(population{t}, offspring);

                archive{t} = [archive{t}, population{t}(replace)];
                if length(archive{t}) > archiveCap
                    archive{t} = archive{t}(randperm(length(archive{t}), archiveCap));
                end

                [MF{t}, MCR{t}, Hidx{t}] = Algo.UpdateSuccessMemory( ...
                    MF{t}, MCR{t}, Hidx{t}, population{t}, offspring, replace);

                population{t}(replace) = offspring(replace);
                MOP{t} = Algo.UpdateOperatorProbabilities(opIdx, improvement, population{t}, MOP{t});
            end
        end
    end

    function [offspring, opIdx] = Generation(Algo, population, archive, MCR, MF, MOP)
        nPop = length(population);
        [~, rank] = sortrows([population.CVs, population.Objs], [1, 2]);
        top25 = rank(1:max(1, ceil(0.25 * nPop)));
        top50 = rank(1:max(2, ceil(0.5 * nPop)));
        union = [population, archive];
        if isempty(union)
            union = population;
        end

        offspring = population;
        opEdges = cumsum(MOP);
        for i = 1:nPop
            parentDec = population(i).Dec;
            d = numel(parentDec);
            memIdx = randi(numel(MCR));

            F = cauchyrnd(MF(memIdx), Algo.AdaptSigma);
            while F <= 0
                F = cauchyrnd(MF(memIdx), Algo.AdaptSigma);
            end
            F = min(1, F);

            CR = MCR(memIdx) + randn() * Algo.AdaptSigma;
            CR = max(0, min(1, CR));

            opRand = rand();
            if opRand <= opEdges(1)
                op = 1;
            elseif opRand <= opEdges(2)
                op = 2;
            else
                op = 3;
            end
            opIdx(i) = op; %#ok<AGROW>

            xp1 = population(top25(randi(numel(top25)))).Dec;
            xp2 = population(top50(randi(numel(top50)))).Dec;
            xr1 = population(randi(nPop)).Dec;
            xr3 = population(randi(nPop)).Dec;
            xr2 = union(randi(length(union))).Dec;

            switch op
                case 1
                    mutant = parentDec + F .* (xp1 - parentDec + xr1 - xr2);
                case 2
                    mutant = parentDec + F .* (xp1 - parentDec + xr1 - xr3);
                otherwise
                    mutant = F .* (xr1 + xp2 - xr3);
            end

            if rand() < 0.4
                trial = mutant;
                keepParent = rand(1, d) > CR;
                trial(keepParent) = parentDec(keepParent);
            else
                trial = Algo.ExponentialCrossover(mutant, parentDec, CR);
            end

            vioLow = trial < 0;
            trial(vioLow) = parentDec(vioLow) ./ 2;
            vioUp = trial > 1;
            trial(vioUp) = (parentDec(vioUp) + 1) ./ 2;

            offspring(i).Dec = trial;
            offspring(i).F = F;
            offspring(i).CR = CR;
        end
    end
end

methods (Access = private)
    function [MF, MCR, Hidx] = UpdateSuccessMemory(~, MF, MCR, Hidx, population, offspring, replace)
        if any(replace)
            SF = [offspring(replace).F]';
            SCR = [offspring(replace).CR]';
            delta = population(replace).CVs - offspring(replace).CVs;
            deltaObj = population(replace).Objs - offspring(replace).Objs;
            deltaObj(deltaObj < 0) = 0;
            delta(delta <= 0) = deltaObj(delta <= 0);
            weightSum = sum(delta);
            if weightSum > 0
                weights = delta ./ weightSum;
            else
                weights = ones(size(delta)) ./ numel(delta);
            end

            crDenom = sum(weights .* SCR);
            if crDenom > 0
                MCR(Hidx) = sum(weights .* (SCR .^ 2)) ./ crDenom;
            else
                MCR(Hidx) = 0.5;
            end

            fDenom = sum(weights .* SF);
            if fDenom > 0
                MF(Hidx) = sum(weights .* (SF .^ 2)) ./ fDenom;
            else
                MF(Hidx) = 0.5;
            end
        else
            MCR(Hidx) = 0.5;
            MF(Hidx) = 0.5;
        end
        Hidx = mod(Hidx, numel(MF)) + 1;
    end

    function MOP = UpdateOperatorProbabilities(Algo, opIdx, improvement, population, MOP)
        currentFitness = abs(Algo.SingleFitness(population));
        currentFitness(currentFitness < eps) = 1;
        scoreInput = max(0, improvement ./ currentFitness);

        scores = zeros(1, 3);
        for op = 1:3
            mask = (opIdx == op);
            if ~any(mask)
                MOP = ones(1, 3) ./ 3;
                return;
            end
            scores(op) = mean(scoreInput(mask));
        end

        if sum(scores) <= 0
            MOP = ones(1, 3) ./ 3;
            return;
        end

        scores = scores ./ sum(scores);
        MOP = max(0.1, min(0.9, scores));
        MOP = MOP ./ sum(MOP);
    end

    function fit = SingleFitness(~, population)
        obj = population.Objs;
        cv = population.CVs;
        fit = cv + 1e10;
        feasible = cv <= 0;
        fit(feasible) = obj(feasible);
    end

    function trial = ExponentialCrossover(~, mutant, parent, CR)
        d = numel(parent);
        startIdx = randi(d);
        len = find([rand(1, d), 2] > CR, 1) - 1;
        if isempty(len) || len < 1
            len = 1;
        end
        idx = mod((startIdx - 1) + (0:len - 1), d) + 1;
        trial = parent;
        trial(idx) = mutant(idx);
    end
end
end
