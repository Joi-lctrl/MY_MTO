%% Ship panel comparison: GA vs MFEA (with live convergence plot)
% Usage:
%   1. cd('MTO');
%   2. run('cmd_ship_panel_compare.m');
%
% Notes:
%   - Both algorithms use the same problem object, same N, and same maxFE.
%   - FE is counted by the MTO platform through Algorithm.Evaluation(...).
%   - MFEA uses fixed RMP=0.15 for cross-task transfer.
%   - Live convergence plot updates every generation via Check_Status_Fn.

clc; clear; close all;
addpath(genpath(pwd));

%% User-adjustable settings
active_tasks = [1 4];
num_tasks = numel(active_tasks);
pop_size = 24;     % each-task population size
total_fe = 1200;
reps = 1;
global_seed = 20260324;
cleanup_apdl = true;
apdl_nproc = 4;
export_final_png = false;

% FE budget estimation
ga_init_fe = pop_size * num_tasks;
ga_gen_fe = pop_size * num_tasks;
mfea_init_fe = pop_size * num_tasks * num_tasks;
mfea_gen_fe = pop_size * num_tasks;

fprintf('=== Ship Panel Grillage Optimization ===\n');
fprintf('Total FE budget per algorithm: %d\n', total_fe);
fprintf('Active tasks: [%s]\n', num2str(active_tasks));
fprintf('Population size per task: %d\n', pop_size);
fprintf('Global random seed: %d\n', global_seed);
fprintf('Approx GA generations: %d\n', ...
    max(0, floor((total_fe - ga_init_fe) / ga_gen_fe)));
fprintf('Approx MFEA generations: %d\n', ...
    max(0, floor((total_fe - mfea_init_fe) / mfea_gen_fe)));

%% Algorithms
ga = GA();
ga.Name = 'GA';

mfea = MFEA();
mfea.Name = 'MFEA';
mfea.RMP = 0.15;

%% Problem
prob = Ship_Panel_MTSO();
prob.ActiveTasks = active_tasks;
prob.N = pop_size;
prob.maxFE = total_fe;
prob.Cleanup = cleanup_apdl;
prob.APDL_NProc = apdl_nproc;
prob.setTasks();

%% Set up live convergence plot
fig_live = figure('Name', 'Live Convergence', 'Position', [100 100 900 400]);
colors = struct('GA', [0 0.447 0.741], 'MFEA', [0.850 0.325 0.098]);
styles = struct('GA', '-o', 'MFEA', '-s');
ax_live = gobjects(1, num_tasks);
lines_obj = struct();  % store animated line handles
lines_cv  = struct();

for t = 1:num_tasks
    ax_live(t) = subplot(1, num_tasks, t);
    hold(ax_live(t), 'on');
    grid(ax_live(t), 'on');
    title(ax_live(t), sprintf('Task %d', active_tasks(t)));
    xlabel(ax_live(t), 'Function Evaluations');
    ylabel(ax_live(t), 'Best Obj (kg) | CV');
end

% Create animated lines for each algorithm x task
algo_names = {'GA', 'MFEA'};
for a = 1:numel(algo_names)
    aname = algo_names{a};
    for t = 1:num_tasks
        lines_obj.(aname)(t) = animatedline(ax_live(t), ...
            'Color', colors.(aname), 'LineWidth', 1.5, ...
            'Marker', '.', 'MarkerSize', 8, ...
            'DisplayName', sprintf('%s Obj', aname));
        lines_cv.(aname)(t) = animatedline(ax_live(t), ...
            'Color', colors.(aname), 'LineStyle', '--', 'LineWidth', 1, ...
            'Marker', 'none', ...
            'DisplayName', sprintf('%s CV', aname));
    end
    legend(ax_live(1), 'Location', 'northeast');
end
drawnow;

% Attach live-plot callback to each algorithm
ga.Check_Status_Fn   = @() live_update(ga,   num_tasks, lines_obj.GA,   lines_cv.GA,   fig_live);
mfea.Check_Status_Fn = @() live_update(mfea, num_tasks, lines_obj.MFEA, lines_cv.MFEA, fig_live);

%% Run comparison
MTOData = mto( ...
    {ga, mfea}, ...
    {prob}, ...
    'Reps', reps, ...
    'Save_Dec', export_final_png, ...
    'Global_Seed', global_seed, ...
    'Par_Flag', false ...
);

