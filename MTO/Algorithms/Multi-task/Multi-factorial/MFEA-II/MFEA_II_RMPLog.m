classdef MFEA_II_RMPLog < MFEA_II
% <Multi-task> <Single-objective> <None/Constrained>

% MFEA-II variant that preserves the original search behavior while
% recording the online-learned RMP matrix at each generation.
% It also records transfer-vs-nontransfer offspring quality, so that
% negative transfer can be verified from run logs.

properties (SetAccess = public)
    RMPHistory cell = {}
    RMPHistoryGen double = []
    RMPHistoryFE double = []
    TransferDiagHistory cell = {}
    TransferDiagGen double = []
    TransferDiagFE double = []
end

methods
    function reset(Algo)
        reset@Algorithm(Algo);
        Algo.RMPHistory = {};
        Algo.RMPHistoryGen = [];
        Algo.RMPHistoryFE = [];
        Algo.TransferDiagHistory = {};
        Algo.TransferDiagGen = [];
        Algo.TransferDiagFE = [];
    end

    function run(Algo, Prob)
        % Initialize
        population = Initialization_MF(Algo, Prob, Individual_MF);

        while Algo.notTerminated(Prob, population)
            % Extract task-specific subpopulations
            subpops = repmat(struct('data', []), 1, Prob.T);
            for i = 1:length(population)
                factor = population(i).MFFactor;
                subpops(factor).data = [subpops(factor).data; population(i).Dec];
            end

            % Learn and record the generation-wise RMP matrix.
            RMP = learnRMP(subpops, Prob.D);
            Algo.RMPHistory{end + 1, 1} = RMP;
            Algo.RMPHistoryGen(end + 1, 1) = Algo.Gen;
            Algo.RMPHistoryFE(end + 1, 1) = Algo.FE;

            % Generation
            [offspring, transfer_flag] = Algo.Generation(population, RMP);

            % Evaluation
            offspring_temp = Individual_MF.empty();
            task_stats = repmat(MFEA_II_RMPLog.emptyTaskStat(), 1, Prob.T);
            for t = 1:Prob.T
                idx_t = find([offspring.MFFactor] == t);
                offspring_t = offspring(idx_t);
                transfer_t = transfer_flag(idx_t);
                offspring_t = Algo.Evaluation(offspring_t, Prob, t);
                task_stats(t) = Algo.computeTaskStat(offspring_t, transfer_t, t);
                for i = 1:length(offspring_t)
                    offspring_t(i).MFObj = inf(1, Prob.T);
                    offspring_t(i).MFCV = inf(1, Prob.T);
                    offspring_t(i).MFObj(t) = offspring_t(i).Obj;
                    offspring_t(i).MFCV(t) = offspring_t(i).CV;
                end
                offspring_temp = [offspring_temp, offspring_t];
            end
            offspring = offspring_temp;
            Algo.TransferDiagHistory{end + 1, 1} = task_stats;
            Algo.TransferDiagGen(end + 1, 1) = Algo.Gen;
            Algo.TransferDiagFE(end + 1, 1) = Algo.FE;

            % Selection
            population = Selection_MF(population, offspring, Prob);
        end
    end

    function [offspring, transfer_flag] = Generation(Algo, population, RMP)
        indorder = randperm(length(population));
        transfer_flag = false(1, length(population));
        count = 1;
        for i = 1:ceil(length(population) / 2)
            p1 = indorder(i);
            p2 = indorder(i + fix(length(population) / 2));
            rmp = RMP(population(p1).MFFactor, population(p2).MFFactor);
            offspring(count) = population(p1); %#ok<AGROW>
            offspring(count + 1) = population(p2); %#ok<AGROW>

            if (population(p1).MFFactor == population(p2).MFFactor) || rand() < rmp
                % crossover
                [offspring(count).Dec, offspring(count + 1).Dec] = ...
                    GA_Crossover(population(p1).Dec, population(p2).Dec, Algo.MuC);
                % mutation
                offspring(count).Dec = GA_Mutation(offspring(count).Dec, Algo.MuM);
                offspring(count + 1).Dec = GA_Mutation(offspring(count + 1).Dec, Algo.MuM);
                % variable swap (uniform X)
                swap_indicator = (rand(1, length(population(p1).Dec)) >= Algo.Swap);
                temp = offspring(count + 1).Dec(swap_indicator);
                offspring(count + 1).Dec(swap_indicator) = offspring(count).Dec(swap_indicator);
                offspring(count).Dec(swap_indicator) = temp;
                % imitation
                p = [p1, p2];
                offspring(count).MFFactor = population(p(randi(2))).MFFactor;
                offspring(count + 1).MFFactor = population(p(randi(2))).MFFactor;

                is_cross_transfer = population(p1).MFFactor ~= population(p2).MFFactor;
                transfer_flag(count) = is_cross_transfer;
                transfer_flag(count + 1) = is_cross_transfer;
            else
                % Randomly pick another individual from the same task
                p = [p1, p2];
                for x = 1:2
                    find_idx = find([population.MFFactor] == population(p(x)).MFFactor);
                    idx = find_idx(randi(length(find_idx)));
                    while idx == p(x)
                        idx = find_idx(randi(length(find_idx)));
                    end
                    offspring_temp = population(idx);
                    % crossover
                    [offspring(count + x - 1).Dec, offspring_temp.Dec] = ...
                        GA_Crossover(population(p(x)).Dec, population(idx).Dec, Algo.MuC);
                    % mutation
                    offspring(count + x - 1).Dec = GA_Mutation(offspring(count + x - 1).Dec, Algo.MuM);
                    offspring_temp.Dec = GA_Mutation(offspring_temp.Dec, Algo.MuM);
                    % variable swap (uniform X)
                    swap_indicator = (rand(1, length(population(p(x)).Dec)) >= Algo.Swap);
                    offspring(count + x - 1).Dec(swap_indicator) = offspring_temp.Dec(swap_indicator);
                    % imitate
                    offspring(count + x - 1).MFFactor = population(p(x)).MFFactor;
                    transfer_flag(count + x - 1) = false;
                end
            end
            for x = count:count + 1
                offspring(x).Dec(offspring(x).Dec > 1) = 1;
                offspring(x).Dec(offspring(x).Dec < 0) = 0;
            end
            count = count + 2;
        end
    end
