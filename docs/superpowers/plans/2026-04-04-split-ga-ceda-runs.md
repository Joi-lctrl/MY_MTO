# Split GA and CEDA-MP-DW Runs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the current mixed `cmd_interleave` workflow into separate run scripts for multitask `CEDA_MP_DUALCHANNEL_WEIGHTED` and single-task `GA`, then add a comparison plot script that overlays the saved results by task.

**Architecture:** Keep the saved result schema aligned with the existing `cmd_interleave` output so plotting stays simple. Add one run script for multitask CEDA, one run script that loops GA across tasks one-by-one but assembles a combined result file, and one comparison plotting script that reads the two files and overlays feasible-best-objective curves on the same task-specific axes.

**Tech Stack:** MATLAB scripts, existing `Ship_Panel_MTSO` problem class, existing MTO algorithm classes, existing `gen2eva` utility.

---

### Task 1: Freeze the target data contract

**Files:**
- Modify: `MTO/cmd_interleave.m`
- Create: `docs/superpowers/plans/2026-04-04-split-ga-ceda-runs.md`

- [ ] Confirm which saved fields the new scripts must preserve for downstream plotting.
- [ ] Reuse the current feasible-best-objective storage pattern and task FE axis format instead of inventing a new file layout.

### Task 2: Add a dedicated multitask CEDA run script

**Files:**
- Create: `MTO/cmd_run_multitask_ceda_dw.m`

- [ ] Copy the relevant run/save logic from `cmd_interleave.m`, but keep only `CEDA_MP_DUALCHANNEL_WEIGHTED`.
- [ ] Preserve the same saved fields where applicable: `algo_names`, `active_tasks`, `ConvergeFeasibleObj`, `ConvergeTaskFE`, `BestFeasibleObj`, `BestDecNorm`, `BestDecReal`, `BestCV`, `Global_Seed`, `rep_seeds`, `PopulationSizeStats`.
- [ ] Save to a distinct filename prefix so multitask results are easy to identify.

### Task 3: Add a dedicated single-task GA run script

**Files:**
- Create: `MTO/cmd_run_ga_single.m`

- [ ] Loop over `active_tasks`, running `GA()` on one task at a time.
- [ ] Assemble the per-task outputs into the same cell-array layout used by the multitask result file so downstream comparison can treat both inputs uniformly.
- [ ] Save to a distinct filename prefix for GA single-task baselines.

### Task 4: Add a two-file comparison plot script

**Files:**
- Create: `MTO/cmd_plot_compare_results.m`

- [ ] Load one multitask result file and one GA-single result file.
- [ ] Validate that `active_tasks` match before plotting.
- [ ] Overlay feasible-best-objective curves for both files task-by-task using `Task FE` as the x-axis.
- [ ] Print the final feasible-best summary per task for both inputs.

### Task 5: Static verification

**Files:**
- Modify: `MTO/cmd_run_multitask_ceda_dw.m`
- Modify: `MTO/cmd_run_ga_single.m`
- Modify: `MTO/cmd_plot_compare_results.m`

- [ ] Verify the new scripts reference the expected algorithms and saved fields.
- [ ] Verify the comparison plot script prefers `ConvergeFeasibleObj` and `ConvergeTaskFE`.
- [ ] Report that MATLAB runtime verification is still pending because this environment does not provide `matlab` or `octave`.
