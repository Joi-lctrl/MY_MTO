# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MToP (Multitask Optimization Platform) is a MATLAB (>= R2022b) benchmarking platform for evolutionary multitasking. It provides 50+ multitask algorithms, 50+ single-task algorithms, 200+ problem cases, and 20+ performance metrics. All code is MATLAB (.m files).

## Running the Platform

```matlab
% GUI mode
mto

% Command-line mode
mto({MFEA, MFDE}, {CMT1, CMT2})
mto({MFEA, MFDE}, {CMT1, CMT2}, 'Reps', 5, 'Par_Flag', true, 'Save_Name', 'out.mat', 'Global_Seed', 2333)
```

The entry point is `MTO/mto.m`, which calls `MTO_GUI()` with no args or `MTO_CMD()` with args. The `mto.m` function auto-adds all subdirectories to the MATLAB path via `addpath(genpath(pwd))`.

See `MTO/cmd_examples.m` for detailed usage examples (single-objective, multi-objective, parameter modification, parallel experiments).

## Architecture

### Core Class Hierarchy

- **`MTO/Algorithms/Algorithm.m`** - Abstract base class for all algorithms. Key methods:
  - `run(Algo, Prob)` - Abstract, must be implemented by subclasses
  - `Evaluation(Algo, Pop, Prob, t)` - Evaluates population on task `t`, updates FE count and global best
  - `notTerminated(Algo, Prob, Pop)` - Termination check + records results each generation
  - `getParameter()`/`setParameter()` - Parameter serialization for GUI

- **`MTO/Problems/Problem.m`** - Abstract base class for all problems. Key properties: `T` (num tasks), `N` (pop size), `M` (num objectives), `D` (dimension), `Fnc` (function handles), `Lb`/`Ub` (bounds). Abstract method: `setTasks()`.

- **`MTO/Algorithms/Utils/Individual/Individual.m`** - Base individual with `Dec`, `Obj`, `Con`, `CV` properties plus batch accessors (`Decs`, `Objs`, `CVs`). Specialized variants: `Individual_MF` (multifactorial), `Individual_DE`, `Individual_PSO`, etc.

### Label System

Every algorithm, problem, and metric file has a label comment on line 2 that declares its category:
```matlab
% <Multi-task/Many-task/Single-task> <Multi-objective/Single-objective> <None/Competitive/Constrained>
```
The GUI uses these labels to filter compatible algorithms/problems/metrics.

### Decision Variable Convention

All algorithms operate on **normalized** decision variables in [0, 1]. The `Evaluation` method in `Algorithm.m` maps them to real values via `x = Dec * (Ub - Lb) + Lb` before calling the problem's evaluation function.

### Directory Organization

- **`MTO/Algorithms/`** - Organized by: `{Multi-task, Multi-objective Multi-task, Multi-objective Single-task, Single-task}` then sub-categorized (e.g., Multi-factorial, Multi-population, Many-task, Competitive, Constrained, Differential Evolution, etc.)
- **`MTO/Algorithms/Utils/`** - Shared utilities: operators (DE/GA crossover, mutation), selection methods, initialization helpers, individual classes, ES utilities, multi-objective utilities (NDSort, CrowdingDistance, NSGA2Sort, UniformPoint)
- **`MTO/Problems/`** - Benchmark problems organized by type, plus `Base/` (Ackley, Sphere, etc.) and `Real-world Applications/`
- **`MTO/Metrics/`** - `Single-objective/` (Obj, CV, FR, etc.) and `Multi-objective/` (IGD, HV, Spread, etc.)
- **`MTO/GUI/`** - `MTO_GUI.m` (GUI app), `MTO_CMD.m` (command-line runner), `Utils/` (data processing, parallel helpers)

### Data Flow

1. `MTO_CMD` creates algorithm and problem objects, runs experiments across reps
2. Each rep: `Prob.setTasks()` -> `Algo.reset()` -> `Algo.run(Prob)` -> `Algo.getResult(Prob)`
3. Results stored as struct array `Results(prob, algo, rep)` with fields `Obj`, `CV`, `Dec`
4. `gen2eva` (in `MTO/Algorithms/Utils/DataProcess/`) converts generation-indexed results to evaluation-indexed
5. Metrics functions (e.g., `Obj()`, `IGD()`) take the `MTOData` struct and return table/convergence data

## Adding New Components

### New Algorithm
1. Create a class inheriting `Algorithm` in the appropriate `MTO/Algorithms/` subdirectory
2. Add the label comment on line 2 (e.g., `% <Multi-task> <Single-objective> <None/Constrained>`)
3. Implement `run(Algo, Prob)` using the pattern: initialize population -> loop with `Algo.notTerminated(Prob, Pop)` -> generate offspring -> `Algo.Evaluation(offspring, Prob, t)` -> selection
4. Override `getParameter()`/`setParameter()` if the algorithm has tunable parameters
5. Reference implementations: `MFEA.m` (single-obj multifactorial), `MO_MFEA.m` (multi-obj)

### New Problem
1. Create a class inheriting `Problem` in the appropriate `MTO/Problems/` subdirectory
2. Add the label comment on line 2
3. Implement `setTasks()` which sets `T`, `D`, `M`, `Fnc`, `Lb`, `Ub`, `maxFE`

### New Metric
Metrics are standalone functions (not classes) in `MTO/Metrics/`. They take `MTOData` and return a struct with `TableData`, `ConvergeData`, `RowName`, `ColumnName`, and `Metric` (either `'Min'` or `'Max'`).

## Naming Convention

MATLAB class names use underscores (e.g., `MFEA_II`), but display names use hyphens (e.g., `MFEA-II`). The `Algorithm` constructor auto-converts via `strrep(class(Algo), '_', '-')`.

## Key Files

- `MTO/mto.m` - Entry point
- `MTO/GUI/MTO_CMD.m` - Command-line experiment runner with parallel support
- `MTO/GUI/MTO_GUI.m` - GUI application
- `MTO/GUI/Utils/MakeGenEqual.m` - Normalizes convergence data lengths across runs
- `MTO/Algorithms/Utils/DataProcess/gen2eva.m` - Generation-to-evaluation data conversion
- `MTO/Algorithms/Utils/Initialization/Initialization.m` - Standard population initialization
- `MTO/Algorithms/Utils/Initialization/Initialization_MF.m` - Multifactorial initialization
