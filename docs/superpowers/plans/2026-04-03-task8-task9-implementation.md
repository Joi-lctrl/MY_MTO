# Task8/Task9 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `task8` and `task9` as `7`-longitudinal by `9`-rib grouped ship panel tasks with `36` design variables and local slenderness constraints.

**Architecture:** Keep the existing MATLAB + APDL workflow, but generalize the ship panel definition from hard-coded `L1/L2/R` parsing into grouped symmetric section maps. Constraint handling is widened so `task8` and `task9` can return `20` constraints while the older tasks keep their current strength-only layout.

**Tech Stack:** MATLAB R2022b+, APDL macro generation, existing `Ship_Panel_Problem` / `Ship_Panel_MTSO` / `run_ansys_eval` pipeline.

---

## File Map

- Modify: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/APDL/Ship_Panel_Problem.m`
  Purpose: define `task8`/`task9`, parse `36` variables, emit grouped APDL sections, compute grouped mass.
- Modify: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/APDL/run_ansys_eval.m`
  Purpose: return task-aware constraint vectors and add slenderness constraints for grouped sections.
- Modify: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Problems/Real-world Applications/Ship Panel Grillage/Ship_Panel_MTSO.m`
  Purpose: accept variable-length constraint vectors in `evalTaskBatch`.
- Create: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/cmd_check_task89_definition.m`
  Purpose: lightweight regression script for task existence, bound size, mass evaluation, macro generation, and constraint width.

### Task 1: Add a Failing Definition Check

**Files:**
- Create: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/cmd_check_task89_definition.m`
- Test: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/cmd_check_task89_definition.m`

- [ ] **Step 1: Write the failing validation script**

```matlab
%% cmd_check_task89_definition.m
clear; clc;
cd(fileparts(mfilename('fullpath')));
addpath(genpath(pwd));

ship_prob = Ship_Panel_Problem();

assert(ship_prob.T >= 9, 'Expected Ship_Panel_Problem to expose task8 and task9.');

for task_id = [8 9]
    [lb, x0, ub] = ship_prob.get_design_space(task_id);
    assert(numel(lb) == 36, 'Task%d lb should have 36 vars.', task_id);
    assert(numel(ub) == 36, 'Task%d ub should have 36 vars.', task_id);
    assert(numel(x0) == 36, 'Task%d x0 should have 36 vars.', task_id);

    mass = ship_prob.compute_mass(x0, task_id);
    assert(isfinite(mass) && mass > 0, 'Task%d mass should be positive.', task_id);

    mac = ship_prob.generate_mac(x0, task_id);
    assert(contains(mac, 'LONG_4'), 'Task%d macro should define the 4th longitudinal group.', task_id);
    assert(contains(mac, 'RIB_5'), 'Task%d macro should define the 5th rib group.', task_id);
end

fprintf('task8/task9 definition checks passed.\n');
```

- [ ] **Step 2: Run the check to verify it fails before implementation**

Run:

```bash
matlab -batch "cd('MTO'); run('cmd_check_task89_definition.m')"
```

Expected: FAIL because `task8` and `task9` do not exist yet, or because the current model only supports `12` variables.

- [ ] **Step 3: Commit the failing test scaffold**

```bash
git add MTO/cmd_check_task89_definition.m
git commit -m "Add task8 task9 regression scaffold"
```

### Task 2: Generalize `Ship_Panel_Problem` for Grouped 36-Variable Tasks

**Files:**
- Modify: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/APDL/Ship_Panel_Problem.m`
- Test: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/cmd_check_task89_definition.m`

- [ ] **Step 1: Extend task metadata and add grouped helper methods**

Add grouped-layout helpers near `defineTasks()`:

