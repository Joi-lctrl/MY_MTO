%% cmd_interleave.m - CEDA-MP-DW与GA交错运行，实时显示收敛曲线
% 每代实时更新图形，不满意可随时 Ctrl+C 终止

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));
addpath(genpath(pwd));

%% ===== 配置 =====
active_tasks = [8 9];  % 修改为你想跑的任务组合
Reps = 1;              % 总重复次数
maxFE = 2500;          % 每个算法的总FE预算
N = 40;                % 种群大小
Results_Num = 50;      % 收敛曲线记录点数
Global_Seed = 2604;
Disable_Swap = true;   % 若算法含Swap参数，则强制关闭变量交换
EarlyStop_Patience = 10;      % 连续多少代无改进就停止
ShowGenProgress = true;

% 收敛曲线Y轴范围（根据经验设置，避免空白太多）
YLim_Obj = [];                % 留空表示自动范围
YLim_CV  = [0 200];           % 约束违反范围（用第二Y轴时可调）

%% ===== 创建算法和问题对象 =====
prob = Ship_Panel_MTSO();
prob.N = N;
prob.maxFE = maxFE;
prob.Cleanup = true; % Keep only necessary outputs; remove ANSYS temp files.
prob.ActiveTasks = active_tasks;
prob.setTasks();

algo_ga = GA();
algo_ceda_dw = CEDA_MP_DUALCHANNEL_WEIGHTED();

algos = {algo_ceda_dw, algo_ga};
algo_names = {'CEDA-MP-DW', 'GA'};
nAlgo = numel(algos);
nTask = prob.T;

%% ===== 预分配结果存储 =====
ConvergeObj = cell(nAlgo, 1);          % 历史FP-best目标值
ConvergeCV = cell(nAlgo, 1);           % 历史FP-best约束违反
ConvergeFeasibleObj = cell(nAlgo, 1);  % 历史可行最优目标值
ConvergeFE = cell(nAlgo, 1);      % 每算法的总FE轴（兼容旧后处理）
ConvergeTaskFE = cell(nAlgo, 1);  % 每任务的真实FE轴
RawConvergeObj = cell(nAlgo, 1);       % 每代原始目标值
RawConvergeCV = cell(nAlgo, 1);        % 每代原始CV
RawConvergeFeasibleObj = cell(nAlgo, 1); % 每代历史可行最优
RawConvergeTaskFE = cell(nAlgo, 1);    % 每代原始任务FE轴
BestObj = nan(nAlgo, Reps, nTask);
BestFeasibleObj = nan(nAlgo, Reps, nTask);
BestCV = nan(nAlgo, Reps, nTask);
BestDecNorm = cell(nAlgo, Reps, nTask);  % 归一化最优Dec
BestDecReal = cell(nAlgo, Reps, nTask);  % 映射后的实数最优Dec
BestCon = cell(nAlgo, Reps, nTask);      % 最优解约束向量
BestConNames = cell(1, nTask);           % 每个任务的约束名称
PopulationSizeStats = cell(nAlgo, Reps); % 每代各任务种群大小
for a = 1:nAlgo
    ConvergeObj{a} = cell(nTask, 1);
    ConvergeCV{a} = cell(nTask, 1);
    ConvergeFeasibleObj{a} = cell(nTask, 1);
    ConvergeFE{a} = [];
    ConvergeTaskFE{a} = cell(nTask, 1);
    RawConvergeObj{a} = cell(nTask, 1);
    RawConvergeCV{a} = cell(nTask, 1);
    RawConvergeFeasibleObj{a} = cell(nTask, 1);
    RawConvergeTaskFE{a} = cell(nTask, 1);
end
for t = 1:nTask
    BestConNames{t} = get_ship_constraint_names(active_tasks(t));
end

seeds = (0:Reps-1) + Global_Seed;
rep_seeds = seeds;

%% ===== 准备图形 =====
colors = lines(nAlgo);

