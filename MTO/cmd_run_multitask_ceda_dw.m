%% cmd_run_multitask_ceda_dw.m - 仅运行CEDA-MP-DW多任务实验并保存结果

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));
addpath(genpath(pwd));

%% ===== 配置 =====
active_tasks = [3 4];
Reps = 1;
maxFE = 12000;
N = 100;
Results_Num = 50;
Global_Seed = 2604;
Disable_Swap = true;
EarlyStop_Patience = 20;
ShowGenProgress = true;

YLim_Obj = [];
YLim_CV  = [0 200];

%% ===== 创建算法和问题对象 =====
prob = Ship_Panel_MTSO();
prob.N = N;
prob.maxFE = maxFE;
prob.Cleanup = true;
prob.ActiveTasks = active_tasks;
prob.setTasks();

algo = CEDA_MP_DUALCHANNEL_WEIGHTED();
algo_names = {'CEDA-MP-DW'};
nAlgo = 1;
nTask = prob.T;

%% ===== 预分配结果存储 =====
ConvergeObj = cell(nAlgo, 1);
ConvergeCV = cell(nAlgo, 1);
ConvergeFeasibleObj = cell(nAlgo, 1);
ConvergeFE = cell(nAlgo, 1);
ConvergeTaskFE = cell(nAlgo, 1);
RawConvergeObj = cell(nAlgo, 1);
RawConvergeCV = cell(nAlgo, 1);
RawConvergeFeasibleObj = cell(nAlgo, 1);
RawConvergeTaskFE = cell(nAlgo, 1);
BestObj = nan(nAlgo, Reps, nTask);
BestFeasibleObj = nan(nAlgo, Reps, nTask);
BestCV = nan(nAlgo, Reps, nTask);
BestDecNorm = cell(nAlgo, Reps, nTask);
BestDecReal = cell(nAlgo, Reps, nTask);
BestCon = cell(nAlgo, Reps, nTask);
BestConNames = cell(1, nTask);
PopulationSizeStats = cell(nAlgo, Reps);
ConvergeObj{1} = cell(nTask, 1);
ConvergeCV{1} = cell(nTask, 1);
ConvergeFeasibleObj{1} = cell(nTask, 1);
ConvergeTaskFE{1} = cell(nTask, 1);
RawConvergeObj{1} = cell(nTask, 1);
RawConvergeCV{1} = cell(nTask, 1);
RawConvergeFeasibleObj{1} = cell(nTask, 1);
RawConvergeTaskFE{1} = cell(nTask, 1);
for t = 1:nTask
    ConvergeObj{1}{t} = [];
    ConvergeCV{1}{t} = [];
    ConvergeFeasibleObj{1}{t} = [];
    ConvergeTaskFE{1}{t} = [];
    RawConvergeObj{1}{t} = [];
    RawConvergeCV{1}{t} = [];
    RawConvergeFeasibleObj{1}{t} = [];
    RawConvergeTaskFE{1}{t} = [];
end
ConvergeFE{1} = [];
for t = 1:nTask
    BestConNames{t} = get_ship_constraint_names(active_tasks(t));
end

seeds = (0:Reps-1) + Global_Seed;
rep_seeds = seeds;

%% ===== 图形 =====
fig1 = figure('Name', 'CEDA-MP-DW 多任务收敛', 'Position', [60 450 900 400]);
ax = gobjects(1, nTask);
h_obj = gobjects(1, nTask);
h_cv = gobjects(1, nTask);
for t = 1:nTask
    ax(t) = subplot(1, nTask, t);
    hold(ax(t), 'on'); grid(ax(t), 'on');
    title(ax(t), sprintf('Task %d', active_tasks(t)));
    xlabel(ax(t), 'Task FE');
    yyaxis(ax(t), 'left');
    ylabel(ax(t), 'Feasible Best Obj');
    if ~isempty(YLim_Obj)
        ylim(ax(t), YLim_Obj);
    end
    h_obj(1, t) = animatedline(ax(t), ...
        'Color', [0 0.4470 0.7410], 'LineWidth', 1.5, ...
        'Marker', '.', 'MarkerSize', 6, ...
        'DisplayName', 'CEDA-MP-DW Feasible Obj');
    yyaxis(ax(t), 'right');
    ylabel(ax(t), 'CV');
    ylim(ax(t), YLim_CV);
    h_cv(1, t) = animatedline(ax(t), ...
        'Color', [0 0.4470 0.7410], 'LineStyle', '--', 'LineWidth', 1, ...
        'DisplayName', 'CEDA-MP-DW CV');
    legend(ax(t), 'Location', 'northeast');