```matlab
function [long_groups, rib_groups] = parse_grouped_sections(~, x, task)
    if task.n_long == 7 && task.n_rib == 9
        long_groups = reshape(x(1:16), 4, 4);
        rib_groups = reshape(x(17:36), 4, 5).';
        return;
    end

    long_groups = [
        x(1:4);
        x(5:8)
    ];
    rib_groups = x(9:12);
end

function long_map = get_long_group_map(~, task)
    if task.n_long == 7
        long_map = [4, 3, 2, 1, 2, 3, 4];
    elseif task.n_long == 5
        long_map = [4, 2, 1, 2, 4];
    else
        long_map = [2, 1, 2];
    end
end

function rib_map = get_rib_group_map(~, task)
    if task.n_rib == 9
        rib_map = [5, 4, 3, 2, 1, 2, 3, 4, 5];
    else
        rib_map = ones(1, task.n_rib);
    end
end
```

- [ ] **Step 2: Add `task8` and `task9` definitions**

Insert after `task7`:

```matlab
tasks(8).name = 'Task8';
tasks(8).s_long = 1600;
tasks(8).s_rib = 600;
tasks(8).q1 = 18;
tasks(8).t_plate = 12;
tasks(8).n_long = 7;
tasks(8).n_rib = 9;
tasks(8).sigma_allow = 200;
tasks(8).bend_allow = 120;
tasks(8).shear_allow = 60;
tasks(8).b_top_long = min(tasks(8).s_long / 2, tasks(8).s_rib / 6);
tasks(8).b_top_rib = min(tasks(8).s_long / 6, tasks(8).s_rib / 2);
tasks(8).lb = [repmat([250, 7, 100, 8], 1, 4), repmat([120, 6, 50, 6], 1, 5)];
tasks(8).ub = [repmat([450, 12, 200, 14], 1, 4), repmat([250, 11, 120, 12], 1, 5)];

tasks(9).name = 'Task9';
tasks(9).s_long = 2400;
tasks(9).s_rib = 800;
tasks(9).q1 = 25;
tasks(9).t_plate = 12;
tasks(9).n_long = 7;
tasks(9).n_rib = 9;
tasks(9).sigma_allow = 200;
tasks(9).bend_allow = 120;
tasks(9).shear_allow = 60;
tasks(9).b_top_long = min(tasks(9).s_long / 2, tasks(9).s_rib / 6);
tasks(9).b_top_rib = min(tasks(9).s_long / 6, tasks(9).s_rib / 2);
tasks(9).lb = tasks(8).lb;
tasks(9).ub = tasks(8).ub;
```

- [ ] **Step 3: Generalize section generation and mass calculation**

Replace the current fixed `L1/L2/R` section setup with grouped loops:

```matlab
[long_groups, rib_groups] = obj.parse_grouped_sections(x, t);
long_map = obj.get_long_group_map(t);
rib_map = obj.get_rib_group_map(t);

for g = 1:size(long_groups, 1)
    sec_id = g;
    h_web = long_groups(g, 1);
    t_web = long_groups(g, 2);
    b_bot = long_groups(g, 3);
    t_bot = long_groups(g, 4);
    h_total = t_bot + h_web + t_top;
    mac{end+1} = sprintf('SECTYPE, %d, BEAM, I, LONG_%d, 5', sec_id, g);
    mac{end+1} = sprintf('SECDATA, %g, %g, %g, %g, %g, %g', ...
        b_bot, b_top_long, h_total, t_bot, t_top, t_web);
end

rib_sec_base = size(long_groups, 1);
for g = 1:size(rib_groups, 1)
    sec_id = rib_sec_base + g;
    h_web = rib_groups(g, 1);
    t_web = rib_groups(g, 2);
    b_bot = rib_groups(g, 3);
    t_bot = rib_groups(g, 4);
    h_total = t_bot + h_web + t_top;
    mac{end+1} = sprintf('SECTYPE, %d, BEAM, I, RIB_%d, 5', sec_id, g);
    mac{end+1} = sprintf('SECDATA, %g, %g, %g, %g, %g, %g', ...
        b_bot, b_top_rib, h_total, t_bot, t_top, t_web);
end
```

Use the same grouped arrays in `compute_mass()`:

