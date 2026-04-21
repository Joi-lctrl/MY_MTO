#!/usr/bin/env python3
from pathlib import Path


def expect_contains(text: str, needle: str, context: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing `{needle}` in {context}")


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]

    algo_path = repo_root / "MTO" / "Algorithms" / "Single-task" / "Genetic Algorithm" / "GA" / "GA.m"
    if not algo_path.is_file():
        raise AssertionError(f"Missing algorithm file: {algo_path}")
    algo_text = algo_path.read_text(encoding="utf-8")
    expect_contains(algo_text, "classdef GA < Algorithm", str(algo_path))
    expect_contains(algo_text, "function run(Algo, Prob)", str(algo_path))

    script_path = repo_root / "MTO" / "cmd_run_ga_single.m"
    if not script_path.is_file():
        raise AssertionError(f"Missing GA single-run script: {script_path}")
    script_text = script_path.read_text(encoding="utf-8")
    expect_contains(script_text, "%% cmd_run_ga_single.m - 逐任务单独运行GA并保存统一格式结果", str(script_path))
    expect_contains(script_text, "clear; clear classes; clc; close all;", str(script_path))
    expect_contains(script_text, "rehash toolboxcache;", str(script_path))
    expect_contains(script_text, "active_tasks = [5];", str(script_path))
    expect_contains(script_text, "algo_names = {'GA'};", str(script_path))
    expect_contains(script_text, "algo = GA();", str(script_path))
    expect_contains(script_text, "constraints=%d", str(script_path))
    expect_contains(script_text, "fprintf('  -> Task %d\\n', actual_task);", str(script_path))
    expect_contains(script_text, "save_name = sprintf('ga_single_%s.mat', datestr(now, 'yyyymmdd_HHMMSS'));", str(script_path))

    problem_path = repo_root / "MTO" / "Problems" / "Real-world Applications" / "Ship Panel Grillage" / "Ship_Panel_MTSO.m"
    problem_text = problem_path.read_text(encoding="utf-8")
    expect_contains(problem_text, "expected_con_count = numel(get_ship_constraint_names(task_id));", str(problem_path))
    expect_contains(problem_text, "Ship_Panel_MTSO:ConstraintCountMismatch", str(problem_path))

    print("ga single setup checks passed")


if __name__ == "__main__":
    main()
