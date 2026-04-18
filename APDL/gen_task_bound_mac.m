%% gen_task_bound_mac.m - Generate APDL lower/upper bound macros from current task definitions
clear; clc;
cd(fileparts(mfilename('fullpath')));
addpath(genpath(pwd));

if ~exist('task_ids', 'var') || isempty(task_ids)
    task_ids = [8 9];
end

ship_prob = Ship_Panel_Problem();

for task_id = reshape(task_ids, 1, [])
    [lb, ~, ub] = ship_prob.get_design_space(task_id);
    task = ship_prob.Tasks(task_id);

    lower_file = sprintf('Task%d_lower.mac', task_id);
    upper_file = sprintf('Task%d_upper.mac', task_id);

    mac_lb = ship_prob.generate_mac(lb, task_id);
    fid = fopen(lower_file, 'w');
    fprintf(fid, '%s\n', mac_lb);
    fclose(fid);

    mac_ub = ship_prob.generate_mac(ub, task_id);
    fid = fopen(upper_file, 'w');
    fprintf(fid, '%s\n', mac_ub);
    fclose(fid);

    fprintf('Generated %s and %s\n', lower_file, upper_file);
    fprintf('  q1=%g, sigma_allow=%g, bend_allow=%g, shear_allow=%g\n', ...
        task.q1, task.sigma_allow, task.bend_allow, task.shear_allow);
end
