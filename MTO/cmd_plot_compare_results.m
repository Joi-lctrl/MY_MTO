%% cmd_plot_compare_results.m - 读取多任务CEDA结果和单任务GA结果并对比

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

%% ===== 文件配置 =====
multitask_file = 'multitask_ceda_dw_20260417_172201.mat';
ga_file = 'globalga_single_20260419_114910.mat';
tasks_to_plot = [];  % 为空时自动取两个结果文件 active_tasks 的交集

ceda_data = load(multitask_file);
ga_data = load(ga_file);

[ceda_obj_all, ceda_task_fe_all, ceda_best_all, ceda_label] = get_plot_fields(ceda_data);
[ga_obj_all, ga_task_fe_all, ga_best_all, ga_label] = get_plot_fields(ga_data);

common_tasks = intersect(ceda_data.active_tasks, ga_data.active_tasks, 'stable');
if isempty(tasks_to_plot)
    active_tasks = common_tasks;
else
    active_tasks = tasks_to_plot;
end

if isempty(active_tasks)
    error('没有可绘制的任务。请检查 tasks_to_plot 或两个结果文件的 active_tasks。');
end

[missing_in_ceda, ceda_idx] = locate_tasks(active_tasks, ceda_data.active_tasks);
[missing_in_ga, ga_idx] = locate_tasks(active_tasks, ga_data.active_tasks);
if ~isempty(missing_in_ceda)
    error('多任务结果文件缺少任务: [%s]', num2str(missing_in_ceda));
end
if ~isempty(missing_in_ga)
    error('GA结果文件缺少任务: [%s]', num2str(missing_in_ga));
end

ceda_obj = ceda_obj_all(ceda_idx);
ceda_task_fe = ceda_task_fe_all(ceda_idx);
ceda_best = ceda_best_all(:, ceda_idx);
ga_obj = ga_obj_all(ga_idx);
ga_task_fe = ga_task_fe_all(ga_idx);
ga_best = ga_best_all(:, ga_idx);
nTask = numel(active_tasks);

fprintf('加载多任务文件: %s\n', multitask_file);
fprintf('加载GA文件: %s\n', ga_file);
fprintf('任务列表: [%s]\n', num2str(active_tasks));

%% ===== 绘图 =====
colors = [0 0.4470 0.7410; 0.8500 0.3250 0.0980];
markers = {'o', 's'};
fig = figure('Name', 'CEDA-MP-DW vs GA', 'Position', [100 220 1000 420]);

for t = 1:nTask
    ax = subplot(1, nTask, t);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    [ceda_mean, ceda_std] = summarize_curve(ceda_obj{t});
    [ga_mean, ga_std] = summarize_curve(ga_obj{t});

    plot_curve(ax, ceda_task_fe{t}, ceda_mean, ceda_std, colors(1,:), markers{1}, ceda_label);
    plot_curve(ax, ga_task_fe{t}, ga_mean, ga_std, colors(2,:), markers{2}, ga_label);

    valid_vals = [ceda_mean(isfinite(ceda_mean)), ga_mean(isfinite(ga_mean))];
    if ~isempty(valid_vals)
        y_min = min(valid_vals);
        y_max = max(valid_vals);
        if y_min < y_max
            margin = 0.05 * (y_max - y_min);
            ylim(ax, [y_min - margin, y_max + margin]);
        end
    end

    title(ax, sprintf('Task %d', active_tasks(t)), 'FontSize', 13);
    xlabel(ax, 'Task FE', 'FontSize', 11);
    ylabel(ax, 'Feasible Best Objective (kg)', 'FontSize', 11);
    legend(ax, 'Location', 'northeast', 'FontSize', 10);
    set(ax, 'FontSize', 10);
end

sgtitle(fig, sprintf('%s vs %s', ceda_label, ga_label), 'FontSize', 14);

%% ===== 打印最终结果 =====
fprintf('\n===== 最终可行结果 =====\n');
for t = 1:nTask
    fprintf('Task %d:\n', active_tasks(t));
    print_best_summary(ceda_label, ceda_best(:, t));
    print_best_summary(ga_label, ga_best(:, t));
end

%% ======================== Local Functions ================================

function [obj_curves, task_fe_curves, best_vals, label] = get_plot_fields(data)
if isfield(data, 'RawConvergeFeasibleObj')
    obj_curves = data.RawConvergeFeasibleObj{1};
elseif isfield(data, 'ConvergeFeasibleObj')
    obj_curves = data.ConvergeFeasibleObj{1};
else
    obj_curves = data.ConvergeObj{1};
end

if isfield(data, 'RawConvergeTaskFE')
    task_fe_curves = data.RawConvergeTaskFE{1};
elseif isfield(data, 'ConvergeTaskFE')
    task_fe_curves = data.ConvergeTaskFE{1};
else
    error('结果文件缺少 ConvergeTaskFE，无法按任务FE对比。');
end

if isfield(data, 'BestFeasibleObj')
    best_vals = reshape(data.BestFeasibleObj(1, :, :), ...
        [size(data.BestFeasibleObj, 2), size(data.BestFeasibleObj, 3)]);
else
    best_vals = reshape(data.BestObj(1, :, :), ...
        [size(data.BestObj, 2), size(data.BestObj, 3)]);
end

if isfield(data, 'algo_names') && ~isempty(data.algo_names)
    label = data.algo_names{1};
else
    label = 'Algorithm';
end
end

function [missing_tasks, idx] = locate_tasks(target_tasks, available_tasks)
idx = zeros(1, numel(target_tasks));
missing_mask = false(1, numel(target_tasks));
for i = 1:numel(target_tasks)
    pos = find(available_tasks == target_tasks(i), 1, 'first');
    if isempty(pos)
        missing_mask(i) = true;
    else
        idx(i) = pos;
    end
end
missing_tasks = target_tasks(missing_mask);
idx = idx(~missing_mask);
end

function [mean_curve, std_curve] = summarize_curve(curve_data)
mean_curve = mean(curve_data, 1, 'omitnan');
if size(curve_data, 1) > 1
    std_curve = std(curve_data, 0, 1, 'omitnan');
else
    std_curve = zeros(size(mean_curve));
end
end

function plot_curve(ax, task_fe_data, mean_curve, std_curve, color, marker, label)
fe_axis = mean(task_fe_data, 1, 'omitnan');
mk_step = max(1, round(numel(fe_axis) / 8));
mk_idx = 1:mk_step:numel(fe_axis);

plot(ax, fe_axis, mean_curve, '-', 'Color', color, 'LineWidth', 2, 'DisplayName', label);
plot(ax, fe_axis(mk_idx), mean_curve(mk_idx), marker, ...
    'Color', color, 'MarkerSize', 6, 'MarkerFaceColor', color, ...
    'HandleVisibility', 'off');

if any(std_curve > 0)
    fill(ax, [fe_axis, fliplr(fe_axis)], ...
        [mean_curve + std_curve, fliplr(mean_curve - std_curve)], ...
        color, 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
end

function print_best_summary(label, vals)
vals = vals(isfinite(vals));
if isempty(vals)
    fprintf('  %s: feasible obj = NA\n', label);
else
    fprintf('  %s: feasible mean=%.2f, feasible std=%.2f, feasible best=%.2f\n', ...
        label, mean(vals), std(vals), min(vals));
end
end