end
drawnow;

%% ===== 运行 =====
fprintf('开始运行 CEDA-MP-DW 多任务实验: Reps=%d, Tasks=[%s]\n', ...
    Reps, num2str(active_tasks));

for rep = 1:Reps
    fprintf('\n--- Rep %d/%d, CEDA-MP-DW ---\n', rep, Reps);

    for t = 1:nTask
        clearpoints(h_obj(1, t));
        clearpoints(h_cv(1, t));
    end

    rng(seeds(rep));
    prob.setTasks();
    algo.Result_Num = Results_Num;
    algo.Save_Dec = false;
    if Disable_Swap && isprop(algo, 'Swap')
        algo.Swap = 1;
    end
    algo.reset();

    es = containers.Map();
    es('prev_best') = inf(1, nTask);
    es('prev_cv') = inf(1, nTask);
    es('prev_has_feasible') = false(1, nTask);
    es('stall_count') = 0;
    es('patience') = EarlyStop_Patience;
    es('triggered') = false;
    es('last_gen_printed') = 0;

    algo.Check_Status_Fn = @() live_update_with_earlystop( ...
        algo, active_tasks, nTask, h_obj, h_cv, fig1, es, ShowGenProgress);

    algo.run(prob);
    PopulationSizeStats{1, rep} = algo.PopSize_Gen;

    if es('triggered')
        fprintf('  [早停] CEDA-MP-DW 停止（连续%d代无改进）\n', es('patience'));
    end

    for t = 1:nTask
        if ~isempty(algo.Best) && numel(algo.Best) >= t && ~isempty(algo.Best{t})
            d = prob.D(t);
            dec_norm = algo.Best{t}.Dec(1:d);
            BestDecNorm{1, rep, t} = dec_norm;
            BestDecReal{1, rep, t} = prob.Lb{t} + dec_norm .* (prob.Ub{t} - prob.Lb{t});
            BestCon{1, rep, t} = algo.Best{t}.Con;
            BestCV(1, rep, t) = algo.Best{t}.CV;
        end
    end

    fe_gen = algo.FE_Gen;
    if ~isempty(fe_gen)
        fe_axis_real = linspace(fe_gen(1), fe_gen(end), Results_Num);
        if isempty(ConvergeFE{1})
            ConvergeFE{1} = nan(Reps, Results_Num);
        end
        ConvergeFE{1}(rep, :) = fe_axis_real;
    end

    for t = 1:nTask
        task_fe_gen = [];
        if ~isempty(algo.TaskFE_Gen) && size(algo.TaskFE_Gen, 2) >= t
            task_fe_gen = algo.TaskFE_Gen(:, t)';
        end
        if isempty(task_fe_gen)
            task_fe_gen = algo.FE_Gen;
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

        RawConvergeObj{1}{t} = assign_history_row(RawConvergeObj{1}{t}, rep, raw_obj_hist);
        RawConvergeCV{1}{t} = assign_history_row(RawConvergeCV{1}{t}, rep, raw_cv_hist);
        RawConvergeFeasibleObj{1}{t} = assign_history_row(RawConvergeFeasibleObj{1}{t}, rep, raw_feasible_obj_hist);
        RawConvergeTaskFE{1}{t} = assign_history_row(RawConvergeTaskFE{1}{t}, rep, raw_task_axis);

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

        if isempty(ConvergeObj{1}{t})
            ConvergeObj{1}{t} = nan(Reps, numel(obj_hist));
        end
        if isempty(ConvergeCV{1}{t})
            ConvergeCV{1}{t} = nan(Reps, numel(cv_hist));
        end
        if isempty(ConvergeFeasibleObj{1}{t})
            ConvergeFeasibleObj{1}{t} = nan(Reps, numel(feasible_obj_hist));
        end
        if isempty(ConvergeTaskFE{1}{t})
            ConvergeTaskFE{1}{t} = nan(Reps, numel(task_axis));
        end

        ConvergeObj{1}{t}(rep, :) = obj_hist;
        ConvergeCV{1}{t}(rep, :) = cv_hist;
        ConvergeFeasibleObj{1}{t}(rep, :) = feasible_obj_hist;
        ConvergeTaskFE{1}{t}(rep, :) = task_axis;
        BestObj(1, rep, t) = obj_hist(end);
        if any(isfinite(feasible_obj_hist))
            BestFeasibleObj(1, rep, t) = feasible_obj_hist(find(isfinite(feasible_obj_hist), 1, 'last'));
        end
    end

    fprintf('  CEDA-MP-DW Rep%d 完成: ', rep);
    for t = 1:nTask
        feasible_val = BestFeasibleObj(1, rep, t);
        if isfinite(feasible_val)
            fprintf('Task%d=%.2f(feas)  ', active_tasks(t), feasible_val);
        else
            fprintf('Task%d=NA(feas)  ', active_tasks(t));
        end
    end
    fprintf('\n');
