%% cmd_plot_interleave_eva.m - 用gen2eva重采样后画收敛图
% 将各算法的收敛数据统一重采样到相同FE刻度，便于公平对比

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));
addpath(genpath(pwd));

%% ===== 加载数据 =====
mat_file = 'ga_single_20260418_071737.mat';
data = load(mat_file);

if isfield(data, 'ConvergeFeasibleObj')
    ConvergeObj = data.ConvergeFeasibleObj;
    using_feasible_obj = true;
else
    ConvergeObj = data.ConvergeObj;
    using_feasible_obj = false;
end
algo_names  = data.algo_names;
active_tasks = data.active_tasks;
maxFE       = data.maxFE;
Reps        = data.Reps;
nAlgo       = numel(algo_names);
nTask       = numel(active_tasks);

% 加载真实FE轴
if isfield(data, 'ConvergeFE')
    ConvergeFE = data.ConvergeFE;
    has_real_fe = true;
else
    ConvergeFE = {};
    has_real_fe = false;
end

if isfield(data, 'ConvergeTaskFE')
    ConvergeTaskFE = data.ConvergeTaskFE;
    has_task_fe = true;
else
    ConvergeTaskFE = {};
    has_task_fe = false;
end

fprintf('加载 %s: %d算法, %d任务, %d次重复, maxFE=%d\n', ...
    mat_file, nAlgo, nTask, Reps, maxFE);
if using_feasible_obj
    fprintf('绘图口径: feasible best objective\n');
else
    fprintf('绘图口径: FP-best objective（旧数据无feasible轨迹）\n');
end

%% ===== gen2eva 重采样 =====
maxGen = 100;  % 重采样到100个等间隔点

ConvergeObj_Eva = cell(nAlgo, 1);
ConvergeTaskFE_Eva = cell(nAlgo, 1);
for a = 1:nAlgo
    ConvergeObj_Eva{a} = cell(nTask, 1);
    ConvergeTaskFE_Eva{a} = cell(nTask, 1);
    for t = 1:nTask
        obj_data = ConvergeObj{a}{t};  % Reps x nPoints
        if isempty(obj_data), continue; end

        nPoints = size(obj_data, 2);
        if has_task_fe && ~isempty(ConvergeTaskFE{a}) && numel(ConvergeTaskFE{a}) >= t ...
                && ~isempty(ConvergeTaskFE{a}{t})
            fe_gen = mean(ConvergeTaskFE{a}{t}, 1, 'omitnan');
        elseif has_real_fe && ~isempty(ConvergeFE{a})
            fe_gen = mean(ConvergeFE{a}, 1, 'omitnan');
        else
            fe_gen = linspace(0, maxFE, nPoints);
        end

        % 对每个rep调用gen2eva
        resampled = zeros(Reps, maxGen);
        for r = 1:Reps
            resampled(r, :) = gen2eva(obj_data(r, :), fe_gen, maxGen);
        end
        ConvergeObj_Eva{a}{t} = resampled;
        ConvergeTaskFE_Eva{a}{t} = linspace(fe_gen(1), fe_gen(end), maxGen);
    end
end

%% ===== 收敛曲线图 =====
colors = lines(nAlgo);
markers = {'o', 's', 'd', '^', 'v'};

fig = figure('Name', '收敛对比 (gen2eva)', 'Position', [100 200 1000 420]);

for t = 1:nTask
    ax = subplot(1, nTask, t);
    hold(ax, 'on'); grid(ax, 'on');
    box(ax, 'on');

    all_min = inf;
    all_max = -inf;

    for a = 1:nAlgo
        obj_data = ConvergeObj_Eva{a}{t};
        if isempty(obj_data), continue; end

        fe_axis_eva = ConvergeTaskFE_Eva{a}{t};
        mean_obj = mean(obj_data, 1, 'omitnan');

        mk = markers{mod(a-1, numel(markers)) + 1};
        mk_step = max(1, round(maxGen / 8));
        mk_idx = 1:mk_step:maxGen;

        plot(ax, fe_axis_eva, mean_obj, '-', ...
            'Color', colors(a,:), 'LineWidth', 2, ...
            'DisplayName', algo_names{a});
        plot(ax, fe_axis_eva(mk_idx), mean_obj(mk_idx), mk, ...
            'Color', colors(a,:), 'MarkerSize', 6, ...
            'MarkerFaceColor', colors(a,:), ...
            'HandleVisibility', 'off');

        if Reps > 1
            std_obj = std(obj_data, 0, 1, 'omitnan');
            fill(ax, [fe_axis_eva, fliplr(fe_axis_eva)], ...
                [mean_obj + std_obj, fliplr(mean_obj - std_obj)], ...
                colors(a,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
        end

        valid = mean_obj(~isnan(mean_obj));
        if ~isempty(valid)
            all_min = min(all_min, min(valid));
            all_max = max(all_max, max(valid));
        end
    end

    if all_min < all_max
        margin = (all_max - all_min) * 0.05;
        ylim(ax, [all_min - margin, all_max + margin]);
    end

    title(ax, sprintf('Task %d', active_tasks(t)), 'FontSize', 13);
    xlabel(ax, 'Task FE', 'FontSize', 11);
    if using_feasible_obj
        ylabel(ax, 'Feasible Best Objective (kg)', 'FontSize', 11);
    else
        ylabel(ax, 'Best Objective (kg)', 'FontSize', 11);
    end
    legend(ax, 'Location', 'northeast', 'FontSize', 10);
    set(ax, 'FontSize', 10);
end

sgtitle(fig, sprintf('%s 收敛对比 gen2eva', strjoin(algo_names, ' vs ')), 'FontSize', 14);

%% ===== 打印最终结果 =====
fprintf('\n===== 最终结果 =====\n');
for t = 1:nTask
    fprintf('Task %d:\n', active_tasks(t));
    for a = 1:nAlgo
        if isfield(data, 'BestFeasibleObj')
            vals = squeeze(data.BestFeasibleObj(a, :, t));
            vals = vals(isfinite(vals));
            if isempty(vals)
                fprintf('  %s: feasible obj = NA\n', algo_names{a});
            else
                fprintf('  %s: feasible mean=%.2f, feasible std=%.2f, feasible best=%.2f\n', ...
                    algo_names{a}, mean(vals), std(vals), min(vals));
            end
        else
            vals = squeeze(data.BestObj(a, :, t));
            fprintf('  %s: mean=%.2f, std=%.2f, best=%.2f\n', ...
                algo_names{a}, mean(vals), std(vals), min(vals));
        end
    end
end
