%% cmd_verify_fea_mass.m - Verify FEA mass vs analytical mass
% Runs a few default-parameter evaluations on each task to compare
% mass computed by ANSYS vs the analytical formula.
%
% Usage: cd('MTO'); run('cmd_verify_fea_mass.m')

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));
addpath(genpath(pwd));

%% Config
tasks_to_test = [3, 4];  % which tasks to verify
apdl_nproc = 4;

%% Setup
ship_prob = Ship_Panel_Problem();

fprintf('===== FEA Mass vs Analytical Mass Verification =====\n\n');

for ti = 1:numel(tasks_to_test)
    task_id = tasks_to_test(ti);
    task = ship_prob.Tasks(task_id);

    % Use default parameters (midpoint of design space)
    [lb, x0, ub] = ship_prob.get_design_space(task_id);

    % Test 3 points: lower bound, midpoint, upper bound
    test_points = {lb, x0, ub};
    test_names = {'Lower Bound', 'Midpoint (default)', 'Upper Bound'};

    fprintf('---------- Task %d ----------\n', task_id);
    fprintf('  s_long=%d, s_rib=%d, q1=%g, sigma_allow=%g\n', ...
        task.s_long, task.s_rib, task.q1, task.sigma_allow);
    fprintf('  bend_allow=%.1f, shear_allow=%.1f\n\n', ...
        task.bend_allow, task.shear_allow);

    % Prepare ANSYS config
    this_file = mfilename('fullpath');
    repo_root = fileparts(fileparts(this_file));
    cfg = struct();
    cfg.apdl_dir = fullfile(repo_root, 'APDL');
    cfg.n_proc = apdl_nproc;
    cfg.cleanup = true;
    cfg.work_dir = fullfile(repo_root, 'APDLRESULTS_MTO', sprintf('verify_task%d', task_id));

    for pi = 1:numel(test_points)
        x = test_points{pi};
        fprintf('  [%s] x = [%s]\n', test_names{pi}, num2str(x, '%.1f '));

        [obj, con, extra] = run_ansys_eval(x, task_id, cfg);

        if extra.error
            fprintf('    !! ANSYS ERROR\n\n');
            continue;
        end

        fprintf('    Mass (analytical): %.4f kg\n', extra.mass_analytical);
        fprintf('    Mass (FEA):        %.4f kg\n', extra.mass_fea);
        diff_pct = (extra.mass_fea - extra.mass_analytical) / extra.mass_analytical * 100;
        fprintf('    Difference:        %.4f kg (%.2f%%)\n', ...
            extra.mass_fea - extra.mass_analytical, diff_pct);
        fprintf('    max_bend=%.2f, max_shear=%.2f\n', extra.max_bend, extra.max_shear);
        fprintf('    con=[%s], feasible=%d\n', num2str(con, '%.2f '), extra.feasible);
        if numel(con) >= 3
            fprintf('    geom(hL2-hL1)=%.2f (<=0 means satisfied)\n', con(3));
        end
        if numel(con) >= 4
            fprintf('    geom(hL3-hL2)=%.2f (<=0 means satisfied)\n', con(4));
        end
        fprintf('\n');
    end
end

fprintf('===== Verification Complete =====\n');