end

%% ===== 保存 =====
save_name = sprintf('multitask_ceda_dw_%s.mat', datestr(now, 'yyyymmdd_HHMMSS'));
save(save_name, 'BestObj', 'BestFeasibleObj', 'BestCV', 'BestDecNorm', 'BestDecReal', 'BestCon', 'BestConNames', ...
    'ConvergeObj', 'ConvergeCV', 'ConvergeFeasibleObj', 'ConvergeFE', 'ConvergeTaskFE', ...
    'RawConvergeObj', 'RawConvergeCV', 'RawConvergeFeasibleObj', 'RawConvergeTaskFE', ...
    'algo_names', 'active_tasks', 'Reps', 'maxFE', 'Disable_Swap', 'Global_Seed', ...
    'rep_seeds', 'PopulationSizeStats');
fprintf('结果已保存到 %s\n', save_name);

%% ======================== Local Functions ================================

function live_update_with_earlystop(algo, active_tasks, nTask, h_obj, h_cv, fig1, es, show_gen_progress)
if ~isvalid(fig1), return; end

total_fe = algo.FE;
cur_best = inf(1, nTask);
cur_cv = inf(1, nTask);
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
        addpoints(h_obj(1, t), task_fe, feasible_obj);
        addpoints(h_cv(1, t), task_fe, algo.Best{t}.CV);
        cur_best(t) = algo.Best{t}.Obj;
        cur_cv(t) = algo.Best{t}.CV;
        task_fe_vals(t) = task_fe;
        task_cv_vals(t) = algo.Best{t}.CV;
    end
end

drawnow('limitrate');

current_gen = max(1, algo.Gen - 1);
if show_gen_progress && current_gen > es('last_gen_printed')
    msg = sprintf('    [CEDA] Gen %d, FE=%d', current_gen, round(total_fe));
    for t = 1:nTask
        if isfinite(cur_best(t))
            msg = sprintf('%s | Task %d: FE=%d, BestObj=%.6f, BestCV=%.6f', ...
                msg, active_tasks(t), round(task_fe_vals(t)), cur_best(t), task_cv_vals(t));
        end
    end
    fprintf('%s\n', msg);
    es('last_gen_printed') = current_gen;
end

prev_best = es('prev_best');
prev_cv = es('prev_cv');
prev_has_feasible = es('prev_has_feasible');
[improved, state] = evaluate_ceda_dw_earlystop_progress( ...
    cur_best, cur_cv, prev_best, prev_cv, prev_has_feasible);
es('prev_best') = state.prev_best;
es('prev_cv') = state.prev_cv;
es('prev_has_feasible') = state.prev_has_feasible;
if improved
    es('stall_count') = 0;
else
    es('stall_count') = es('stall_count') + 1;
end
if es('stall_count') >= es('patience')
    es('triggered') = true;
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
