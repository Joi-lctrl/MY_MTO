%% cmd_task3_single_var_sensitivity.m
% Task 3 单变量敏感性扫描：
% 固定其余变量为中值，只扫描一个变量，记录目标值和约束响应。

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

repo_root = fileparts(pwd);
addpath(genpath(pwd));
addpath(genpath(fullfile(repo_root, 'APDL')));

%% ===== 配置 =====
task_id = 3;
scan_points = 11;          % 每个变量的扫描点数
variables_to_scan = [];    % 为空表示扫描全部变量
reference_mode = 'project_mid'; % 'mid' 或 'project_mid'
apdl_nproc = 4;
cleanup = true;
reuse_mesh = true;
save_csv = true;
save_mat = true;

%% ===== 初始化 =====
ship_prob = Ship_Panel_Problem();
task = ship_prob.Tasks(task_id);
[lb, x_mid, ub] = ship_prob.get_design_space(task_id);
x_ref = build_reference_point(x_mid, lb, ub, task, reference_mode);
var_names = build_group_var_names(task);
con_names = get_ship_constraint_names(task_id);

if isempty(variables_to_scan)
    variables_to_scan = 1:numel(lb);
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
out_dir = fullfile(repo_root, 'APDLRESULTS_MTO', ...
    sprintf('task%d_single_var_sensitivity_%s', task_id, timestamp));
if exist(out_dir, 'dir') ~= 7
    mkdir(out_dir);
end

cfg = struct();
cfg.apdl_dir = fullfile(repo_root, 'APDL');
cfg.n_proc = apdl_nproc;
cfg.cleanup = cleanup;
cfg.reuse_mesh = reuse_mesh;
cfg.work_dir = fullfile(out_dir, sprintf('ansys_task%d_scan', task_id));

all_rows = table();
summary_rows = table();
scan_results = struct();

fprintf('===== Task %d 单变量敏感性扫描 =====\n', task_id);
fprintf('输出目录: %s\n', out_dir);
fprintf('固定其余变量为中值 x_mid = [%s]\n', num2str(x_mid, '%.4f '));
fprintf('实际扫描基准 x_ref (%s) = [%s]\n', reference_mode, num2str(x_ref, '%.4f '));

%% ===== 逐变量扫描 =====
for ii = 1:numel(variables_to_scan)
    var_idx = variables_to_scan(ii);
    var_name = var_names{var_idx};
    scan_values = linspace(lb(var_idx), ub(var_idx), scan_points)';

    fprintf('\n[%d/%d] 扫描 x%d (%s): %.4f -> %.4f\n', ...
        ii, numel(variables_to_scan), var_idx, var_name, lb(var_idx), ub(var_idx));

    T = table();
    T.var_index = repmat(var_idx, scan_points, 1);
    T.var_name = repmat({var_name}, scan_points, 1);
    T.scan_step = (1:scan_points)';
    T.scan_value = scan_values;
    T.lb = repmat(lb(var_idx), scan_points, 1);
    T.mid_value = repmat(x_mid(var_idx), scan_points, 1);
    T.reference_value = repmat(x_ref(var_idx), scan_points, 1);
    T.ub = repmat(ub(var_idx), scan_points, 1);
    T.objective_kg = nan(scan_points, 1);
    T.max_bend = nan(scan_points, 1);
    T.max_shear = nan(scan_points, 1);
    T.cv = nan(scan_points, 1);
    T.feasible = false(scan_points, 1);
    T.error_flag = false(scan_points, 1);

    con_mat = nan(scan_points, numel(con_names));
    valid_con_names = cell(1, numel(con_names));
    for cj = 1:numel(con_names)
        valid_con_names{cj} = matlab.lang.makeValidName(con_names{cj});
    end

    for sj = 1:scan_points
        x = x_ref;
        x(var_idx) = scan_values(sj);

        [obj, con, extra] = run_ansys_eval(x, task_id, cfg);
        cv = sum(max(0, con));

        T.objective_kg(sj) = obj;
        T.max_bend(sj) = extra.max_bend;
        T.max_shear(sj) = extra.max_shear;
        T.cv(sj) = cv;
        T.feasible(sj) = all(con <= 0);
        T.error_flag(sj) = extra.error;
        con_mat(sj, :) = con(:).';
    end

    for cj = 1:numel(con_names)
        T.(valid_con_names{cj}) = con_mat(:, cj);
    end

    feasible_mask = T.feasible & ~T.error_flag;
    if any(feasible_mask)
        feasible_min = min(T.scan_value(feasible_mask));
        feasible_max = max(T.scan_value(feasible_mask));
        best_feasible_obj = min(T.objective_kg(feasible_mask));
    else
        feasible_min = NaN;
        feasible_max = NaN;
        best_feasible_obj = NaN;
    end

    summary_row = table( ...
        var_idx, {var_name}, lb(var_idx), x_ref(var_idx), ub(var_idx), ...
        sum(feasible_mask), feasible_min, feasible_max, best_feasible_obj, ...
        min(T.max_bend), max(T.max_bend), min(T.max_shear), max(T.max_shear), ...
        'VariableNames', {'var_index', 'var_name', 'lb', 'reference_value', 'ub', ...
        'n_feasible', 'feasible_min', 'feasible_max', 'best_feasible_obj', ...
        'min_bend', 'max_bend', 'min_shear', 'max_shear'});

    if isempty(summary_rows)
        summary_rows = summary_row;
    else
        summary_rows = [summary_rows; summary_row]; %#ok<AGROW>
    end

    if isempty(all_rows)
        all_rows = T;
    else
        all_rows = [all_rows; T]; %#ok<AGROW>
    end

    scan_results(ii).var_index = var_idx; %#ok<SAGROW>
    scan_results(ii).var_name = var_name; %#ok<SAGROW>
    scan_results(ii).table = T; %#ok<SAGROW>

    if save_csv
        csv_file = fullfile(out_dir, sprintf('scan_%02d_%s.csv', var_idx, var_name));
        writetable(T, csv_file);
    end

    fprintf('  可行点数: %d/%d', sum(feasible_mask), scan_points);
    if any(feasible_mask)
        fprintf(', 可行扫描范围: [%.4f, %.4f], 最佳可行质量: %.4f kg\n', ...
            feasible_min, feasible_max, best_feasible_obj);
    else
        fprintf(', 当前扫描点上无可行解\n');
    end
