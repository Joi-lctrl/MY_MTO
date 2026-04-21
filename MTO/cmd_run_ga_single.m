%% cmd_run_ga_single.m - 逐任务单独运行GA并保存统一格式结果

clear; clear classes; clc; close all;
cd(fileparts(mfilename('fullpath')));
rehash toolboxcache;
addpath(genpath(pwd));

%% ===== 配置 =====
active_tasks = [5];
Reps = 1;
maxFE = 6000;
N = 100;
Results_Num = 50;
Global_Seed = 2604;
EarlyStop_Patience = 50;
ShowGenProgress = true;

YLim_Obj = [];
YLim_CV  = [0 200];

algo_names = {'GA'};
nAlgo = 1;
nTask = numel(active_tasks);

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
fig1 = figure('Name', 'GA 单任务基线收敛', 'Position', [60 450 900 400]);
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
        'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5, ...
        'Marker', '.', 'MarkerSize', 6, ...
        'DisplayName', 'GA Feasible Obj');
    yyaxis(ax(t), 'right');
    ylabel(ax(t), 'CV');
    ylim(ax(t), YLim_CV);
    h_cv(1, t) = animatedline(ax(t), ...
        'Color', [0.8500 0.3250 0.0980], 'LineStyle', '--', 'LineWidth', 1, ...
        'DisplayName', 'GA CV');
    legend(ax(t), 'Location', 'northeast');
end
drawnow;

%% ===== 运行 =====
fprintf('开始运行 GA 单任务基线: Reps=%d, Tasks=[%s]\n', Reps, num2str(active_tasks));

