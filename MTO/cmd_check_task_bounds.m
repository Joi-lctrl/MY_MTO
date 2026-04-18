%% cmd_check_task_bounds.m - Check lower/upper feasibility for selected tasks
% Purpose:
%   Validate that for each selected task:
%   1) lower-bound design violates constraints
%   2) upper-bound design is feasible
%
% Usage:
%   cd('MTO'); run('cmd_check_task_bounds.m')

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

repo_root = fileparts(pwd);
addpath(genpath(pwd));
addpath(genpath(fullfile(repo_root, 'APDL')));

%% Config
tasks_to_test = [7];
apdl_nproc = 4;
cleanup = true;      % true: remove temporary ANSYS files
save_report = true;  % save text report under APDLRESULTS_MTO

ship_prob = Ship_Panel_Problem();

report_fid = -1;
if save_report
    report_dir = fullfile(repo_root, 'APDLRESULTS_MTO', 'bound_check_reports');
    if exist(report_dir, 'dir') ~= 7
        mkdir(report_dir);
    end
    report_file = fullfile(report_dir, ...
        sprintf('bound_check_%s.txt', datestr(now, 'yyyymmdd_HHMMSS')));
    report_fid = fopen(report_file, 'w');
end

fprintf('===== Bound Feasibility Check =====\n');
if report_fid ~= -1
    fprintf(report_fid, '===== Bound Feasibility Check =====\n');
end

for ti = 1:numel(tasks_to_test)
    task_id = tasks_to_test(ti);
    task = ship_prob.Tasks(task_id);
    [lb, ~, ub] = ship_prob.get_design_space(task_id);

    cfg = struct();
    cfg.apdl_dir = fullfile(repo_root, 'APDL');
    cfg.n_proc = apdl_nproc;
    cfg.cleanup = cleanup;
    cfg.work_dir = fullfile(repo_root, 'APDLRESULTS_MTO', sprintf('boundcheck_task%d', task_id));

    line = sprintf('\n--- Task %d ---', task_id);
    fprintf('%s\n', line);
    if report_fid ~= -1
        fprintf(report_fid, '%s\n', line);
    end

    line = sprintf('q1=%.2f, bend_allow=%.2f, shear_allow=%.2f', ...
        task.q1, task.bend_allow, task.shear_allow);
    fprintf('%s\n', line);
    if report_fid ~= -1
        fprintf(report_fid, '%s\n', line);
    end

    cases = {'LOWER', lb; 'UPPER', ub};
    for ci = 1:size(cases, 1)
        case_name = cases{ci, 1};
        x = cases{ci, 2};

        [obj, con, extra] = run_ansys_eval(x, task_id, cfg);
        cv = sum(max(0, con));
        is_feasible = (cv <= 0);

        if ci == 1
            expected = 'VIOLATE';
            pass_case = ~is_feasible;
        else
            expected = 'FEASIBLE';
            pass_case = is_feasible;
        end

        if extra.error
            status = 'ANSYS_ERROR';
        elseif is_feasible
            status = 'FEASIBLE';
        else
            status = 'VIOLATE';
        end

        line = sprintf('[%s] expected=%s, status=%s, PASS=%d', ...
            case_name, expected, status, pass_case);
        fprintf('%s\n', line);
        if report_fid ~= -1
            fprintf(report_fid, '%s\n', line);
        end

        line = sprintf('  Obj=%.4f, Con=[%s], CV=%.4f', ...
            obj, num2str(con, '%.4f '), cv);
        fprintf('%s\n', line);
        if report_fid ~= -1
            fprintf(report_fid, '%s\n', line);
        end

        line = sprintf('  max_bend=%.4f, max_shear=%.4f', ...
            extra.max_bend, extra.max_shear);
        fprintf('%s\n', line);
        if report_fid ~= -1
            fprintf(report_fid, '%s\n', line);
        end

        if numel(con) >= 3
            line = sprintf('  geom(hL2-hL1)=%.4f (<=0 means satisfied)', con(3));
            fprintf('%s\n', line);
            if report_fid ~= -1
                fprintf(report_fid, '%s\n', line);
            end
        end
        if numel(con) >= 4
            line = sprintf('  geom(hL3-hL2)=%.4f (<=0 means satisfied)', con(4));
            fprintf('%s\n', line);
            if report_fid ~= -1
                fprintf(report_fid, '%s\n', line);
            end
        end
    end
end

fprintf('\n===== Check Complete =====\n');
if report_fid ~= -1
    fprintf(report_fid, '\n===== Check Complete =====\n');
    fclose(report_fid);
    fprintf('Report saved: %s\n', report_file);
end
