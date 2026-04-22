function [obj, con, extra] = run_ansys_eval(x, task_id, cfg)
% Run ANSYS APDL evaluation for ship panel grillage optimization.
%
% Inputs:
%   x        - 1xD design variable vector (real values, not normalized)
%   task_id  - task index
%   cfg      - struct with fields:
%              .apdl_dir  - path to APDL template directory
%              .n_proc    - number of ANSYS parallel processes
%              .cleanup   - logical, remove temp files after evaluation
%              .work_dir  - working directory for this evaluation
%              .reuse_mesh - logical, reuse cached meshed base model when true
%
% Outputs:
%   obj   - scalar objective (mass in kg)
%   con   - constraint vector (positive = violated)
%           tasks 1-2,7: [bend_violation, shear_violation, 0, 0]
%           tasks 3-4: [bend_violation, shear_violation, ...
%                      web_L1, flange_L1, web_L2, flange_L2, ...
%                      web_R1, flange_R1, web_R2, flange_R2, web_R3, flange_R3]
%           task 5: [bend_violation, shear_violation, ...
%                    web_L1, flange_L1, web_L2, flange_L2, ...
%                    web_R1, flange_R1, web_R2, flange_R2, ...
%                    web_R3, flange_R3, web_R4, flange_R4]
%           task 6: same constraint layout as task 5
%           tasks 8-9: [bend_violation, shear_violation, ...
%                      web_L1, flange_L1, web_L2, flange_L2, web_L3, flange_L3, web_L4, flange_L4, ...
%                      web_R1, flange_R1, web_R2, flange_R2, web_R3, flange_R3, ...
%                      web_R4, flange_R4, web_R5, flange_R5]
%   extra - struct with additional info

extra = struct('error', false, 'feasible', false, ...
    'max_bend', NaN, 'max_shear', NaN, 'mass', NaN, ...
    'hL2_minus_hL1', NaN, ...
    'hL3_minus_hL2', NaN);

ship_prob = Ship_Panel_Problem();
task = ship_prob.Tasks(task_id);
reuse_mesh = true;
if isfield(cfg, 'reuse_mesh')
    reuse_mesh = logical(cfg.reuse_mesh);
end

% Compute objective (mass)
mass = ship_prob.compute_mass(x, task_id);
extra.mass = mass;

% Prepare working directory
work_dir = cfg.work_dir;
if exist(work_dir, 'dir') ~= 7
    mkdir(work_dir);
end

% Find ANSYS executable
ansys_exe = find_ansys_exe();
if isempty(ansys_exe)
    warning('run_ansys_eval:noAnsys', 'ANSYS executable not found.');
    obj = 1e10;
    con = build_penalty_constraints(task);
    extra.error = true;
    return;
end

if reuse_mesh
    [base_ok, base_model_name] = ensure_base_model(ship_prob, task, task_id, cfg, ansys_exe); %#ok<ASGLU>
    if ~base_ok
        warning('run_ansys_eval:baseModelFail', ...
            'Failed to prepare cached base model for task %d.', task_id);
        obj = 1e10;
        con = build_penalty_constraints(task);
        extra.error = true;
        return;
    end
end

job_name = make_job_name(task_id, work_dir);
results_stem = [job_name '_results'];
mac_file = fullfile(work_dir, [job_name '.mac']);
results_file = fullfile(work_dir, [results_stem '.txt']);
cleanup_enabled = isfield(cfg, 'cleanup') && logical(cfg.cleanup);
if cleanup_enabled
    % Ensure temp files are cleaned even when this function returns early.
    cleanup_guard = onCleanup(@()cleanup_work_dir(work_dir, job_name)); %#ok<NASGU>
end

% Generate macro with a per-run results file to avoid cross-run collisions.
if reuse_mesh
    mac_str = ship_prob.generate_mac_from_base(x, task_id, base_model_name, results_stem);
else
    mac_str = ship_prob.generate_mac(x, task_id);
    mac_str = strrep(mac_str, '*CFOPEN, results, txt', ...
        sprintf('*CFOPEN, %s, txt', results_stem));