end

methods (Access = private)
    function stats = computeTaskStat(~, offspring_t, transfer_t, task_idx)
        stats = MFEA_II_RMPLog.emptyTaskStat();
        stats.TaskIndex = task_idx;

        n = numel(offspring_t);
        if n == 0
            return;
        end
        cvs = offspring_t.CVs;
        objs = offspring_t.Objs;
        if isempty(objs)
            obj_col = nan(n, 1);
        else
            obj_col = objs(:, 1);
        end

        mask = logical(transfer_t(:));
        if numel(mask) ~= n
            mask = false(n, 1);
        end
        non_mask = ~mask;

        stats.NTotal = n;
        stats.NTransfer = sum(mask);
        stats.NNonTransfer = sum(non_mask);
        stats.FRTransfer = MFEA_II_RMPLog.frac_or_nan(cvs(mask) <= 0);
        stats.FRNonTransfer = MFEA_II_RMPLog.frac_or_nan(cvs(non_mask) <= 0);
        stats.MeanCVTransfer = MFEA_II_RMPLog.mean_or_nan(cvs(mask));
        stats.MeanCVNonTransfer = MFEA_II_RMPLog.mean_or_nan(cvs(non_mask));
        stats.MeanObjTransfer = MFEA_II_RMPLog.mean_or_nan(obj_col(mask));
        stats.MeanObjNonTransfer = MFEA_II_RMPLog.mean_or_nan(obj_col(non_mask));
        stats.DeltaCV = stats.MeanCVTransfer - stats.MeanCVNonTransfer;
        stats.DeltaObj = stats.MeanObjTransfer - stats.MeanObjNonTransfer;
    end
end

methods (Static, Access = private)
    function stats = emptyTaskStat()
        stats = struct( ...
            'TaskIndex', NaN, ...
            'NTotal', 0, ...
            'NTransfer', 0, ...
            'NNonTransfer', 0, ...
            'FRTransfer', NaN, ...
            'FRNonTransfer', NaN, ...
            'MeanCVTransfer', NaN, ...
            'MeanCVNonTransfer', NaN, ...
            'MeanObjTransfer', NaN, ...
            'MeanObjNonTransfer', NaN, ...
            'DeltaCV', NaN, ...
            'DeltaObj', NaN);
    end

    function m = mean_or_nan(v)
        if isempty(v)
            m = NaN;
        else
            m = mean(v);
        end
    end

    function p = frac_or_nan(v)
        if isempty(v)
            p = NaN;
        else
            p = sum(v) / numel(v);
        end
    end
end
end
