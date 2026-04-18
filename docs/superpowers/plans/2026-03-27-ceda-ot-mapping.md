# CEDA OT Mapping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create CEDA_MP_OT — a variant of CEDA_MP that replaces the whitening-coloring domain adaptation mapping with an Optimal Transport (Bures-Wasserstein) mapping.

**Architecture:** Copy CEDA_MP.m, replace calls to `CEDA_trans` with an inline OT mapping method. The OT mapping uses `T = Cs^(-1/2) * (Cs^(1/2) * Ct * Cs^(1/2))^(1/2) * Cs^(-1/2)` instead of `Cs^(-1/2) * Ct^(1/2)`.

**Tech Stack:** MATLAB (>= R2022b), MToP platform

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_OT.m` | OT variant of CEDA_MP, self-contained with OT mapping as a method |

One file. No other files modified.

---

### Task 1: Create CEDA_MP_OT.m

**Files:**
- Create: `MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_OT.m`

- [ ] **Step 1: Create the complete CEDA_MP_OT.m file**

This is a copy of `CEDA_MP.m` with two changes:
1. All `CEDA_trans(src, dst, D)` calls replaced with `Algo.OT_trans(src, dst, D)`
2. A new method `OT_trans` added that implements the Bures-Wasserstein mapping

```matlab
classdef CEDA_MP_OT < Algorithm
% <Multi-task> <Single-objective> <Constrained>

properties (SetAccess = public)
    EC_Top = 0.2
    EC_Tc = 0.8
    EC_Cp = 5
    MuC = 2
    MuM = 5
    RMP1 = 0.15
    RMP2 = 0
end

