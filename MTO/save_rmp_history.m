function save_info = save_rmp_history(algo, active_tasks, out_dir, run_tag)
% Save RMP trajectory from a log-enabled multitask algorithm to MAT/CSV.
%
% Inputs:
%   algo         - algorithm object with RMPHistory/RMPHistoryGen/RMPHistoryFE
%   active_tasks - original task ids used in this run (e.g., [1 2])
%   out_dir      - output directory, default: fullfile(pwd, 'RMPLogs')
%   run_tag      - file tag prefix, default: algo name
%
% Output:
%   save_info    - struct containing output paths and basic stats

if nargin < 2 || isempty(active_tasks)
    active_tasks = [];
end
if nargin < 3 || isempty(out_dir)
    out_dir = fullfile(pwd, 'RMPLogs');
end
if nargin < 4 || isempty(run_tag)
    run_tag = char(algo.Name);
end

save_info = struct( ...
    'mat_path', '', ...
    'csv_path', '', ...
    'transfer_csv_path', '', ...
    'n_gen', 0, ...
    'n_pairs', 0, ...
    'n_diag_rows', 0);

if ~isprop(algo, 'RMPHistory') || isempty(algo.RMPHistory)
    warning('save_rmp_history:NoRMPData', ...
        'No RMP history found on the algorithm object. Nothing saved.');
    return;
end

if exist(out_dir, 'dir') ~= 7
    mkdir(out_dir);
end

rmp_hist = algo.RMPHistory;
n_gen = numel(rmp_hist);
num_tasks = size(rmp_hist{1}, 1);

if isempty(active_tasks) || numel(active_tasks) ~= num_tasks
    active_tasks = 1:num_tasks;
end

if isprop(algo, 'RMPHistoryGen') && numel(algo.RMPHistoryGen) == n_gen
    rmp_gen = algo.RMPHistoryGen(:);
else
    rmp_gen = (1:n_gen)';
end
if isprop(algo, 'RMPHistoryFE') && numel(algo.RMPHistoryFE) == n_gen
    rmp_fe = algo.RMPHistoryFE(:);
else
    rmp_fe = nan(n_gen, 1);
end

pair_i = [];
pair_j = [];
pair_names = {};
for i = 1:num_tasks
    for j = i + 1:num_tasks
        pair_i(end + 1, 1) = i; %#ok<AGROW>
        pair_j(end + 1, 1) = j; %#ok<AGROW>
        pair_names{end + 1, 1} = sprintf('RMP_T%d_T%d', active_tasks(i), active_tasks(j)); %#ok<AGROW>
    end
end
n_pairs = numel(pair_i);

rmp_pair_values = nan(n_gen, n_pairs);
for g = 1:n_gen
    R = rmp_hist{g};
    for p = 1:n_pairs
        rmp_pair_values(g, p) = R(pair_i(p), pair_j(p));
    end
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
base_name = sprintf('%s_%s', sanitize_name(run_tag), timestamp);
mat_path = fullfile(out_dir, [base_name, '.mat']);
csv_path = fullfile(out_dir, [base_name, '.csv']);

RMPLog = struct();
RMPLog.CreatedAt = datetime('now');
RMPLog.Algorithm = char(algo.Name);
RMPLog.RunTag = run_tag;
RMPLog.ActiveTasks = active_tasks(:)';
RMPLog.RMPHistory = rmp_hist;
RMPLog.RMPHistoryGen = rmp_gen;
RMPLog.RMPHistoryFE = rmp_fe;
RMPLog.PairNames = pair_names;
RMPLog.PairValues = rmp_pair_values;
RMPLog.Note = 'If Reps > 1 in mto(...), this stores the last repetition only.';