for rep = 1:Reps
    fprintf('\n--- Rep %d/%d, GA ---\n', rep, Reps);
    pop_histories = cell(1, nTask);

    for task_slot = 1:nTask
        actual_task = active_tasks(task_slot);
        clearpoints(h_obj(1, task_slot));
        clearpoints(h_cv(1, task_slot));

        prob = Ship_Panel_MTSO();
        prob.N = N;
        prob.maxFE = maxFE;
        prob.Cleanup = true;
        prob.ActiveTasks = actual_task;
        prob.setTasks();
        fprintf('     Task %d setup: D=%d, constraints=%d\n', ...
            actual_task, prob.D(1), numel(get_ship_constraint_names(actual_task)));

        algo = GA();
        algo.Result_Num = Results_Num;
        algo.Save_Dec = false;
        algo.reset();

        rng(seeds(rep));

        es = containers.Map();
        es('prev_best') = inf;
        es('stall_count') = 0;
        es('patience') = EarlyStop_Patience;
        es('triggered') = false;
        es('last_gen_printed') = 0;

        algo.Check_Status_Fn = @() live_update_single_task( ...
            algo, task_slot, actual_task, h_obj, h_cv, fig1, es, ShowGenProgress);

        fprintf('  -> Task %d\n', actual_task);
        algo.run(prob);
        pop_histories{task_slot} = algo.PopSize_Gen(:);

        if es('triggered')
            fprintf('     [早停] Task %d 停止（连续%d代无改进）\n', actual_task, es('patience'));
        end

        if ~isempty(algo.Best) && ~isempty(algo.Best{1})
            d = prob.D(1);
            dec_norm = algo.Best{1}.Dec(1:d);
            BestDecNorm{1, rep, task_slot} = dec_norm;
            BestDecReal{1, rep, task_slot} = prob.Lb{1} + dec_norm .* (prob.Ub{1} - prob.Lb{1});
            BestCon{1, rep, task_slot} = algo.Best{1}.Con;
            BestCV(1, rep, task_slot) = algo.Best{1}.CV;
        end

        task_fe_gen = algo.FE_Gen;
        if isempty(task_fe_gen)
            error('GA Task %d 未生成 FE_Gen，无法构造收敛曲线。', actual_task);
        end

        raw_task_axis = task_fe_gen(:)';
        raw_obj_hist = [algo.Result(1, 1:numel(raw_task_axis)).Obj];
        raw_cv_hist = [algo.Result(1, 1:numel(raw_task_axis)).CV];
        raw_feasible_obj_hist = build_feasible_best_obj(raw_obj_hist, raw_cv_hist);

        RawConvergeObj{1}{task_slot} = assign_history_row(RawConvergeObj{1}{task_slot}, rep, raw_obj_hist);
        RawConvergeCV{1}{task_slot} = assign_history_row(RawConvergeCV{1}{task_slot}, rep, raw_cv_hist);
        RawConvergeFeasibleObj{1}{task_slot} = assign_history_row(RawConvergeFeasibleObj{1}{task_slot}, rep, raw_feasible_obj_hist);
        RawConvergeTaskFE{1}{task_slot} = assign_history_row(RawConvergeTaskFE{1}{task_slot}, rep, raw_task_axis);

        tmp_task = gen2eva(algo.Result(1, :), task_fe_gen, Results_Num);
        task_axis = linspace(task_fe_gen(1), task_fe_gen(end), size(tmp_task, 2));

        obj_hist = [tmp_task.Obj];
        cv_hist = [tmp_task.CV];
        feasible_obj_hist = build_feasible_best_obj(obj_hist, cv_hist);

        if isempty(ConvergeObj{1}{task_slot})
            ConvergeObj{1}{task_slot} = nan(Reps, numel(obj_hist));
        end
        if isempty(ConvergeCV{1}{task_slot})
            ConvergeCV{1}{task_slot} = nan(Reps, numel(cv_hist));
        end
        if isempty(ConvergeFeasibleObj{1}{task_slot})
            ConvergeFeasibleObj{1}{task_slot} = nan(Reps, numel(feasible_obj_hist));
        end
        if isempty(ConvergeTaskFE{1}{task_slot})
            ConvergeTaskFE{1}{task_slot} = nan(Reps, numel(task_axis));
        end

        ConvergeObj{1}{task_slot}(rep, :) = obj_hist;
        ConvergeCV{1}{task_slot}(rep, :) = cv_hist;
        ConvergeFeasibleObj{1}{task_slot}(rep, :) = feasible_obj_hist;
        ConvergeTaskFE{1}{task_slot}(rep, :) = task_axis;
        BestObj(1, rep, task_slot) = obj_hist(end);
        if any(isfinite(feasible_obj_hist))
            BestFeasibleObj(1, rep, task_slot) = feasible_obj_hist(find(isfinite(feasible_obj_hist), 1, 'last'));
        end
    end

    max_gen = max(cellfun(@numel, pop_histories));
    pop_matrix = nan(max_gen, nTask);
    for task_slot = 1:nTask
        hist_col = pop_histories{task_slot};
        pop_matrix(1:numel(hist_col), task_slot) = hist_col;
    end
    PopulationSizeStats{1, rep} = pop_matrix;

    fprintf('  GA Rep%d 完成: ', rep);
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
save_name = sprintf('ga_single_%s.mat', datestr(now, 'yyyymmdd_HHMMSS'));
save(save_name, 'BestObj', 'BestFeasibleObj', 'BestCV', 'BestDecNorm', 'BestDecReal', 'BestCon', 'BestConNames', ...
    'ConvergeObj', 'ConvergeCV', 'ConvergeFeasibleObj', 'ConvergeFE', 'ConvergeTaskFE', ...
    'RawConvergeObj', 'RawConvergeCV', 'RawConvergeFeasibleObj', 'RawConvergeTaskFE', ...
    'algo_names', 'active_tasks', 'Reps', 'maxFE', 'Global_Seed', 'rep_seeds', ...
    'PopulationSizeStats');
fprintf('结果已保存到 %s\n', save_name);

%% ======================== Local Functions ================================

function live_update_single_task(algo, task_slot, actual_task, h_obj, h_cv, fig1, es, show_gen_progress)
if ~isvalid(fig1), return; end
if isempty(algo.Best) || isempty(algo.Best{1}), return; end

task_fe = algo.FE;
if isprop(algo, 'TaskFE') && ~isempty(algo.TaskFE) && isfinite(algo.TaskFE(1)) && algo.TaskFE(1) > 0
    task_fe = algo.TaskFE(1);
end

feasible_obj = nan;
if isfield(algo.Best{1}, 'CV') && algo.Best{1}.CV <= 0
    feasible_obj = algo.Best{1}.Obj;
end
addpoints(h_obj(1, task_slot), task_fe, feasible_obj);
addpoints(h_cv(1, task_slot), task_fe, algo.Best{1}.CV);
drawnow('limitrate');

current_gen = max(1, algo.Gen - 1);
if show_gen_progress && current_gen > es('last_gen_printed')
    fprintf('    [GA][Task %d] Gen %d, FE=%d, BestObj=%.6f, BestCV=%.6f\n', ...
        actual_task, current_gen, round(task_fe), algo.Best{1}.Obj, algo.Best{1}.CV);
    es('last_gen_printed') = current_gen;
end

if algo.Best{1}.Obj < es('prev_best') - 1e-6
    es('stall_count') = 0;
    es('prev_best') = algo.Best{1}.Obj;
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
