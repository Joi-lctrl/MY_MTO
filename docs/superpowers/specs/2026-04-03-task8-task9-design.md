# Task8/Task9 Ship Panel Extension Design

**Date:** 2026-04-03

**Goal:** Extend the ship panel grillage problem with two new large-layout tasks (`task8`, `task9`) that model a `7`-longitudinal by `9`-transverse grillage using grouped section variables and additional local slenderness constraints.

## Background

The current ship panel problem supports:

- `3` longitudinals with `1 + 2` grouped longitudinal sections
- `5` longitudinals with an outer pair reusing the inner-side section
- a single rib section group reused across all ribs

This is sufficient for `task1`-`task7`, but not for the requested `7`-longitudinal and `9`-rib layout. Adding `task8` and `task9` requires grouped section mapping for both directions and a larger design vector.

The repository currently uses strength constraints only. The new tasks keep that strength-based evaluation flow and add section proportion constraints.

## Task Definition

### Shared Layout

Both new tasks use:

- `n_long = 7`
- `n_rib = 9`
- `36` design variables total

### Longitudinal Grouping

The `7` longitudinals are grouped into `4` symmetric section families:

- `L1`: center longitudinal
- `L2`: inner pair
- `L3`: middle pair
- `L4`: outer pair

Expanded physical order across the width:

`[L4, L3, L2, L1, L2, L3, L4]`

Each longitudinal group has `4` variables:

- `h_web`
- `t_web`
- `b_bot`
- `t_bot`

Longitudinal variables therefore use `16` dimensions:

`[L1(4), L2(4), L3(4), L4(4)]`

### Rib Grouping

The `9` ribs are grouped into `5` symmetric section families:

- `R1`: center rib
- `R2`: first inner pair
- `R3`: second inner pair
- `R4`: third inner pair
- `R5`: outer pair

Expanded physical order along the length:

`[R5, R4, R3, R2, R1, R2, R3, R4, R5]`

Each rib group has `4` variables:

- `h_web`
- `t_web`
- `b_bot`
- `t_bot`

Rib variables therefore use `20` dimensions:

`[R1(4), R2(4), R3(4), R4(4), R5(4)]`

### Complete Variable Order

The full `36`-variable order is fixed as:

`[L1(4), L2(4), L3(4), L4(4), R1(4), R2(4), R3(4), R4(4), R5(4)]`

or explicitly:

`[`
`h_web_L1, t_web_L1, b_bot_L1, t_bot_L1,`
`h_web_L2, t_web_L2, b_bot_L2, t_bot_L2,`
`h_web_L3, t_web_L3, b_bot_L3, t_bot_L3,`
`h_web_L4, t_web_L4, b_bot_L4, t_bot_L4,`
`h_web_R1, t_web_R1, b_bot_R1, t_bot_R1,`
`h_web_R2, t_web_R2, b_bot_R2, t_bot_R2,`
`h_web_R3, t_web_R3, b_bot_R3, t_bot_R3,`
`h_web_R4, t_web_R4, b_bot_R4, t_bot_R4,`
`h_web_R5, t_web_R5, b_bot_R5, t_bot_R5`
`]`

## Proposed Task Parameters

The user requested that `task9` differs from `task8` mainly by larger overall dimensions and larger load. Since exact baseline numbers were not provided, the first implementation uses practical values consistent with existing tasks.

### Task8

- `name = 'Task8'`
- `s_long = 1600`
- `s_rib = 600`
- `q1 = 18`
- `t_plate = 12`
- `n_long = 7`
- `n_rib = 9`
- `sigma_allow = 200`
- `bend_allow = 120`
- `shear_allow = 60`

Derived top flange widths follow the existing rule:

- `b_top_long = min(s_long/2, s_rib/6)`
- `b_top_rib = min(s_long/6, s_rib/2)`

### Task9

- `name = 'Task9'`
- `s_long = 2400`
- `s_rib = 800`
- `q1 = 25`
- `t_plate = 12`
- `n_long = 7`
- `n_rib = 9`
- `sigma_allow = 200`
- `bend_allow = 120`
- `shear_allow = 60`

Derived top flange widths use the same rule:

- `b_top_long = min(s_long/2, s_rib/6)`
- `b_top_rib = min(s_long/6, s_rib/2)`

## Variable Bounds

The first implementation keeps grouped bounds simple and consistent with the current task family:

- every longitudinal group uses the current `task3` longitudinal bounds
- every rib group uses the current `task3` rib bounds

That gives:

- longitudinal group lower bound: `[250, 7, 100, 8]`
- longitudinal group upper bound: `[450, 12, 200, 14]`
- rib group lower bound: `[120, 6, 50, 6]`
- rib group upper bound: `[250, 11, 120, 12]`

Expanded to `36` variables:

- `lb = [L1_lb, L2_lb, L3_lb, L4_lb, R1_lb, R2_lb, R3_lb, R4_lb, R5_lb]`
- `ub = [L1_ub, L2_ub, L3_ub, L4_ub, R1_ub, R2_ub, R3_ub, R4_ub, R5_ub]`

