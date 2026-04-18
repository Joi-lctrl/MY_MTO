# Repository Guidelines

## Project Structure & Module Organization
`MTO/` contains the MATLAB platform code. Use [`MTO/mto.m`](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/mto.m) as the entry point: calling `mto` launches the GUI, while `mto(...)` runs experiments from the command line. Core extension points live in [`MTO/Algorithms`](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Algorithms), [`MTO/Problems`](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Problems), and [`MTO/Metrics`](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/Metrics). GUI and batch orchestration are under [`MTO/GUI`](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/GUI). Documentation and figures are in [`Doc/`](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/Doc), and [`MTO/cmd_examples.m`](/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO/MTO/cmd_examples.m) is the best working usage reference.

## Build, Test, and Development Commands
This repository targets MATLAB R2022b or newer; there is no separate build step.

- `matlab -batch "cd('MTO'); mto"` opens the platform from a clean shell session.
- `matlab -batch "cd('MTO'); run('cmd_examples.m')"` runs the maintained command-line examples.
- `matlab -batch "cd('MTO'); data = mto({MFEA()},{CEC17_MTSO1_CI_HS()},'Reps',1); disp(Obj(data).TableData)"` is a minimal smoke test for algorithm, problem, and metric wiring.

## Coding Style & Naming Conventions
Follow existing MATLAB style: 4-space indentation, one class or function per `.m` file, and concise `%` comments only where behavior is non-obvious. Preserve current naming patterns such as `MFEA_VC.m` for class files and hyphenated display names derived from underscores. New algorithms/problems should inherit the existing base classes and keep the category label comment near the top because the GUI uses it for filtering.

## Testing Guidelines
There is no dedicated `tests/` suite yet, so validate changes with targeted MATLAB runs. For algorithm changes, exercise at least one single-objective and one multi-objective case when relevant. For problem or metric changes, confirm `mto(...)` completes and the corresponding metric function returns sensible `TableData` and convergence output. Prefer small `maxFE` or `Reps` values in contributor checks.

## Commit & Pull Request Guidelines
Recent history uses short imperative commit subjects such as `Refactor HV calculation` and `Fix condition for drawing Pareto`. Keep subjects under about 72 characters and make each commit a single logical change. Pull requests should describe the affected module paths, summarize validation commands, link any related issue, and include screenshots for GUI-facing changes.

## Security & Configuration Tips
Do not commit generated `.mat` experiment outputs, local MATLAB preferences, or large benchmark datasets outside the tracked examples already in the repository. Keep path handling relative to `MTO/` so both GUI and batch mode continue to work across machines.
