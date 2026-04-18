classdef MFEA_RMPLog < MFEA
% <Multi-task> <Single-objective> <None/Constrained>
%
% MFEA variant that records per-generation RMP and transfer diagnostics.

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
            RMP = Algo.buildRMPMatrix(Prob.T);
            Algo.RMPHistory{end + 1, 1} = RMP;
            Algo.RMPHistoryGen(end + 1, 1) = Algo.Gen;
            Algo.RMPHistoryFE(end + 1, 1) = Algo.FE;

            % Generation
            [offspring, transfer_flag] = Algo.GenerationWithTrace(population);

            % Evaluation
            offspring_temp = Individual_MF.empty();
            task_stats = repmat(MFEA_RMPLog.emptyTaskStat(), 1, Prob.T);
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

    function [offspring, transfer_flag] = GenerationWithTrace(Algo, population)
        indorder = randperm(length(population));
        transfer_flag = false(1, length(population));
        count = 1;
        for i = 1:ceil(length(population) / 2)
            p1 = indorder(i);
            p2 = indorder(i + fix(length(population) / 2));
            offspring(count) = population(p1); %#ok<AGROW>
            offspring(count + 1) = population(p2); %#ok<AGROW>

            if (population(p1).MFFactor == population(p2).MFFactor) || rand() < Algo.RMP
                % crossover
                [offspring(count).Dec, offspring(count + 1).Dec] = ...
                    GA_Crossover(population(p1).Dec, population(p2).Dec, Algo.MuC);
                % imitation
                p = [p1, p2];
                offspring(count).MFFactor = population(p(randi(2))).MFFactor;
                offspring(count + 1).MFFactor = population(p(randi(2))).MFFactor;

                is_cross_transfer = population(p1).MFFactor ~= population(p2).MFFactor;
                transfer_flag(count) = is_cross_transfer;
                transfer_flag(count + 1) = is_cross_transfer;
            else
                % mutation
                offspring(count).Dec = GA_Mutation(population(p1).Dec, Algo.MuM);
                offspring(count + 1).Dec = GA_Mutation(population(p2).Dec, Algo.MuM);
                % imitation
                offspring(count).MFFactor = population(p1).MFFactor;
                offspring(count + 1).MFFactor = population(p2).MFFactor;
                transfer_flag(count) = false;
                transfer_flag(count + 1) = false;
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
    function RMP = buildRMPMatrix(Algo, num_tasks)
        RMP = Algo.RMP * ones(num_tasks);
        RMP(1:num_tasks + 1:end) = 1;
    end

    function stats = computeTaskStat(~, offspring_t, transfer_t, task_idx)
        stats = MFEA_RMPLog.emptyTaskStat();
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
        stats.FRTransfer = MFEA_RMPLog.frac_or_nan(cvs(mask) <= 0);
        stats.FRNonTransfer = MFEA_RMPLog.frac_or_nan(cvs(non_mask) <= 0);
        stats.MeanCVTransfer = MFEA_RMPLog.mean_or_nan(cvs(mask));
        stats.MeanCVNonTransfer = MFEA_RMPLog.mean_or_nan(cvs(non_mask));
        stats.MeanObjTransfer = MFEA_RMPLog.mean_or_nan(obj_col(mask));
        stats.MeanObjNonTransfer = MFEA_RMPLog.mean_or_nan(obj_col(non_mask));
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
