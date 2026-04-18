#!/usr/bin/env python3
from pathlib import Path


def expect_contains(text: str, needle: str, context: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing `{needle}` in {context}")


def expect_not_contains(text: str, needle: str, context: str) -> None:
    if needle in text:
        raise AssertionError(f"Unexpected `{needle}` in {context}")


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    script_path = repo_root / "MTO" / "cmd_run_globalga_single.m"
    script_text = script_path.read_text(encoding="utf-8")

    expect_contains(script_text, "es('prev_best') = inf;", str(script_path))
    expect_contains(script_text, "es('prev_cv') = inf;", str(script_path))
    expect_contains(script_text, "es('prev_has_feasible') = false;", str(script_path))
    expect_contains(script_text, "[improved, state] = evaluate_ceda_dw_earlystop_progress( ...", str(script_path))
    expect_contains(script_text, "cur_best, cur_cv, prev_best, prev_cv, prev_has_feasible);", str(script_path))
    expect_contains(script_text, "es('prev_cv') = state.prev_cv;", str(script_path))
    expect_contains(script_text, "es('prev_has_feasible') = state.prev_has_feasible;", str(script_path))
    expect_not_contains(script_text, "if algo.Best{1}.Obj < es('prev_best') - 1e-6", str(script_path))

    helper_path = repo_root / "MTO" / "evaluate_ceda_dw_earlystop_progress.m"
    helper_text = helper_path.read_text(encoding="utf-8")
    expect_contains(helper_text, "Before a task becomes feasible, progress is defined by lower CV.", str(helper_path))
    expect_contains(helper_text, "After a task becomes feasible, progress is defined by lower objective.", str(helper_path))

    print("globalga early-stop logic checks passed")


if __name__ == "__main__":
    main()
