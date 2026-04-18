#!/usr/bin/env python3
from pathlib import Path


def expect_contains(text: str, needle: str, context: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing `{needle}` in {context}")


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]

    algo_path = repo_root / "MTO" / "Algorithms" / "Single-task" / "Differential Evolution" / "IMODE" / "IMODE.m"
    if not algo_path.is_file():
        raise AssertionError(f"Missing algorithm file: {algo_path}")
    algo_text = algo_path.read_text(encoding="utf-8")
    expect_contains(algo_text, "classdef IMODE < Algorithm", str(algo_path))
    expect_contains(algo_text, "% <Single-task> <Single-objective> <None/Constrained>", str(algo_path))
    expect_contains(algo_text, "function run(Algo, Prob)", str(algo_path))
    expect_contains(algo_text, "Initialization(Algo, Prob, Individual_DE)", str(algo_path))

    script_path = repo_root / "MTO" / "cmd_run_imode_single.m"
    if not script_path.is_file():
        raise AssertionError(f"Missing single-run script: {script_path}")
    script_text = script_path.read_text(encoding="utf-8")
    expect_contains(script_text, "%% cmd_run_imode_single.m - 逐任务单独运行IMODE并保存统一格式结果", str(script_path))
    expect_contains(script_text, "active_tasks = [8 9];", str(script_path))
    expect_contains(script_text, "algo_names = {'IMODE'};", str(script_path))
    expect_contains(script_text, "algo = IMODE();", str(script_path))
    expect_contains(script_text, "fprintf('  -> Task %d\\n', actual_task);", str(script_path))
    expect_contains(script_text, "save_name = sprintf('imode_single_%s.mat', datestr(now, 'yyyymmdd_HHMMSS'));", str(script_path))

    print("imode single setup checks passed")


if __name__ == "__main__":
    main()