## Constraint Design

### Existing Strength Constraints

The current FEA-based strength checks remain:

- bending stress violation
- shear stress violation

### New Section Slenderness Constraints

The user selected the more common local proportion constraints instead of a direct `web-height / flange-width` rule.

Each section group receives two local slenderness constraints:

1. web slenderness

`h_web / t_web <= lambda_web_max`

2. flange slenderness

`b_bot / t_bot <= lambda_flange_max`

The first implementation uses these fixed limits:

- `lambda_web_max = 50`
- `lambda_flange_max = 10`

These are engineering starter values, chosen to behave like practical I-section local slenderness limits and to avoid unconstrained thin-web/thin-flange sections. They can be replaced later if the advisor provides a target code rule.

### Constraint Count

For `task8` and `task9`:

- `2` strength constraints
- `9` section groups × `2` slenderness constraints = `18`

Total:

- `20` constraints per task

### Constraint Ordering

The constraint vector order for `task8` and `task9` is fixed as:

`[`
`bend_violation,`
`shear_violation,`
`web_slender_L1, flange_slender_L1,`
`web_slender_L2, flange_slender_L2,`
`web_slender_L3, flange_slender_L3,`
`web_slender_L4, flange_slender_L4,`
`web_slender_R1, flange_slender_R1,`
`web_slender_R2, flange_slender_R2,`
`web_slender_R3, flange_slender_R3,`
`web_slender_R4, flange_slender_R4,`
`web_slender_R5, flange_slender_R5`
`]`

All constraints continue using:

`g(x) <= 0`

## Required Code Changes

### 1. `APDL/Ship_Panel_Problem.m`

This file needs the largest update.

Required changes:

- increase total task count from `7` to `9`
- add `task8` and `task9`
- document the `36`-variable order
- generalize section parsing so grouped sections are not hard-coded to `L1/L2/R`
- generalize section definition generation for `4` longitudinal section types and `5` rib section types
- generalize section assignment maps for symmetric grouped layout
- generalize mass computation for grouped longitudinals and grouped ribs

The preferred design is to move from special-case parsing to grouped arrays:

- longitudinal groups stored as `4 x 4`
- rib groups stored as `5 x 4`
- physical member-to-group mapping vectors

### 2. `APDL/run_ansys_eval.m`

This file currently assumes a fixed `4`-constraint output shape and should be generalized.

Required changes:

- keep strength constraints
- add grouped section slenderness checks for `task8` and `task9`
- allow constraint vector length to vary by task
- extend `extra` only as needed, but avoid forcing fixed-width geometric-ordering fields for the new tasks

### 3. `MTO/Problems/Real-world Applications/Ship Panel Grillage/Ship_Panel_MTSO.m`

This file currently preallocates:

`Cons = zeros(n, 4);`

That must become task-aware so `task8` and `task9` can return `20` constraints.

Required changes:

- query the first evaluated constraint length and size `Cons` accordingly
- keep the existing penalty behavior for solver failures

## Non-Goals

This change does not attempt to:

- add plate buckling or frequency constraints
- introduce classification-society-specific ship rules
- redesign the overall optimization workflow
- refactor the whole APDL modeling stack beyond what is needed for grouped section support

## Risks

### Risk 1: Hard-coded assumptions on section count

The current APDL generator assumes at most:

- `4` longitudinal section IDs
- `1` rib section type

That must be checked carefully in line creation, `LATT`, and `SECTYPE/SECDATA` emission.

### Risk 2: Constraint width mismatch

If `run_ansys_eval.m` returns longer vectors but `Ship_Panel_MTSO.m` still allocates `4` columns, evaluation will fail.

### Risk 3: Bounds too permissive or too restrictive

The starter bounds are intentionally conservative and reused from the current task family. They may need adjustment after the first few runs.

## Verification Plan

At minimum, implementation verification should cover:

- `Ship_Panel_Problem().Tasks(8)` and `.Tasks(9)` exist and have `36`-length bounds
- `generate_mac(..., 8)` and `generate_mac(..., 9)` produce macros with:
  - `7` longitudinal rows
  - `9` rib rows
  - `4` longitudinal section groups
  - `5` rib section groups
- `compute_mass(..., 8/9)` runs without indexing errors
- `run_ansys_eval(..., 8/9)` returns a `1 x 20` constraint vector when ANSYS succeeds
- `Ship_Panel_MTSO.evalTaskBatch(..., 8/9)` accepts the longer constraint vector

## Open Assumptions Locked For First Implementation

These assumptions were accepted for the first implementation:

- the symmetric grouping interpretation is correct
- `task9` differs from `task8` by larger `s_long`, larger `s_rib`, and larger `q1`
- top flange widths continue using the current geometry-derived rule
- `task8` base parameters may be chosen pragmatically
- local slenderness constraints use:
  - `h_web / t_web <= 50`
  - `b_bot / t_bot <= 10`

If later guidance from the advisor changes any of these values, they can be updated without changing the grouped-layout architecture.
