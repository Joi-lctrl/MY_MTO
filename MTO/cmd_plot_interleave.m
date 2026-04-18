%% cmd_plot_interleave.m - 根据已保存的interleave结果画收敛图
% 纵轴根据实际数据范围自动缩放，充分利用整个Y轴

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));

%% ===== 加载数据 =====
mat_file = 'multitask_ceda_dw_20260417_172201.mat';
data = load(mat_file);

if isfield(data, 'RawConvergeFeasibleObj')
    ConvergeObj = data.RawConvergeFeasibleObj;
    using_feasible_obj = true;
elseif isfield(data, 'ConvergeFeasibleObj')
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

% 加载真实FE轴（兼容旧数据）
if isfield(data, 'ConvergeFE')
    ConvergeFE = data.ConvergeFE;
    has_real_fe = true;
else
    ConvergeFE = {};
    has_real_fe = false;
end

if isfield(data, 'RawConvergeTaskFE')
    ConvergeTaskFE = data.RawConvergeTaskFE;
    has_task_fe = true;
elseif isfield(data, 'ConvergeTaskFE')
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

%% ===== 收敛曲线图 =====
colors = lines(nAlgo);
markers = {'o', 's', 'd', '^', 'v'};

fig = figure('Name', '收敛对比', 'Position', [100 200 1000 420]);

for t = 1:nTask
    ax = subplot(1, nTask, t);
    hold(ax, 'on'); grid(ax, 'on');
    box(ax, 'on');

    all_min = inf;
    all_max = -inf;

    for a = 1:nAlgo
        obj_data = ConvergeObj{a}{t};  % Reps x nPoints
        if isempty(obj_data), continue; end

        nPoints = size(obj_data, 2);
        % 优先使用任务FE轴，旧数据则回退到总FE轴
        if has_task_fe && ~isempty(ConvergeTaskFE{a}) && numel(ConvergeTaskFE{a}) >= t ...
                && ~isempty(ConvergeTaskFE{a}{t})
            fe_axis = mean(ConvergeTaskFE{a}{t}, 1, 'omitnan');
        elseif has_real_fe && ~isempty(ConvergeFE{a})
            fe_axis = mean(ConvergeFE{a}, 1, 'omitnan');
        else
            fe_axis = linspace(0, maxFE, nPoints);
        end

        % 均值曲线
        mean_obj = mean(obj_data, 1, 'omitnan');

        % 画均值线
        mk = markers{mod(a-1, numel(markers)) + 1};
        mk_step = max(1, round(nPoints / 8));
        mk_idx = 1:mk_step:nPoints;

        plot(ax, fe_axis, mean_obj, '-', ...
            'Color', colors(a,:), 'LineWidth', 2, ...
            'DisplayName', algo_names{a});
        plot(ax, fe_axis(mk_idx), mean_obj(mk_idx), mk, ...
            'Color', colors(a,:), 'MarkerSize', 6, ...
            'MarkerFaceColor', colors(a,:), ...
            'HandleVisibility', 'off');

        % 如果多次重复，画标准差带
        if Reps > 1
            std_obj = std(obj_data, 0, 1, 'omitnan');
            fill(ax, [fe_axis, fliplr(fe_axis)], ...
                [mean_obj + std_obj, fliplr(mean_obj - std_obj)], ...
                colors(a,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
        end

        % 追踪最值
        valid = mean_obj(~isnan(mean_obj));
        if ~isempty(valid)
            all_min = min(all_min, min(valid));
            all_max = max(all_max, max(valid));
        end
    end

    % 自动Y轴：在数据范围基础上留5%边距
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

sgtitle(fig, sprintf('%s 收敛对比', strjoin(algo_names, ' vs ')), 'FontSize', 14);

%% ===== RMP 图 =====
if isfield(data, 'RMPTraceAll') && ~isempty(data.RMPTraceAll)
    has_rmp = false;
    for rep = 1:Reps
        if ~isempty(data.RMPTraceAll{rep})
            has_rmp = true;
            break;
        end
    end

    if has_rmp
        fig2 = figure('Name', 'RMP变化', 'Position', [100 50 600 350]);
        ax_rmp = axes(fig2);
        hold(ax_rmp, 'on'); grid(ax_rmp, 'on');
        box(ax_rmp, 'on');
        rmp_colors = lines(nTask * (nTask - 1) / 2);

        for rep = 1:Reps
            trace = data.RMPTraceAll{rep};
            if isempty(trace), continue; end

            nGen = numel(trace);
            pair_idx = 0;
            for ti = 1:nTask
                for tj = (ti+1):nTask
                    pair_idx = pair_idx + 1;
                    rmp_vals = zeros(1, nGen);
                    for g = 1:nGen
                        rmp_vals(g) = trace{g}(ti, tj);
                    end
                    plot(ax_rmp, 1:nGen, rmp_vals, '-', ...
                        'Color', rmp_colors(pair_idx,:), 'LineWidth', 1.5, ...
                        'DisplayName', sprintf('Rep%d RMP(T%d,T%d)', rep, active_tasks(ti), active_tasks(tj)));
                end
            end
        end

        title(ax_rmp, 'MFEA-II RMP 变化', 'FontSize', 13);
        xlabel(ax_rmp, 'Generation', 'FontSize', 11);
        ylabel(ax_rmp, 'RMP', 'FontSize', 11);
        ylim(ax_rmp, [0 1]);
        legend(ax_rmp, 'Location', 'best', 'FontSize', 10);
        set(ax_rmp, 'FontSize', 10);
    end
end

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
