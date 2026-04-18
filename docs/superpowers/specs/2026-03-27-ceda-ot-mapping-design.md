# CEDA OT Mapping Design

## Background

CEDA_MP uses a whitening-coloring transform for cross-task domain adaptation:

```
T_wc = Cs^(-1/2) * Ct^(1/2)
x_mapped = (x - mu_s) * T_wc + mu_t
```

This comes from the domain adaptation literature (CORAL, 2016). It matches second-order statistics but does not minimize any transport cost.

The best-performing variant so far is CEDA_MP_DUALCHANNEL_WEIGHTED, which separates feasible/infeasible individuals into dual channels and uses weighted statistics. Other variants (adaptive RMP, angle-guided, PCA, etc.) did not outperform the original in partial CMT testing.

## Core Idea

Replace the whitening-coloring mapping with the Optimal Transport (Bures-Wasserstein) mapping between Gaussian distributions:

```
T_ot = Cs^(-1/2) * (Cs^(1/2) * Ct * Cs^(1/2))^(1/2) * Cs^(-1/2)
x_mapped = (x - mu_s) * T_ot + mu_t
```

This is the unique linear map that minimizes the Wasserstein-2 distance between two Gaussian distributions. It preserves the relative structure (neighborhood) of the source population better than whitening-coloring by finding the minimum-displacement transformation.

## Why OT May Be Better for Constrained Optimization

- Whitening-coloring destroys source structure during the whitening step (compress to unit ball), then rebuilds target structure. Nearby feasible solutions may be scattered.
- OT finds the "shortest path" rotation/scaling, keeping nearby individuals close. This is more likely to preserve feasibility relationships after mapping.

## Ablation Layers

| Layer | Algorithm Name | Change |
|-------|---------------|--------|
| Baseline | CEDA_MP | Original |
| Layer 1 | CEDA_MP_OT | Replace mapping formula only |
| Layer 2 | CEDA_MP_OT_EMA | + Exponential moving average covariance |
| Layer 3 | CEDA_MP_OT_EMA_CL | + Distance-limited transfer |
| Control | CEDA_MP_DUALCHANNEL_WEIGHTED | Current best variant |

### Layer 1: CEDA_MP_OT

Only change: replace `CEDA_trans.m` mapping formula with OT mapping. Everything else identical to CEDA_MP (dual population, epsilon-constraint, RMP1/RMP2, GA operators, Selection_Elit).

Implementation: create `CEDA_MP_OT.m` with a new `OT_trans` method.

### Layer 2: CEDA_MP_OT_EMA (future)

Borrowed from MTES-KG / CMA-ES: instead of computing `cov()` from scratch each generation, maintain a running covariance estimate:

```
Cs = (1 - lr) * Cs_old + lr * cov(current_population)
```

This reduces estimation noise from small population sizes.

### Layer 3: CEDA_MP_OT_EMA_CL (future)

Borrowed from MTES-KG DoS strategy: if a mapped solution is too far from the target population mean, clip its displacement to a reasonable step size:

```
if norm(mapped - mu_t) > threshold
    mapped = mu_t + (mapped - mu_t) / norm(mapped - mu_t) * threshold
end
```

## Testing Plan

- Test on CMT benchmark suite (same problems used for DUALCHANNEL_WEIGHTED evaluation)
- Compare: CEDA_MP vs CEDA_MP_OT vs CEDA_MP_DUALCHANNEL_WEIGHTED
- Metric: final objective value (Obj)
- Initial testing: 1 rep for quick signal, then 5+ reps for statistical significance

## Mathematical Reference

The Bures-Wasserstein OT map between N(mu_s, Cs) and N(mu_t, Ct):

```
T = Cs^(-1/2) * (Cs^(1/2) * Ct * Cs^(1/2))^(1/2) * Cs^(-1/2)
```

Originally from: Dowson & Landau (1982), "The Frechet distance between multivariate normal distributions."

No existing evolutionary multitask optimization algorithm uses OT mapping (verified by searching the MToP codebase).