end

%% ===== 保存总结果 =====
if save_csv
    writetable(summary_rows, fullfile(out_dir, 'summary.csv'));
    writetable(all_rows, fullfile(out_dir, 'all_scans.csv'));
end

if save_mat
    save(fullfile(out_dir, 'task3_single_var_sensitivity.mat'), ...
        'task_id', 'task', 'lb', 'x_mid', 'x_ref', 'ub', 'var_names', 'con_names', ...
        'variables_to_scan', 'scan_points', 'scan_results', ...
        'summary_rows', 'all_rows');
end

fprintf('\n===== 扫描完成 =====\n');
fprintf('summary.csv / all_scans.csv / task3_single_var_sensitivity.mat 已输出到:\n%s\n', out_dir);

function x_ref = build_reference_point(x_mid, lb, ub, task, reference_mode)
if strcmpi(reference_mode, 'mid')
    x_ref = x_mid;
    return;
end

if ~strcmpi(reference_mode, 'project_mid')
    error('Unsupported reference_mode: %s', reference_mode);
end

x_ref = x_mid;

lambda_web_long = resolve_slenderness_limit(task, 'lambda_web_long', 50);
lambda_flange_long = resolve_slenderness_limit(task, 'lambda_flange_long', 10);
lambda_web_rib = resolve_slenderness_limit(task, 'lambda_web_rib', 50);
lambda_flange_rib = resolve_slenderness_limit(task, 'lambda_flange_rib', 10);

group_count = task.long_group_count + task.rib_group_count;
for g = 1:group_count
    idx0 = 4 * (g - 1) + 1;
    h_web = x_ref(idx0);
    b_bot = x_ref(idx0 + 2);

    if g <= task.long_group_count
        lambda_web_max = lambda_web_long;
        lambda_flange_max = lambda_flange_long;
    else
        lambda_web_max = lambda_web_rib;
        lambda_flange_max = lambda_flange_rib;
    end

    min_t_web = h_web / lambda_web_max;
    min_t_bot = b_bot / lambda_flange_max;

    x_ref(idx0 + 1) = min(max(max(x_ref(idx0 + 1), min_t_web), lb(idx0 + 1)), ub(idx0 + 1));
    x_ref(idx0 + 3) = min(max(max(x_ref(idx0 + 3), min_t_bot), lb(idx0 + 3)), ub(idx0 + 3));
end
end

function value = resolve_slenderness_limit(task, field_name, default_value)
value = default_value;
if isfield(task, field_name)
    value = task.(field_name);
end
end

function names = build_group_var_names(task)
names = cell(1, 4 * (task.long_group_count + task.rib_group_count));
idx = 1;

for g = 1:task.long_group_count
    names{idx} = sprintf('h_web_L%d', g); idx = idx + 1;
    names{idx} = sprintf('t_web_L%d', g); idx = idx + 1;
    names{idx} = sprintf('b_bot_L%d', g); idx = idx + 1;
    names{idx} = sprintf('t_bot_L%d', g); idx = idx + 1;
end

for g = 1:task.rib_group_count
    names{idx} = sprintf('h_web_R%d', g); idx = idx + 1;
    names{idx} = sprintf('t_web_R%d', g); idx = idx + 1;
    names{idx} = sprintf('b_bot_R%d', g); idx = idx + 1;
    names{idx} = sprintf('t_bot_R%d', g); idx = idx + 1;
end
end