% 收敛曲线（每代实时更新）
fig1 = figure('Name', 'CEDA-MP-DW vs GA 收敛对比', 'Position', [50 450 900 400]);
ax = gobjects(1, nTask);
h_obj = gobjects(nAlgo, nTask);   % animatedline: 可行最优目标值
h_cv  = gobjects(nAlgo, nTask);   % animatedline: 约束违反
for t = 1:nTask
    ax(t) = subplot(1, nTask, t);
    hold(ax(t), 'on'); grid(ax(t), 'on');
    title(ax(t), sprintf('Task %d (ActiveTask %d)', active_tasks(t), t));
    xlabel(ax(t), 'Task FE');
    yyaxis(ax(t), 'left');
    ylabel(ax(t), 'Feasible Best Obj');
    if ~isempty(YLim_Obj)
        ylim(ax(t), YLim_Obj);
    end
    for a = 1:nAlgo
        h_obj(a,t) = animatedline(ax(t), ...
            'Color', colors(a,:), 'LineWidth', 1.5, ...
            'Marker', '.', 'MarkerSize', 6, ...
            'DisplayName', sprintf('%s Feasible Obj', algo_names{a}));
    end
    yyaxis(ax(t), 'right');
    ylabel(ax(t), 'CV');
    ylim(ax(t), YLim_CV);
    for a = 1:nAlgo
        h_cv(a,t) = animatedline(ax(t), ...
            'Color', colors(a,:), 'LineStyle', '--', 'LineWidth', 1, ...
            'DisplayName', sprintf('%s CV', algo_names{a}));
    end
    legend(ax(t), 'Location', 'northeast');
end
drawnow;

%% ===== 交错运行 =====
fprintf('开始交错运行: %d算法 x %d次重复\n', nAlgo, Reps);