methods
    function Parameter = getParameter(Algo)
        Parameter = {'EC_Top', num2str(Algo.EC_Top), ...
                'EC_Tc', num2str(Algo.EC_Tc), ...
                'EC_Cp', num2str(Algo.EC_Cp), ...
                'RMP1', num2str(Algo.RMP1), ...
                'RMP2', num2str(Algo.RMP2)};
    end

    function Algo = setParameter(Algo, Parameter)
        i = 1;
        Algo.EC_Top = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Tc = str2double(Parameter{i}); i = i + 1;
        Algo.EC_Cp = str2double(Parameter{i}); i = i + 1;
        Algo.RMP1 = str2double(Parameter{i}); i = i + 1;
        Algo.RMP2 = str2double(Parameter{i}); i = i + 1;
    end

    function run(Algo, Prob)
        % Initialization
        population1 = Initialization(Algo, Prob, Individual);
        population2 = Initialization(Algo, Prob, Individual);

        for t = 1:Prob.T
            n = ceil(Algo.EC_Top * length(population1{t}));
            cv_temp = [population1{t}.CV];
            [~, idx] = sort(cv_temp);
            Ep0{t} = cv_temp(idx(n));
        end

        while Algo.notTerminated(Prob, population2)
            for t = 1:Prob.T
                if Algo.FE < Algo.EC_Tc * Prob.maxFE
                    Ep = Ep0{t} * ((1 - Algo.FE / (Algo.EC_Tc * Prob.maxFE))^Algo.EC_Cp);
                else
                    Ep = 0;
                end
                CV = population1{t}.CVs; CV(CV < Ep) = 0;
                Obj = population1{t}.Objs;
                mating_pool1{t} = TournamentSelection(2, Prob.N, CV, Obj);
                mating_pool2{t} = TournamentSelection(2, Prob.N, population2{t}.CVs, population2{t}.Objs);
            end
            for t = 1:Prob.T
                k = randi(Prob.T);
                while k == t
                    k = randi(Prob.T);
                end
                offspring1 = Algo.Generation1(population1{t}, mating_pool1{t}, population1{k}(mating_pool1{k}));
                offspring2 = Algo.Generation2(population2{t}, mating_pool2{t}, population2{k}(mating_pool2{k}));
                offspring = [offspring1, offspring2];
                % Evaluation
                offspring = Algo.Evaluation(offspring, Prob, t);
                % Selection
                population1{t} = Selection_Elit(population1{t}, offspring, Ep);
                population2{t} = Selection_Elit(population2{t}, offspring, 0);
            end
        end
    end

    function offspring = Generation1(Algo, population, pool, transpop)
        population = population(pool);
        population_temp = population;
        temp_Dec = Algo.OT_trans(transpop, population_temp, transpop.Decs);
        temp_Dec2 = Algo.OT_trans(population_temp, transpop, population.Decs);
        for i = 1:length(population)
            if rand() < Algo.RMP1
                if rand() < 0.5
                    population(i).Dec = temp_Dec(randi(end), :);
                else
                    population(i).Dec = temp_Dec2(randi(end), :);
                end
            end
        end

        for i = 1:ceil(length(population) / 2)
            offspring(i) = population(i);

            p2 = i + fix(length(population) / 2);
            [offspring(i).Dec, tempDec] = GA_Crossover(population(i).Dec, population(p2).Dec, Algo.MuC);
            offspring(i).Dec = GA_Mutation(offspring(i).Dec, Algo.MuM);
            tempDec = GA_Mutation(tempDec, Algo.MuM);
            % variable swap (uniform X)
            swap_indicator = (rand(1, length(population(i).Dec)) >= 0.5);
            offspring(i).Dec(swap_indicator) = tempDec(swap_indicator);

            offspring(i).Dec(offspring(i).Dec > 1) = 1;
            offspring(i).Dec(offspring(i).Dec < 0) = 0;
        end
    end

    function offspring = Generation2(Algo, population, pool, transpop)
        population = population(pool);
        population_temp = population;
        temp_Dec = Algo.OT_trans(transpop, population_temp, transpop.Decs);
        temp_Dec2 = Algo.OT_trans(population_temp, transpop, population.Decs);
        for i = 1:length(population)
            if rand() < Algo.RMP2
                if rand() < 0.5
                    population(i).Dec = temp_Dec(randi(end), :);
                else
                    population(i).Dec = temp_Dec2(randi(end), :);
                end
            end
        end

        for i = 1:ceil(length(population) / 2)
            offspring(i) = population(i);

            p2 = i + fix(length(population) / 2);
            [offspring(i).Dec, tempDec] = GA_Crossover(population(i).Dec, population(p2).Dec, Algo.MuC);
            offspring(i).Dec = GA_Mutation(offspring(i).Dec, Algo.MuM);
            tempDec = GA_Mutation(tempDec, Algo.MuM);
            % variable swap (uniform X)
            swap_indicator = (rand(1, length(population(i).Dec)) >= 0.5);
            offspring(i).Dec(swap_indicator) = tempDec(swap_indicator);

            offspring(i).Dec(offspring(i).Dec > 1) = 1;
            offspring(i).Dec(offspring(i).Dec < 0) = 0;
        end
    end

    function trans = OT_trans(~, Ds, Dt, D)
        % Optimal Transport (Bures-Wasserstein) mapping between Gaussian distributions
        Ds_Dec = Ds.Decs;
        Dt_Dec = Dt.Decs;

        mus = mean(Ds_Dec);
        mut = mean(Dt_Dec);

        D = D - mus;
        Ds_Dec = Ds_Dec - mus;
        Dt_Dec = Dt_Dec - mut;

        dim = size(Ds_Dec, 2);
        reg = eye(dim);
        Cs = cov(Ds_Dec) + reg;
        Ct = cov(Dt_Dec) + reg;

        % Bures-Wasserstein OT map: T = Cs^(-1/2) * (Cs^(1/2) * Ct * Cs^(1/2))^(1/2) * Cs^(-1/2)
        [V, E] = eig((Cs + Cs') / 2);
        e = max(real(diag(E)), 1e-12);
        Cs_sqrt = V * diag(sqrt(e)) * V';
        Cs_invsqrt = V * diag(1 ./ sqrt(e)) * V';

        M = Cs_sqrt * Ct * Cs_sqrt;
        M = (M + M') / 2;
        [Vm, Em] = eig(M);
        em = max(real(diag(Em)), 1e-12);
        M_sqrt = Vm * diag(sqrt(em)) * Vm';

        T_ot = Cs_invsqrt * M_sqrt * Cs_invsqrt;

        trans = D * T_ot;
        trans = trans + mut;
    end
end
end
```

- [ ] **Step 2: Verify file is recognized by MToP**

Run in MATLAB:
```matlab
cd('path/to/MY_MTO/MTO')
mto
```
In the GUI, check that `CEDA-MP-OT` appears in the algorithm list under Multi-task > Constrained.
Expected: algorithm appears with correct label.

- [ ] **Step 3: Smoke test — run on one CMT problem**

Run in MATLAB:
```matlab
mto({CEDA_MP_OT}, {CMT1})
```
Expected: completes without error, produces result.

- [ ] **Step 4: Comparison test — OT vs original vs weighted**

Run in MATLAB:
```matlab
mto({CEDA_MP, CEDA_MP_OT, CEDA_MP_DUALCHANNEL_WEIGHTED}, {CMT1, CMT2, CMT3, CMT4, CMT5})
```
Expected: all three complete. Compare final Obj values.

- [ ] **Step 5: Commit**

```bash
git add "MTO/Algorithms/Multi-task/Constrained Multi-task/CEDA/CEDA_MP_OT.m"
git commit -m "Add CEDA_MP_OT: OT mapping variant of CEDA_MP"
```