```matlab
long_areas = long_groups(:, 1) .* long_groups(:, 2) + ...
    long_groups(:, 3) .* long_groups(:, 4) + b_top_long .* t_top;
rib_areas = rib_groups(:, 1) .* rib_groups(:, 2) + ...
    rib_groups(:, 3) .* rib_groups(:, 4) + b_top_rib .* t_top;

vol = 0;
for idx = 1:numel(long_map)
    vol = vol + long_areas(long_map(idx)) * L_long;
end
for idx = 1:numel(rib_map)
    vol = vol + rib_areas(rib_map(idx)) * L_rib;
end
mass = rho * vol * 1e3;
```

- [ ] **Step 4: Run the regression script and verify it turns green for task definitions**

Run:

```bash
matlab -batch "cd('MTO'); run('cmd_check_task89_definition.m')"
```

Expected: the task existence, bound width, mass positivity, and macro section-name checks pass.

- [ ] **Step 5: Commit**

```bash
git add APDL/Ship_Panel_Problem.m MTO/cmd_check_task89_definition.m
git commit -m "Add grouped task8 task9 panel definitions"
```

### Task 3: Generalize Constraint Width and Add Slenderness Constraints

**Files:**
- Modify: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/APDL/run_ansys_eval.m`
- Modify: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Problems/Real-world Applications/Ship Panel Grillage/Ship_Panel_MTSO.m`
- Test: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/cmd_check_task89_definition.m`

- [ ] **Step 1: Add grouped slenderness helpers in `run_ansys_eval.m`**

Add a local helper:

```matlab
function con_slender = build_slenderness_constraints(x, task)
ship_prob = Ship_Panel_Problem();
[long_groups, rib_groups] = ship_prob.parse_grouped_sections(x, task);

lambda_web_max = 50;
lambda_flange_max = 10;

con_slender = [];
for g = 1:size(long_groups, 1)
    h_web = long_groups(g, 1);
    t_web = long_groups(g, 2);
    b_bot = long_groups(g, 3);
    t_bot = long_groups(g, 4);
    con_slender(end + 1) = h_web / t_web - lambda_web_max;
    con_slender(end + 1) = b_bot / t_bot - lambda_flange_max;
end

for g = 1:size(rib_groups, 1)
    h_web = rib_groups(g, 1);
    t_web = rib_groups(g, 2);
    b_bot = rib_groups(g, 3);
    t_bot = rib_groups(g, 4);
    con_slender(end + 1) = h_web / t_web - lambda_web_max;
    con_slender(end + 1) = b_bot / t_bot - lambda_flange_max;
end
end
```

- [ ] **Step 2: Replace the fixed `1x4` constraint vector**

Update the main body:

```matlab
con_strength = zeros(1, 2);
con_strength(1) = max_bend - task.bend_allow;
con_strength(2) = max_shear - task.shear_allow;

if isfield(task, 'n_long') && task.n_long == 7 && isfield(task, 'n_rib') && task.n_rib == 9
    con = [con_strength, build_slenderness_constraints(x, task)];
else
    con = [con_strength, 0, 0];
end
```

Keep solver-error fallback dynamic:

```matlab
fallback_ncon = numel(con);
obj = 1e10;
con = 100 * ones(1, fallback_ncon);
```

- [ ] **Step 3: Make `Ship_Panel_MTSO.evalTaskBatch()` task-aware**

Replace the fixed `Cons = zeros(n, 4);` pattern with lazy sizing:

```matlab
Cons = [];

for i = 1:n
    [obj, con, extra] = run_ansys_eval(x(i, :), task_id, cfg);
    if isempty(Cons)
        Cons = zeros(n, numel(con));
    end

    Objs(i, 1) = obj;
    Cons(i, :) = reshape(con, 1, []);

    if extra.error
        Objs(i, 1) = 1e10;
        Cons(i, :) = 100 * ones(1, size(Cons, 2));
    end
end
```

- [ ] **Step 4: Extend the validation script to check constraint width**

Append to `cmd_check_task89_definition.m`:

```matlab
prob = Ship_Panel_MTSO();
prob.ActiveTasks = [8 9];
prob.setTasks();