for rep = 1:Reps
    for a = 1:nAlgo
        fprintf('\n--- Rep %d/%d, %s ---\n', rep, Reps, algo_names{a});

        % 清空本轮 animatedline 数据
        for t = 1:nTask
            clearpoints(h_obj(a,t));
            clearpoints(h_cv(a,t));
        end

        rng(seeds(rep));
        prob.setTasks();
        algo = algos{a};
        algo.Result_Num = Results_Num;
        algo.Save_Dec = false;
        if Disable_Swap && isprop(algo, 'Swap')
            % In this codebase, setting Swap=1 disables variable swapping.
            algo.Swap = 1;
        end
        algo.reset();

        % 早停状态（用containers.Map实现引用传递）
        es = containers.Map();
        es('prev_best') = inf(1, nTask);
        es('stall_count') = 0;
        es('patience') = EarlyStop_Patience;
        es('triggered') = false;
        es('last_gen_printed') = 0;

        % 绑定每代实时更新回调（含早停检查）
        cur_a = a;
        algo.Check_Status_Fn = @() live_update_with_earlystop( ...
            algo, cur_a, algo_names{a}, nTask, h_obj, h_cv, active_tasks, fig1, es, ShowGenProgress);

        algo.run(prob);
        PopulationSizeStats{a, rep} = algo.PopSize_Gen;

        if es('triggered')
            fprintf('  [早停] %s 停止（连续%d代无改进）\n', ...
                algo_names{a}, es('patience'));
        end

        % 保存最终最优个体（归一化Dec与实值Dec）
        for t = 1:nTask
            if ~isempty(algo.Best) && numel(algo.Best) >= t && ~isempty(algo.Best{t})
                d = prob.D(t);
                dec_norm = algo.Best{t}.Dec(1:d);
                BestDecNorm{a, rep, t} = dec_norm;
                BestDecReal{a, rep, t} = prob.Lb{t} + dec_norm .* (prob.Ub{t} - prob.Lb{t});
                BestCon{a, rep, t} = algo.Best{t}.Con;
                BestCV(a, rep, t) = algo.Best{t}.CV;
            end
        end

        % 保存总FE轴（兼容旧后处理）
        fe_gen = algo.FE_Gen;
        if ~isempty(fe_gen)
            nPoints = Results_Num;
            fe_axis_real = linspace(fe_gen(1), fe_gen(end), nPoints);
            if isempty(ConvergeFE{a})
                ConvergeFE{a} = nan(Reps, nPoints);
            end
            ConvergeFE{a}(rep, :) = fe_axis_real;
        end

        for t = 1:nTask
            task_fe_gen = [];
            if ~isempty(algo.TaskFE_Gen) && size(algo.TaskFE_Gen, 2) >= t
                task_fe_gen = algo.TaskFE_Gen(:, t)';
            end

            raw_valid_idx = find(task_fe_gen > 0);
            if isempty(raw_valid_idx)
                raw_valid_idx = 1:numel(algo.FE_Gen);
                raw_task_axis = algo.FE_Gen(raw_valid_idx);
            else
                raw_task_axis = task_fe_gen(raw_valid_idx);
            end
            raw_obj_hist = [algo.Result(t, raw_valid_idx).Obj];
            raw_cv_hist = [algo.Result(t, raw_valid_idx).CV];
            raw_feasible_obj_hist = build_feasible_best_obj(raw_obj_hist, raw_cv_hist);

            RawConvergeObj{a}{t} = assign_history_row(RawConvergeObj{a}{t}, rep, raw_obj_hist);
            RawConvergeCV{a}{t} = assign_history_row(RawConvergeCV{a}{t}, rep, raw_cv_hist);
            RawConvergeFeasibleObj{a}{t} = assign_history_row(RawConvergeFeasibleObj{a}{t}, rep, raw_feasible_obj_hist);
            RawConvergeTaskFE{a}{t} = assign_history_row(RawConvergeTaskFE{a}{t}, rep, raw_task_axis);

            valid_idx = find(task_fe_gen > 0);
            if ~isempty(valid_idx)
                tmp_task = gen2eva(algo.Result(t, valid_idx), task_fe_gen(valid_idx), Results_Num);
                task_axis = linspace(task_fe_gen(valid_idx(1)), task_fe_gen(valid_idx(end)), size(tmp_task, 2));
            else
                tmp_task = gen2eva(algo.Result(t, :), algo.FE_Gen, Results_Num);
                task_axis = linspace(algo.FE_Gen(1), algo.FE_Gen(end), size(tmp_task, 2));
            end

            obj_hist = [tmp_task.Obj];
            cv_hist = [tmp_task.CV];
            feasible_obj_hist = build_feasible_best_obj(obj_hist, cv_hist);
            if isempty(ConvergeObj{a}{t})
                ConvergeObj{a}{t} = nan(Reps, numel(obj_hist));
            end
            ConvergeObj{a}{t}(rep, :) = obj_hist;
            if isempty(ConvergeCV{a}{t})
                ConvergeCV{a}{t} = nan(Reps, numel(cv_hist));
            end
            ConvergeCV{a}{t}(rep, :) = cv_hist;
            if isempty(ConvergeFeasibleObj{a}{t})
                ConvergeFeasibleObj{a}{t} = nan(Reps, numel(feasible_obj_hist));
            end
            ConvergeFeasibleObj{a}{t}(rep, :) = feasible_obj_hist;
            if isempty(ConvergeTaskFE{a}{t})
                ConvergeTaskFE{a}{t} = nan(Reps, numel(task_axis));
            end
            ConvergeTaskFE{a}{t}(rep, :) = task_axis;
            BestObj(a, rep, t) = obj_hist(end);
            if any(isfinite(feasible_obj_hist))
                BestFeasibleObj(a, rep, t) = feasible_obj_hist(find(isfinite(feasible_obj_hist), 1, 'last'));
            end
        end

        drawnow;

        fprintf('  %s Rep%d 完成: ', algo_names{a}, rep);
        for t = 1:nTask
            feasible_val = BestFeasibleObj(a, rep, t);
            if isfinite(feasible_val)
                fprintf('Task%d=%.2f(feas)  ', active_tasks(t), feasible_val);
            else
                fprintf('Task%d=NA(feas)  ', active_tasks(t));
            end
        end
        fprintf('\n');
    end
end

%% ===== 汇总 =====
fprintf('\n========== 最终结果 ==========\n');
for t = 1:nTask
    fprintf('Task %d (ActiveTask %d):\n', t, active_tasks(t));
    for a = 1:nAlgo
        vals = BestObj(a, :, t);
        feas_vals = BestFeasibleObj(a, :, t);
        feas_mask = isfinite(feas_vals);
        if any(feas_mask)
            feas_mean = mean(feas_vals(feas_mask));
            feas_std = std(feas_vals(feas_mask));
            feas_best = min(feas_vals(feas_mask));
            feas_str = num2str(feas_vals(feas_mask), '%.2f ');
        else
            feas_mean = nan;
            feas_std = nan;
            feas_best = nan;
            feas_str = 'NA';
        end
        fprintf('  %s: mean=%.2f, std=%.2f, best=%.2f, feasible_mean=%.2f, feasible_std=%.2f, feasible_best=%.2f, [%s]\n', ...
            algo_names{a}, mean(vals), std(vals), min(vals), ...
            feas_mean, feas_std, feas_best, feas_str);
    end