end

if isfile(results_file)
    delete(results_file);
end

% Write macro file
fid = fopen(mac_file, 'w');
if fid == -1
    warning('run_ansys_eval:fileWrite', 'Cannot write macro file: %s', mac_file);
    obj = 1e10;
    con = build_penalty_constraints(task);
    extra.error = true;
    return;
end
fprintf(fid, '%s\n', mac_str);
fclose(fid);

% Run ANSYS in batch mode
n_proc = cfg.n_proc;
cmd = sprintf('"%s" -b -np %d -j %s -i "%s" -o "%s" -dir "%s"', ...
    ansys_exe, n_proc, job_name, mac_file, ...
    fullfile(work_dir, [job_name '.out']), work_dir);

[status, ~] = system(cmd);
if status ~= 0
    warning('run_ansys_eval:ansysFail', 'ANSYS returned non-zero status: %d', status);
    obj = 1e10;
    con = build_penalty_constraints(task);
    extra.error = true;
    return;
end

% Parse results
[max_bend, max_shear, fea_mass, parse_ok] = parse_results(results_file);

if ~parse_ok
    obj = 1e10;
    con = build_penalty_constraints(task);
    extra.error = true;
    return;
end

extra.max_bend = max_bend;
extra.max_shear = max_shear;
extra.mass_analytical = mass;
extra.mass_fea = fea_mass;

% Objective: use FEA mass (more accurate than analytical formula)
obj = fea_mass;

% Constraints: g(x) <= 0 form, positive means violated
con_strength = zeros(1, 2);
con_strength(1) = max_bend - task.bend_allow;
con_strength(2) = max_shear - task.shear_allow;

if has_slenderness_constraints(task)
    con = [con_strength, build_group_constraints(x, task)];
else
    con = [con_strength, 0, 0];
    extra.hL2_minus_hL1 = 0;
    extra.hL3_minus_hL2 = 0;
end

extra.feasible = all(con <= 0);
end

function tf = has_slenderness_constraints(task)
tf = false;
if isfield(task, 'enable_group_slenderness')
    tf = logical(task.enable_group_slenderness);
    return;
end

if ~isfield(task, 'n_long') || ~isfield(task, 'n_rib')
    return;
end
end

function con = build_penalty_constraints(task)
if has_slenderness_constraints(task)
    long_group_count = 1;
    rib_group_count = 1;
    if isfield(task, 'long_group_count')
        long_group_count = task.long_group_count;
    end
    if isfield(task, 'rib_group_count')
        rib_group_count = task.rib_group_count;
    end
    ncon = 2 + 2 * (long_group_count + rib_group_count) + count_additional_group_constraints(task);
    con = 100 * ones(1, ncon);
else
    con = [100, 100, 100, 100];
end
end

function con_group = build_group_constraints(x, task)
ship_prob = Ship_Panel_Problem();
[long_groups, rib_groups] = ship_prob.parse_grouped_sections(x, task);

lambda_web_long = resolve_slenderness_limit(task, 'lambda_web_long', 50);
lambda_flange_long = resolve_slenderness_limit(task, 'lambda_flange_long', 10);
lambda_web_rib = resolve_slenderness_limit(task, 'lambda_web_rib', 50);
lambda_flange_rib = resolve_slenderness_limit(task, 'lambda_flange_rib', 10);

con_group = zeros(1, 2 * (size(long_groups, 1) + size(rib_groups, 1)) + count_additional_group_constraints(task));
idx = 1;

for g = 1:size(long_groups, 1)
    h_web = long_groups(g, 1);
    t_web = long_groups(g, 2);
    b_bot = long_groups(g, 3);
    t_bot = long_groups(g, 4);
    con_group(idx) = h_web / t_web - lambda_web_long;
    con_group(idx + 1) = b_bot / t_bot - lambda_flange_long;
    idx = idx + 2;
end

