%% gen_task5_mac.m - Generate Task 5 APDL macro files for lower/upper bound
clear; clc;
cd(fileparts(mfilename('fullpath')));
addpath(genpath(pwd));

ship_prob = Ship_Panel_Problem();
[lb, ~, ub] = ship_prob.get_design_space(5);

% Lower bound macro
mac_lb = ship_prob.generate_mac(lb, 5);
fid = fopen('task5_lower.mac', 'w');
fprintf(fid, '%s\n', mac_lb);
fclose(fid);
fprintf('Generated task5_lower.mac\n');

% Upper bound macro
mac_ub = ship_prob.generate_mac(ub, 5);
fid = fopen('task5_upper.mac', 'w');
fprintf(fid, '%s\n', mac_ub);
fclose(fid);
fprintf('Generated task5_upper.mac\n');

fprintf('\nTask 5 LB: [%s]\n', num2str(lb, '%.0f '));
fprintf('Task 5 UB: [%s]\n', num2str(ub, '%.0f '));