end

%% ===== 保存 =====
save_name = sprintf('interleave_%s.mat', datestr(now, 'yyyymmdd_HHMMSS'));
save(save_name, 'BestObj', 'BestFeasibleObj', 'BestCV', 'BestDecNorm', 'BestDecReal', 'BestCon', 'BestConNames', ...
    'ConvergeObj', 'ConvergeCV', 'ConvergeFeasibleObj', 'ConvergeFE', 'ConvergeTaskFE', 'algo_names', 'active_tasks', ...
    'RawConvergeObj', 'RawConvergeCV', 'RawConvergeFeasibleObj', 'RawConvergeTaskFE', ...
    'Reps', 'maxFE', 'Disable_Swap', 'Global_Seed', 'rep_seeds', ...
    'PopulationSizeStats');
fprintf('结果已保存到 %s\n', save_name);

%% ======================== Local Functions ================================

function live_update_with_earlystop(algo, algo_idx, algo_name, nTask, h_obj, h_cv, active_tasks, fig1, es, show_gen_progress)
% 每代由 Algorithm.notTerminated 调用，实时更新图形 + 早停检查
if ~isvalid(fig1), return; end

total_fe = algo.FE;
cur_best = inf(1, nTask);
task_fe_vals = nan(1, nTask);
task_cv_vals = nan(1, nTask);
for t = 1:nTask
    if ~isempty(algo.Best) && numel(algo.Best) >= t && ~isempty(algo.Best{t})
        task_fe = total_fe;
        if isprop(algo, 'TaskFE') && ~isempty(algo.TaskFE) && numel(algo.TaskFE) >= t ...
                && isfinite(algo.TaskFE(t)) && algo.TaskFE(t) > 0
            task_fe = algo.TaskFE(t);
        end
        feasible_obj = nan;
        if isfield(algo.Best{t}, 'CV') && algo.Best{t}.CV <= 0
            feasible_obj = algo.Best{t}.Obj;
        end
        addpoints(h_obj(algo_idx, t), task_fe, feasible_obj);
        addpoints(h_cv(algo_idx, t),  task_fe, algo.Best{t}.CV);
        cur_best(t) = algo.Best{t}.Obj;
        task_fe_vals(t) = task_fe;
        task_cv_vals(t) = algo.Best{t}.CV;
    end
end

drawnow('limitrate');

current_gen = max(1, algo.Gen - 1);
if show_gen_progress && current_gen > es('last_gen_printed')
    msg = sprintf('    [%s] Gen %d, FE=%d', algo_name, current_gen, round(total_fe));
    for t = 1:nTask
        if isfinite(cur_best(t))
            msg = sprintf('%s | Task %d: FE=%d, BestObj=%.6f, BestCV=%.6f', ...
                msg, active_tasks(t), round(task_fe_vals(t)), cur_best(t), task_cv_vals(t));
        end
    end
    fprintf('%s\n', msg);
    es('last_gen_printed') = current_gen;
end

% 早停检查：连续patience代无改进则强制终止
prev_best = es('prev_best');
improved = any(cur_best < prev_best - 1e-6);
if improved
    es('stall_count') = 0;
    es('prev_best') = min(cur_best, prev_best);
else
    es('stall_count') = es('stall_count') + 1;
end
if es('stall_count') >= es('patience')
    es('triggered') = true;
    % 强制FE超过maxFE，让notTerminated返回false
    algo.FE = inf;
end
end

function feasible_hist = build_feasible_best_obj(obj_hist, cv_hist)
feasible_hist = nan(size(obj_hist));
best_feasible = inf;
for i = 1:numel(obj_hist)
    if cv_hist(i) <= 0
        best_feasible = min(best_feasible, obj_hist(i));
    end
    if isfinite(best_feasible)
        feasible_hist(i) = best_feasible;
    end
end
end

function hist_mat = assign_history_row(hist_mat, rep, row_vals)
row_vals = row_vals(:)';
need_cols = numel(row_vals);
if isempty(hist_mat)
    hist_mat = nan(rep, need_cols);
elseif size(hist_mat, 2) < need_cols
    hist_mat(:, end+1:need_cols) = nan;
end
if size(hist_mat, 1) < rep
    hist_mat(end+1:rep, :) = nan;
end
hist_mat(rep, 1:need_cols) = row_vals;
end