for g = 1:size(rib_groups, 1)
    h_web = rib_groups(g, 1);
    t_web = rib_groups(g, 2);
    b_bot = rib_groups(g, 3);
    t_bot = rib_groups(g, 4);
    con_group(idx) = h_web / t_web - lambda_web_rib;
    con_group(idx + 1) = b_bot / t_bot - lambda_flange_rib;
    idx = idx + 2;
end

if has_rib_web_below_long_web_constraint(task)
    con_group(idx) = max(rib_groups(:, 1)) - min(long_groups(:, 1));
end
end

function ncon = count_additional_group_constraints(task)
ncon = 0;
if has_rib_web_below_long_web_constraint(task)
    ncon = ncon + 1;
end
end

function tf = has_rib_web_below_long_web_constraint(task)
tf = false;
if isfield(task, 'enforce_rib_web_below_long_web')
    tf = logical(task.enforce_rib_web_below_long_web);
end
end

function value = resolve_slenderness_limit(task, field_name, default_value)
value = default_value;
if isfield(task, field_name)
    value = task.(field_name);
end
end

function [max_bend, max_shear, fea_mass, ok] = parse_results(results_file)
max_bend = NaN;
max_shear = NaN;
fea_mass = NaN;
ok = false;

if ~isfile(results_file)
    return;
end

fid = fopen(results_file, 'r');
if fid == -1
    return;
end

vals = zeros(7, 1);
for i = 1:7
    line = fgetl(fid);
    if ~ischar(line)
        fclose(fid);
        return;
    end
    vals(i) = str2double(strtrim(line));
    if isnan(vals(i))
        fclose(fid);
        return;
    end
end
fclose(fid);

sx_max  = vals(1);
sx_min  = vals(2);
sxy_max = vals(3);
sxy_min = vals(4);
sxz_max = vals(5);
sxz_min = vals(6);
fea_mass = vals(7) * 1e3; % ANSYS uses tonnes (density 7.85e-9 t/mm^3), convert to kg

max_bend = max(abs([sx_max, sx_min]));
max_shear = max(abs([sxy_max, sxy_min, sxz_max, sxz_min]));
ok = true;
end

function exe = find_ansys_exe()
exe = '';
% Common ANSYS installation paths on Windows
base_paths = {'C:\Program Files\ANSYS Inc', ...
    'D:\Program Files\ANSYS Inc', ...
    'E:\Program Files\ANSYS Inc', ...
    'C:\Program Files\ANSYS Inc241', ...
    'D:\Program Files\ANSYS Inc241', ...
    'E:\Program Files\ANSYS Inc241'};

for i = 1:length(base_paths)
    candidates = dir(fullfile(base_paths{i}, 'v*', 'ANSYS', 'bin', 'winx64', 'MAPDL.exe'));
    if ~isempty(candidates)
        exe = fullfile(candidates(end).folder, candidates(end).name);
        return;
    end
    candidates = dir(fullfile(base_paths{i}, 'v*', 'ANSYS', 'bin', 'winx64', 'ansys*.exe'));
    if ~isempty(candidates)
        exe = fullfile(candidates(end).folder, candidates(end).name);
        return;
    end
end

% Try system PATH
[status, result] = system('where MAPDL.exe 2>nul');
if status == 0
    exe = strtrim(result);
    exe = strsplit(exe, newline);
    exe = strtrim(exe{1});
    return;
end
[status, result] = system('where ansys241.exe 2>nul');
if status == 0
    exe = strtrim(result);
    exe = strsplit(exe, newline);
    exe = strtrim(exe{1});
end
end

function [ok, base_model_name] = ensure_base_model(ship_prob, task, task_id, cfg, ansys_exe)
ok = false;
base_model_name = sprintf('task%d_base_model', task_id);
work_dir = cfg.work_dir;
base_db_file = fullfile(work_dir, [base_model_name '.db']);
sig_file = fullfile(work_dir, [base_model_name '_signature.txt']);
expected_sig = make_base_model_signature(task, task_id);