%% Report final performance
obj_result = Obj(MTOData);
cv_result = CV(MTOData);
fr_result = FR(MTOData);

disp('=== Final objective values (mean over repetitions) ===');
disp(array2table(mean(obj_result.TableData, 3), ...
    'RowNames', obj_result.RowName, ...
    'VariableNames', obj_result.ColumnName));

disp('=== Final constraint violation (mean over repetitions) ===');
disp(array2table(mean(cv_result.TableData, 3), ...
    'RowNames', cv_result.RowName, ...
    'VariableNames', cv_result.ColumnName));

disp('=== Final feasible rate ===');
disp(array2table(mean(fr_result.TableData, 3), ...
    'RowNames', fr_result.RowName, ...
    'VariableNames', fr_result.ColumnName));

%% Final static convergence plot (from saved results)
figure('Name', 'Convergence Comparison (Final)');
tiledlayout('flow');
mean_converge = squeeze(mean(obj_result.ConvergeData.Y, 3));
mean_evaluations = squeeze(mean(obj_result.ConvergeData.X, 3));
for i = 1:size(mean_converge, 1)
    nexttile;
    for j = 1:size(mean_converge, 2)
        plot(squeeze(mean_evaluations(i, j, :)), ...
            squeeze(mean_converge(i, j, :)), ...
            'LineWidth', 1.5);
        hold on;
    end
    title(obj_result.RowName{i});
    legend(obj_result.ColumnName, 'Location', 'best');
    xlabel('Function Evaluations');
    ylabel('Objective Value (kg)');
    grid on;
end

%% ======================== Local Functions ================================

function live_update(algo, num_tasks, h_obj, h_cv, fig)
% Called every generation by Algorithm.notTerminated via Check_Status_Fn.
% algo is a handle object so we can read its current state.
if ~isvalid(fig)
    return;
end
fe = algo.FE;
for t = 1:num_tasks
    if ~isempty(algo.Best) && numel(algo.Best) >= t && ~isempty(algo.Best{t})
        addpoints(h_obj(t), fe, algo.Best{t}.Obj);
        addpoints(h_cv(t),  fe, algo.Best{t}.CV);
    end
end
drawnow('limitrate');
end

function export_final_plots(MTOData, prob)
repo_root = fileparts(pwd);
plot_root = fullfile(repo_root, 'APDLRESULTS_MTO', 'final_plots');
if exist(plot_root, 'dir') ~= 7
    mkdir(plot_root);
end

disp('=== Export final PNG plots ===');

for algo = 1:length(MTOData.Algorithms)
    algo_name = sanitize_name(char(MTOData.Algorithms(algo).Name));
    for task = 1:prob.T
        actual_task = prob.ActiveTasks(task);
        best_rep = [];
        best_obj = inf;
        best_cv = inf;

        for rep = 1:MTOData.Reps
            final_obj = MTOData.Results(1, algo, rep).Obj(task, end);
            final_cv = MTOData.Results(1, algo, rep).CV(task, end);
            if final_cv <= 0 && isfinite(final_obj) && final_obj < best_obj
                best_obj = final_obj;
                best_cv = final_cv;
                best_rep = rep;
            elseif isempty(best_rep) && isfinite(final_cv) && final_cv < best_cv
                best_obj = final_obj;
                best_cv = final_cv;
                best_rep = rep;
            end
        end

        if isempty(best_rep)
            fprintf('Skip %s Task %d: no final solution stored.\n', ...
                char(MTOData.Algorithms(algo).Name), actual_task);
            continue;
        end

        x = squeeze(MTOData.Results(1, algo, best_rep).Dec(task, end, :))';
        cfg = struct();
        cfg.apdl_dir = fullfile(repo_root, 'APDL');
        cfg.n_proc = prob.APDL_NProc;
        cfg.cleanup = cleanup_apdl;
        cfg.work_dir = fullfile(plot_root, algo_name, sprintf('task%d', actual_task));

        [obj, con, extra] = run_ansys_eval(x, actual_task, cfg);
        fprintf('%s Task %d -> rep %d, obj=%.2f kg, cv=%.3f, feasible=%d\n', ...
            char(MTOData.Algorithms(algo).Name), actual_task, best_rep, ...
            obj, sum(max(0, con)), extra.feasible);
    end
end
end

function name = sanitize_name(name)
name = regexprep(name, '[^A-Za-z0-9_-]+', '_');
end
