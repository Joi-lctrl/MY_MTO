clear; clc;
cd(fileparts(mfilename('fullpath')));
addpath(genpath(pwd));

tol = 1e-6;

% Case 1: No feasible solution yet, smaller CV should count as progress.
[improved, state] = evaluate_ceda_dw_earlystop_progress( ...
    [120, 200], [15, 30], [inf, inf], [20, 30], [false, false], tol);
assert(improved, 'CV improvement should reset early stop before feasibility.');
assert(all(abs(state.prev_cv - [15, 30]) < tol), 'Best CV state update mismatch.');
assert(all(~state.prev_has_feasible), 'No task should be marked feasible yet.');

% Case 2: First feasible solution should count as progress even if objective is not better.
[improved, state] = evaluate_ceda_dw_earlystop_progress( ...
    [150, 210], [0, 5], [inf, inf], [10, 8], [false, false], tol);
assert(improved, 'First feasible solution should reset early stop.');
assert(state.prev_has_feasible(1), 'Feasible state should be latched once found.');
assert(abs(state.prev_best(1) - 150) < tol, 'Feasible objective should be recorded.');

% Case 3: Once feasible, only objective improvement should count.
[improved, state] = evaluate_ceda_dw_earlystop_progress( ...
    [140, 205], [0, 4], [150, inf], [0, 5], [true, false], tol);
assert(improved, 'Feasible objective improvement or infeasible CV improvement should reset early stop.');
assert(abs(state.prev_best(1) - 140) < tol, 'Best feasible objective should update.');
assert(abs(state.prev_cv(2) - 4) < tol, 'Best infeasible CV should update.');

% Case 4: Feasible objective unchanged and infeasible CV unchanged -> no progress.
[improved, state] = evaluate_ceda_dw_earlystop_progress( ...
    [140, 205], [0, 4], [140, inf], [0, 4], [true, false], tol);
assert(~improved, 'No progress should not reset early stop.');
assert(abs(state.prev_best(1) - 140) < tol, 'Feasible best objective should remain unchanged.');
assert(abs(state.prev_cv(2) - 4) < tol, 'Best infeasible CV should remain unchanged.');

fprintf('CEDA-DW early-stop logic checks passed.\n');
