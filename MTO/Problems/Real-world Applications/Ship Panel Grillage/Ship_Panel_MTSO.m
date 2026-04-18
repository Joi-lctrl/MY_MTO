classdef Ship_Panel_MTSO < Problem
% <Multi-task> <Single-objective> <Constrained>

% Parametric ship grillage sizing problem driven by MATLAB + ANSYS APDL.
% Task 1: s_long=800, s_rib=2400, q1=18, sigma_allow=130
% Task 2: s_long=1000, s_rib=3200, q1=25, sigma_allow=150

properties
    Cleanup logical = true
    APDL_NProc double = 2
    APDLDir char = ''
    WorkRoot char = ''
    ActiveTasks double = [1 2 3 4]
end

methods
    function Prob = Ship_Panel_MTSO(varargin)
        Prob = Prob@Problem(varargin);
        Prob.N = 6;
        Prob.maxFE = 48;
    end

    function Parameter = getParameter(Prob)
        Parameter = [Prob.getRunParameter(), ...
            {'Cleanup APDL Temp (0/1)', num2str(double(Prob.Cleanup)), ...
            'APDL NProc', num2str(Prob.APDL_NProc)}];
    end

    function Prob = setParameter(Prob, Parameter)
        Prob.setRunParameter(Parameter(1:2));
        Prob.Cleanup = logical(str2double(Parameter{3}));
        Prob.APDL_NProc = str2double(Parameter{4});
        Prob.setTasks();
    end

    function setTasks(Prob)
        apdl_dir = Prob.getAPDLDir();
        if exist(apdl_dir, 'dir') ~= 7
            error('Ship_Panel_MTSO:APDLDirMissing', ...
                'APDL directory not found: %s', apdl_dir);
        end
        addpath(apdl_dir);

        ship_prob = Ship_Panel_Problem();
        active_tasks = Prob.ActiveTasks(:)';
        if isempty(active_tasks) || any(active_tasks < 1) || any(active_tasks > ship_prob.T)
            error('Ship_Panel_MTSO:InvalidActiveTasks', ...
                'ActiveTasks must be a non-empty subset of 1:%d.', ship_prob.T);
        end

        lb = cell(1, numel(active_tasks));
        ub = cell(1, numel(active_tasks));
        fnc = cell(1, numel(active_tasks));
        for k = 1:numel(active_tasks)
            task_id = active_tasks(k);
            [lb{k}, ~, ub{k}] = ship_prob.get_design_space(task_id);
            fnc{k} = Prob.makeTaskFcn(task_id);
        end

        Prob.T = numel(active_tasks);
        Prob.M = ones(1, Prob.T);
        Prob.D = cellfun(@length, lb);
        Prob.Lb = lb;
        Prob.Ub = ub;
        Prob.Fnc = fnc;
    end
end

methods (Access = private)
    function [Objs, Cons] = evalTaskBatch(Prob, x, task_id)
        n = size(x, 1);
        Objs = zeros(n, 1);
        Cons = [];

        cfg = Prob.getEvalConfig(task_id);
        for i = 1:n
            fprintf('[DEBUG] Task%d Ind%d/%d Dec=[%s]\n', ...
                task_id, i, n, num2str(x(i, :), '%.4f '));
            [obj, con, extra] = run_ansys_eval(x(i, :), task_id, cfg);
            if isempty(Cons)
                Cons = zeros(n, numel(con));
            end
            Objs(i, 1) = obj;
            Cons(i, :) = reshape(con, 1, []);

            % Convert unexpected solver failures into a strong penalty
            % while keeping the run alive for the optimizer.
            if extra.error
                fprintf('[DEBUG] Task%d Ind%d ANSYS ERROR -> penalty\n', task_id, i);
                Objs(i, 1) = 1e10;
                Cons(i, :) = 100 * ones(1, size(Cons, 2));
            end
            fprintf('[DEBUG] Task%d Ind%d -> Obj=%.4f Con=[%s] CV=%.4f\n', ...
                task_id, i, Objs(i,1), num2str(Cons(i,:), '%.4f '), sum(max(0, Cons(i,:))));
        end
    end

    function cfg = getEvalConfig(Prob, task_id)
        apdl_dir = Prob.getAPDLDir();
        work_root = Prob.getWorkRoot();
        cfg = struct();
        cfg.apdl_dir = apdl_dir;
        cfg.n_proc = Prob.APDL_NProc;
        cfg.cleanup = Prob.Cleanup;
        cfg.reuse_mesh = true;
        cfg.work_dir = fullfile(work_root, sprintf('task%d', task_id));
    end

    function apdl_dir = getAPDLDir(Prob)
        if ~isempty(Prob.APDLDir)
            apdl_dir = Prob.APDLDir;
            return;
        end
        this_file = mfilename('fullpath');
        repo_root = fileparts(fileparts(fileparts(fileparts(fileparts(this_file)))));
        apdl_dir = fullfile(repo_root, 'APDL');
    end

    function work_root = getWorkRoot(Prob)
        if ~isempty(Prob.WorkRoot)
            work_root = Prob.WorkRoot;
            return;
        end
        this_file = mfilename('fullpath');
        repo_root = fileparts(fileparts(fileparts(fileparts(fileparts(this_file)))));
        work_root = fullfile(repo_root, 'APDLRESULTS_MTO');
        if exist(work_root, 'dir') ~= 7
            mkdir(work_root);
        end
    end

    function fnc = makeTaskFcn(Prob, task_id)
        fnc = @(x)Prob.evalTaskBatch(x, task_id);
    end
end
end