for k = 1:prob.T
    x = repmat(prob.Lb{k}, 2, 1);
    [obj, con] = prob.Fnc{k}(x);
    assert(all(size(obj) == [2, 1]), 'Task%d objective shape mismatch.', prob.ActiveTasks(k));
    assert(size(con, 2) == 20, 'Task%d should return 20 constraints.', prob.ActiveTasks(k));
end

fprintf('task8/task9 constraint-width checks passed.\n');
```

- [ ] **Step 5: Run validation**

Run:

```bash
matlab -batch "cd('MTO'); run('cmd_check_task89_definition.m')"
```

Expected: PASS for both new tasks, including `20`-constraint width in `Ship_Panel_MTSO`.

- [ ] **Step 6: Commit**

```bash
git add APDL/run_ansys_eval.m "MTO/Problems/Real-world Applications/Ship Panel Grillage/Ship_Panel_MTSO.m" MTO/cmd_check_task89_definition.m
git commit -m "Add task8 task9 slenderness constraints"
```

### Task 4: Verify APDL Layout and Batch Integration

**Files:**
- Modify: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/cmd_check_task89_definition.m`
- Test: `/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/cmd_check_task89_definition.m`

- [ ] **Step 1: Add stronger macro assertions**

Extend the script with exact count checks:

```matlab
for task_id = [8 9]
    [~, x0, ~] = ship_prob.get_design_space(task_id);
    mac = ship_prob.generate_mac(x0, task_id);

    assert(count(mac, 'SECTYPE') >= 9, 'Task%d should define 9 grouped sections.', task_id);
    assert(count(mac, 'LONG_') >= 4, 'Task%d should define 4 longitudinal groups.', task_id);
    assert(count(mac, 'RIB_') >= 5, 'Task%d should define 5 rib groups.', task_id);
end
```

- [ ] **Step 2: Add a smoke command for the command-line optimizer**

Document a minimal batch run:

```bash
matlab -batch "cd('MTO'); prob = Ship_Panel_MTSO(); prob.ActiveTasks = [8 9]; prob.N = 4; prob.maxFE = 16; prob.setTasks(); disp(prob.D);"
```

Expected: output shows `[36 36]`.

- [ ] **Step 3: Run both verification commands**

Run:

```bash
matlab -batch "cd('MTO'); run('cmd_check_task89_definition.m')"
matlab -batch "cd('MTO'); prob = Ship_Panel_MTSO(); prob.ActiveTasks = [8 9]; prob.N = 4; prob.maxFE = 16; prob.setTasks(); disp(prob.D);"
```

Expected:

- `cmd_check_task89_definition.m` prints success
- `disp(prob.D)` prints two `36`s

- [ ] **Step 4: Commit**

```bash
git add MTO/cmd_check_task89_definition.m
git commit -m "Verify task8 task9 grouped panel integration"
```

## Self-Review

- Spec coverage:
  - grouped `7x9` layout: covered in Task 2
  - `36`-variable order: covered in Task 2
  - `task8/task9` parameter additions: covered in Task 2
  - `20`-constraint output with slenderness checks: covered in Task 3
  - APDL/mass/integration validation: covered in Task 4
- Placeholder scan:
  - no `TODO` / `TBD` / “implement later” placeholders remain
- Type consistency:
  - grouped helpers use the same `long_groups/rib_groups` naming in `Ship_Panel_Problem` and `run_ansys_eval`
  - constraint width for `task8/task9` is consistently `20`

## Notes for Execution

- `parse_grouped_sections` may need `Access = public` instead of `Access = private` if `run_ansys_eval.m` calls it through a `Ship_Panel_Problem` instance.
- The first implementation keeps older tasks behavior unchanged; do not silently alter task1-task7 geometry or bounds.
- If MATLAB complains about local helper placement in a class file, move grouped helper methods into the existing `methods` block instead of adding free functions.