table_data = [rmp_gen, rmp_fe, rmp_pair_values];
table_names = [{'Generation', 'FunctionEvaluations'}, pair_names'];
T = array2table(table_data, 'VariableNames', table_names);
writetable(T, csv_path);

if isprop(algo, 'TransferDiagHistory') && ~isempty(algo.TransferDiagHistory)
    diag_hist = algo.TransferDiagHistory;
    diag_gen = [];
    diag_fe = [];
    if isprop(algo, 'TransferDiagGen')
        diag_gen = algo.TransferDiagGen;
    end
    if isprop(algo, 'TransferDiagFE')
        diag_fe = algo.TransferDiagFE;
    end
    [diag_csv_path, n_diag_rows] = write_transfer_diag_csv( ...
        diag_hist, diag_gen, diag_fe, active_tasks, out_dir, base_name);
    if ~isempty(diag_csv_path)
        save_info.transfer_csv_path = diag_csv_path;
        save_info.n_diag_rows = n_diag_rows;
    end
    RMPLog.TransferDiagHistory = diag_hist;
    RMPLog.TransferDiagGen = diag_gen;
    RMPLog.TransferDiagFE = diag_fe;
end

save(mat_path, 'RMPLog');

save_info.mat_path = mat_path;
save_info.csv_path = csv_path;
save_info.n_gen = n_gen;
save_info.n_pairs = n_pairs;
end

function name = sanitize_name(name)
name = regexprep(char(name), '[^A-Za-z0-9_-]+', '_');
end

function [csv_path, n_rows] = write_transfer_diag_csv(diag_hist, diag_gen, diag_fe, active_tasks, out_dir, base_name)
csv_path = '';
n_rows = 0;
if isempty(diag_hist)
    return;
end

gen_col = [];
fe_col = [];
task_idx_col = [];
task_id_col = [];
n_total_col = [];
n_trans_col = [];
n_non_col = [];
fr_trans_col = [];
fr_non_col = [];
mean_cv_trans_col = [];
mean_cv_non_col = [];
mean_obj_trans_col = [];
mean_obj_non_col = [];
delta_cv_col = [];
delta_obj_col = [];

for g = 1:numel(diag_hist)
    task_stats = diag_hist{g};
    if isempty(task_stats)
        continue;
    end

    curr_gen = value_at_or(diag_gen, g, g);
    curr_fe = value_at_or(diag_fe, g, NaN);

    for t = 1:numel(task_stats)
        s = task_stats(t);
        task_idx = field_or(s, 'TaskIndex', t);
        task_id = task_idx;
        if ~isempty(active_tasks) && task_idx >= 1 && task_idx <= numel(active_tasks)
            task_id = active_tasks(task_idx);
        end

        gen_col(end + 1, 1) = curr_gen; %#ok<AGROW>
        fe_col(end + 1, 1) = curr_fe; %#ok<AGROW>
        task_idx_col(end + 1, 1) = task_idx; %#ok<AGROW>
        task_id_col(end + 1, 1) = task_id; %#ok<AGROW>
        n_total_col(end + 1, 1) = field_or(s, 'NTotal', 0); %#ok<AGROW>
        n_trans_col(end + 1, 1) = field_or(s, 'NTransfer', 0); %#ok<AGROW>
        n_non_col(end + 1, 1) = field_or(s, 'NNonTransfer', 0); %#ok<AGROW>
        fr_trans_col(end + 1, 1) = field_or(s, 'FRTransfer', NaN); %#ok<AGROW>
        fr_non_col(end + 1, 1) = field_or(s, 'FRNonTransfer', NaN); %#ok<AGROW>
        mean_cv_trans_col(end + 1, 1) = field_or(s, 'MeanCVTransfer', NaN); %#ok<AGROW>
        mean_cv_non_col(end + 1, 1) = field_or(s, 'MeanCVNonTransfer', NaN); %#ok<AGROW>
        mean_obj_trans_col(end + 1, 1) = field_or(s, 'MeanObjTransfer', NaN); %#ok<AGROW>
        mean_obj_non_col(end + 1, 1) = field_or(s, 'MeanObjNonTransfer', NaN); %#ok<AGROW>
        delta_cv_col(end + 1, 1) = field_or(s, 'DeltaCV', NaN); %#ok<AGROW>
        delta_obj_col(end + 1, 1) = field_or(s, 'DeltaObj', NaN); %#ok<AGROW>
    end
end

if isempty(gen_col)
    return;
end

T = table( ...
    gen_col, fe_col, task_idx_col, task_id_col, ...
    n_total_col, n_trans_col, n_non_col, ...
    fr_trans_col, fr_non_col, ...
    mean_cv_trans_col, mean_cv_non_col, ...
    mean_obj_trans_col, mean_obj_non_col, ...
    delta_cv_col, delta_obj_col, ...
    'VariableNames', { ...
    'Generation', 'FunctionEvaluations', 'TaskIndex', 'TaskID', ...
    'NTotal', 'NTransfer', 'NNonTransfer', ...
    'FRTransfer', 'FRNonTransfer', ...
    'MeanCVTransfer', 'MeanCVNonTransfer', ...
    'MeanObjTransfer', 'MeanObjNonTransfer', ...
    'DeltaCV', 'DeltaObj'});

csv_path = fullfile(out_dir, [base_name, '_transfer_diag.csv']);
writetable(T, csv_path);
n_rows = height(T);
end

function v = field_or(s, field_name, default_v)
if isfield(s, field_name)
    v = s.(field_name);
else
    v = default_v;
end
end

function v = value_at_or(x, idx, default_v)
if isempty(x) || numel(x) < idx
    v = default_v;
else
    v = x(idx);
end
end
