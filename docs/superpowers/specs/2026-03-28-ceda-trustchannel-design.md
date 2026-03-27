# CEDA Trust-Channel Design

## Summary

This spec proposes a paper-oriented constrained multitasking variant of CEDA-MP named `CEDA_MP_TRUSTCHANNEL`.
The core claim is that cross-task transfer should not be controlled by a single global probability. In constrained multitasking, individuals occupy different constraint stages, and transfer is only useful when the transferred knowledge matches the target task's current constraint state. The method therefore combines state-aware transfer channels with a lightweight transfer trust estimator.

## Context

The current repository already contains several CEDA extensions:

- Base global whitening-coloring transfer in [CEDA_MP.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP.m)
- Global mapping refinements in [CEDA_MP_MAP.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP_MAP.m), [CEDA_MP_OT.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP_OT.m), and [CEDA_MP_COPULA.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP_COPULA.m)
- Feasibility-split transfer channels in [CEDA_MP_FEASCHANNEL.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP_FEASCHANNEL.m) and [CEDA_MP_DUALCHANNEL.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP_DUALCHANNEL.m)
- Trigger-based adaptive transfer in [CEDA_MP_TRIGGER.m](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms/Multi-task/Constrained%20Multi-task/CEDA/CEDA_MP_TRIGGER.m)

The new method must therefore contribute more than a different mapper or one more channel split. Its novelty should come from coupling transfer modeling with constraint handling in a unified control mechanism.

## Problem Statement

Existing CEDA-style variants still assume that transfer is broadly beneficial once a source task has been chosen. Even when transfer probability is adapted, the decision is still largely global. This creates knowledge mismatch:

- feasible-stage individuals may be disrupted by aggressive external injection
- boundary-stage individuals need transfer that specifically helps feasibility transition
- strongly infeasible individuals need exploratory transfer, not refined feasible guidance

The design goal is to make transfer occur only when the mapped knowledge matches the target task's current constraint stage and has evidence of recent usefulness.

## Goals

- Introduce a mechanism-level innovation beyond mapper replacement
- Couple transfer decisions to constraint-state information
- Keep the trust model lightweight, interpretable, and ablation-friendly
- Reuse the current CEDA code structure and logging style where possible
- Preserve clear experimental comparisons against existing CEDA variants

## Non-Goals

- Replacing the full CEDA framework
- Building a heavy surrogate or deep model
- Introducing task-pair-specific manual hyperparameter tables
- Refactoring unrelated CEDA variants

## Proposed Method

### Method Name

`CEDA_MP_TRUSTCHANNEL`

### Central Idea

Pop1 transfer is no longer governed by a single `RMP1`. Instead, each target task maintains multiple constraint-state channels, and each mapped transfer candidate receives a trust score. The actual injection decision is controlled by:

`transfer probability = base state RMP x trust score`

This turns `RMP` into a prior willingness to transfer, while the final decision depends on state matching and historical effectiveness.

## Constraint-State Partition

Each task's Pop1 is partitioned into three states:

- `F`: feasible and exploitation-worthy individuals
- `B`: boundary-near individuals that are still infeasible or barely feasible and are most likely to cross into the feasible region
- `I`: strongly infeasible individuals used for broader exploration

The partition should use relative population statistics instead of fixed global thresholds.

### `F` State

Individuals with `CV <= 0` are feasible. From them, the algorithm keeps the better objective-side portion as the `F` channel. This channel represents feasible refinement.

### `B` State

The `B` channel contains the smallest-violation infeasible individuals. Two acceptable implementations are:

- top `rho_b` fraction among `CV > 0`
- individuals satisfying `CV / (median(CV_infeasible) + eps) <= tau_b`

The first implementation is simpler and should be preferred initially.

### `I` State

All remaining individuals belong to `I`. This channel preserves exploratory transfer and prevents the method from collapsing into feasible-only knowledge reuse.

### Fallback Rule

When a state subset is too small to build a stable mapping, the algorithm should fall back to a wider subset using the same direction of preference:

- for `F`, use the best available low-CV individuals
- for `B`, use the smallest-violation individuals
- for `I`, use the highest-violation portion

This keeps the method stable under early-generation scarcity.

## State-Aware Mapping

Mapping is built per state channel instead of over the entire population. The preferred alignment order is:

- `F -> F`
- `B -> B`
- `I -> I`

The first implementation should reuse the current linear `CEDA_trans` style mapping so the new contribution remains focused on control logic rather than mapper substitution.

For each source-target task pair `(k -> t)`, the algorithm builds mapped candidate pools for the active state using source and target subsets drawn from the same state channel. This keeps the transferred distribution closer to the target stage currently being optimized.

## Transfer Trust Estimator

Each mapped candidate receives a trust score in `[0, 1]`:

`trust = w1 * compat + w2 * boundary + w3 * history`

The three components are defined as follows.

### `compat`

Distribution compatibility measures whether the mapped candidate resembles the target state's current distribution. A practical first implementation is to compute a normalized distance to the target state model, such as Mahalanobis distance or whitening-space Euclidean distance, then convert it to a bounded score.

Interpretation: does the mapped point look like it belongs to the target state's region.