needs_build = ~isfile(base_db_file);
if ~needs_build
    if ~isfile(sig_file)
        needs_build = true;
    else
        existing_sig = strtrim(fileread(sig_file));
        needs_build = ~strcmp(existing_sig, expected_sig);
    end
end

if ~needs_build
    ok = true;
    return;
end

base_job_name = sprintf('%s_build', base_model_name);
base_mac_file = fullfile(work_dir, [base_job_name '.mac']);
base_out_file = fullfile(work_dir, [base_job_name '.out']);
base_mac_str = ship_prob.generate_base_mesh_mac(task_id, base_model_name);

fid = fopen(base_mac_file, 'w');
if fid == -1
    warning('run_ansys_eval:baseWrite', 'Cannot write base macro file: %s', base_mac_file);
    return;
end
fprintf(fid, '%s\n', base_mac_str);
fclose(fid);

if isfile(base_db_file)
    delete(base_db_file);
end

n_proc = cfg.n_proc;
cmd = sprintf('"%s" -b -np %d -j %s -i "%s" -o "%s" -dir "%s"', ...
    ansys_exe, n_proc, base_job_name, base_mac_file, base_out_file, work_dir);

[status, ~] = system(cmd);
if status ~= 0 || ~isfile(base_db_file)
    warning('run_ansys_eval:baseBuildFail', ...
        'ANSYS failed to build base model for task %d (status=%d).', task_id, status);
    return;
end

fid = fopen(sig_file, 'w');
if fid ~= -1
    fprintf(fid, '%s\n', expected_sig);
    fclose(fid);
end

ok = true;
end

function sig = make_base_model_signature(task, task_id)
if any(task_id == [3, 4])
    long_ext = task.s_rib;
    rib_ext = task.s_long / 2;
elseif any(task_id == [8, 9])
    long_ext = task.s_rib;
    rib_ext = task.s_long / 2;
else
    long_ext = task.s_rib / 2;
    rib_ext = task.s_long / 2;
end

sig = sprintf(['task=%d|name=%s|s_long=%.12g|s_rib=%.12g|q1=%.12g|t_plate=%.12g|' ...
               'n_long=%d|n_rib=%d|long_group_count=%d|rib_group_count=%d|' ...
               'b_top_long=%s|b_top_rib=%s|long_ext=%.12g|rib_ext=%.12g'], ...
               task_id, task.name, task.s_long, task.s_rib, task.q1, task.t_plate, ...
               task.n_long, task.n_rib, task.long_group_count, task.rib_group_count, ...
               format_signature_value(task.b_top_long), format_signature_value(task.b_top_rib), ...
               long_ext, rib_ext);
end

function text = format_signature_value(value)
value = reshape(value, 1, []);
parts = arrayfun(@(x)sprintf('%.12g', x), value, 'UniformOutput', false);
text = ['[' strjoin(parts, ',') ']'];
end

function job_name = make_job_name(task_id, work_dir)
% Generate a unique ANSYS job name to avoid stale .lock collisions.
tmp_name = tempname(work_dir);
[~, base_name] = fileparts(tmp_name);
job_name = sprintf('eval_t%d_%s', task_id, base_name);
end

function cleanup_work_dir(work_dir, job_name)
% Remove ANSYS temp files but keep the directory
patterns = {[job_name '*.rst'], [job_name '*.rth'], [job_name '*.full'], [job_name '*.esav'], ...
    [job_name '*.mntr'], [job_name '*.err'], [job_name '*.log'], ...
    [job_name '*.out'], [job_name '*.DSP'], [job_name '*.page'], ...
    [job_name '*.lock'], [job_name '*.BCS'], [job_name '*.db'], ...
    [job_name '*.stat'], ...
    [job_name '*.mac'], [job_name '*.bat'], ...
    [job_name '_results.txt'], '*.png'};
for i = 1:length(patterns)
    files = dir(fullfile(work_dir, patterns{i}));
    for j = 1:length(files)
        delete(fullfile(work_dir, files(j).name));
    end
end
end
