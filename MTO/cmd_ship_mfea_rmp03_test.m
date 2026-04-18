%% Quick MFEA RMP=0.3 test on ship panel problem with transfer diagnostics
% Usage:
%   1. cd('MTO');
%   2. run('cmd_ship_mfea_rmp03_test.m');

clc; clear; close all;
addpath(genpath(pwd));

%% Settings
active_tasks = [1 2];
num_tasks = numel(active_tasks);
pop_size = 5;
target_generations = 50;
total_fe = pop_size * num_tasks * (target_generations + 1);
global_seed = 20260324;
fixed_rmp = 0.3;
save_rmp_log = true;
rmp_log_dir = fullfile(pwd, 'RMPLogs', 'cmd_ship_mfea_rmp03_test');

fprintf('=== MFEA Fixed-RMP Test ===\n');
fprintf('Pop size: %d, Target gen: %d, Total FE: %d\n', ...
    pop_size, target_generations, total_fe);
fprintf('Fixed RMP: %.3f\n', fixed_rmp);

%% Algorithm
mfea = MFEA_RMPLog();
mfea.Name = 'MFEA-RMP0.3';
mfea.RMP = fixed_rmp;

%% Problem
prob = Ship_Panel_MTSO();
prob.ActiveTasks = active_tasks;
prob.N = pop_size;
prob.maxFE = total_fe;
prob.Cleanup = true;
prob.APDL_NProc = 4;
prob.setTasks();

%% Run
MTOData = mto( ...
    {mfea}, ...
    {prob}, ...
    'Reps', 1, ...
    'Save_Dec', false, ...
    'Global_Seed', global_seed, ...
    'Par_Flag', false ...
);

if save_rmp_log
    save_info = save_rmp_history(mfea, active_tasks, rmp_log_dir, ...
        'cmd_ship_mfea_rmp03_test');
    if ~isempty(save_info.mat_path)
        fprintf('RMP log MAT saved: %s\n', save_info.mat_path);
        fprintf('RMP log CSV saved: %s\n', save_info.csv_path);
        if ~isempty(save_info.transfer_csv_path)
            fprintf('Transfer diagnostic CSV saved: %s\n', ...
                save_info.transfer_csv_path);
        end
    end
end

%% Plot recorded off-diagonal RMP (expected around fixed value)
if ~isempty(mfea.RMPHistory)
    figure('Name', 'MFEA RMP Evolution');
    rmp_hist = mfea.RMPHistory;
    rmp_gen = mfea.RMPHistoryGen;
    n_gen = numel(rmp_hist);
    rmp_vals = zeros(n_gen, 1);
    for g = 1:n_gen
        rmp_vals(g) = rmp_hist{g}(1, 2);
    end
    plot(rmp_gen, rmp_vals, '-o', 'LineWidth', 1.5, 'MarkerSize', 5);
    xlabel('Generation');
    ylabel('RMP');
    title('MFEA Fixed RMP(T1, T2)');
    grid on;
    ylim([0, 1]);
    fprintf('RMP range: [%.4f, %.4f], mean: %.4f\n', ...
        min(rmp_vals), max(rmp_vals), mean(rmp_vals));
else
    disp('No RMP history available.');
end

if isprop(mfea, 'TransferDiagHistory') && ~isempty(mfea.TransferDiagHistory)
    summarize_transfer_diag(mfea, active_tasks);
end

obj_result = Obj(MTOData);
cv_result = CV(MTOData);
fr_result = FR(MTOData);
disp('=== Final objective / CV / FR ===');
disp(mean(obj_result.TableData, 3));
disp(mean(cv_result.TableData, 3));
disp(mean(fr_result.TableData, 3));

function summarize_transfer_diag(algo, active_tasks)
diag_hist = algo.TransferDiagHistory;
n_gen = numel(diag_hist);
if n_gen == 0
    return;
end

n_task = numel(diag_hist{1});
delta_cv = nan(n_gen, n_task);
delta_obj = nan(n_gen, n_task);
fr_gap = nan(n_gen, n_task);
transfer_count = zeros(n_task, 1);
nontransfer_count = zeros(n_task, 1);

for g = 1:n_gen
    stats = diag_hist{g};
    for t = 1:min(n_task, numel(stats))
        delta_cv(g, t) = stats(t).DeltaCV;
        delta_obj(g, t) = stats(t).DeltaObj;
        fr_gap(g, t) = stats(t).FRTransfer - stats(t).FRNonTransfer;
        transfer_count(t) = transfer_count(t) + stats(t).NTransfer;
        nontransfer_count(t) = nontransfer_count(t) + stats(t).NNonTransfer;
    end
end

disp('=== Transfer Diagnostic Summary (Transfer - NonTransfer) ===');
for t = 1:n_task
    task_id = t;
    if t <= numel(active_tasks)
        task_id = active_tasks(t);
    end
    if transfer_count(t) == 0
        fprintf(['Task %d: no transferred offspring were sampled ' ...
            '(NTransfer=0, NNonTransfer=%d).\n'], ...
            task_id, nontransfer_count(t));
        continue;
    end

    valid_delta = ~isnan(delta_cv(:, t));
    mean_delta_cv = mean(delta_cv(:, t), 'omitnan');
    mean_delta_obj = mean(delta_obj(:, t), 'omitnan');
    mean_fr_gap = mean(fr_gap(:, t), 'omitnan');
    neg_cv_ratio = mean(delta_cv(valid_delta, t) > 0);
    fprintf(['Task %d: mean DeltaCV=%.4f, mean DeltaObj=%.4f, ' ...
        'mean FR gap=%.4f, P(DeltaCV>0)=%.2f, ' ...
        'NTransfer=%d, NNonTransfer=%d\n'], ...
        task_id, mean_delta_cv, mean_delta_obj, mean_fr_gap, ...
        neg_cv_ratio, transfer_count(t), nontransfer_count(t));
end
end