### `boundary`

Boundary consistency measures whether the mapped candidate moves toward a promising constraint transition region, especially for `B` and `I` channels. A simple implementation is distance-to-boundary-state-center or distance to a mixed `F/B` envelope.

Interpretation: is the candidate moving toward the target task's feasibility frontier rather than drifting into a statistically valid but useless area.

### `history`

Historical effectiveness is maintained per task pair and state channel using a low-dimensional moving statistic. It records whether recent transferred samples from state `s` on edge `(k -> t)` were useful. Utility signals should include:

- selected into the next generation
- improved `CV`
- crossed from infeasible to feasible
- improved objective after feasibility

Interpretation: has this transfer route been useful recently.

## Trust-Coupled Injection

For each state channel, define a base transfer rate:

- `RMP_F`
- `RMP_B`
- `RMP_I`

Recommended ordering:

- `RMP_B` highest
- `RMP_I` medium
- `RMP_F` lowest

The actual injection rule becomes:

`if rand < RMP_state * trust`

This preserves a compact parameterization while making transfer sensitive to both constraint stage and task relation quality.

## Algorithm Flow

Within each generation, the Pop1 workflow becomes:

1. Partition each target task population into `F`, `B`, and `I`
2. Build state-aware source and target subsets for the selected partner task
3. Construct mapped candidate pools using state-matched mapping
4. Evaluate trust for each mapped candidate
5. Inject transfer into selected parents using `RMP_state * trust`
6. Run the existing crossover, mutation, and variable swap pipeline
7. Evaluate offspring and perform selection
8. Update per-edge, per-state history statistics

Pop2 is explicitly out of scope for the first implementation and remains unchanged from the current baseline.

## Implementation Structure

The design should be implemented as a new algorithm file rather than modifying the existing baseline class in place.

Recommended new file:

- `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_TRUSTCHANNEL.m`

Recommended helper functions inside the class:

- `PartitionConstraintStates(pop, state_cfg)`
- `SelectStatePopulation(pop, state_id, state_info)`
- `BuildStateAwareMaps(dst_pop, src_pop, state_info_dst, state_info_src)`
- `EstimateTransferTrust(mapped_dec, dst_model, hist_stat, state_id)`
- `InjectByTrust(pop, mapped_pool, trust_score, base_rmp, state_id)`
- `UpdateChannelHistory(edge_stat, offspring_stat, state_id)`

The initial version should keep helper logic local to the algorithm file. Shared extraction into separate utilities is not necessary until the method is validated.

## Logging and Diagnostics

The method should record process-level evidence, following the style already used in `CEDA_MP_TRIGGER`:

- channel sizes for `F`, `B`, `I`
- per-channel transfer attempts
- per-channel accepted injections
- average trust per task pair and state
- number of transferred offspring that survive selection
- number of transferred offspring that reduce `CV`
- number of transferred offspring that cross into feasibility

These logs are needed both for debugging and for process-oriented figures in the paper.

## Experimental Plan

### Main Baselines

- `CEDA_MP`
- `CEDA_MP_TRIGGER`
- `CEDA_MP_DUALCHANNEL`
- `CEDA_MP_TRUSTCHANNEL`

If runtime budget allows, add:

- `CEDA_MP_MAP`
- `CEDA_MP_OT`

### Required Ablations

- `w/o state partition`: no `F/B/I`, trust only
- `w/o trust`: state channels remain, but transfer uses fixed `RMP`
- `w/o history`: trust uses only `compat` and `boundary`
- `B-only trust`: trust only used for the `B` channel

### Metrics to Analyze

- final optimization quality on constrained multitask benchmarks
- convergence behavior
- feasible-rate progression
- per-channel transfer effectiveness
- rate of `B/I -> F` transition caused by transfer

## Parameter Strategy

To avoid an over-engineered method, keep the new hyperparameters limited to three groups:

- state partition parameters such as `rho_f` and `rho_b`
- trust weights `w1`, `w2`, `w3`
- base state transfer rates `RMP_F`, `RMP_B`, `RMP_I`

No separate manual parameters should be introduced per task, task pair, or generation stage. Those effects should be captured by history statistics instead of explicit tuning.

## Risks and Mitigations

### Risk 1: State partition is unstable across problems

Mitigation:
Use relative rankings or ratios instead of fixed absolute `CV` thresholds.

### Risk 2: Trust duplicates the role of environmental selection

Mitigation:
Keep trust focused on pre-injection screening and validate it with process logs showing improved transfer quality before selection acts.

### Risk 3: Too many moving parts weaken the paper story

Mitigation:
Use a lightweight linear trust model and a small number of state/base-rate parameters.

## Recommendation

Implement `CEDA_MP_TRUSTCHANNEL` as a new variant that keeps the current CEDA variation pipeline and mapping backbone, while changing only the transfer control logic for Pop1. This gives the strongest paper narrative with the smallest deviation from the current code family:

- channel structure captures constraint stages
- trust controls whether mapped knowledge is injected
- history stabilizes transfer decisions without a heavy learner

This design is focused enough for a single implementation plan and directly supports baseline comparison and ablation analysis.
