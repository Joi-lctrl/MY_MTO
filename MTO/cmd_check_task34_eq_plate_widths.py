#!/usr/bin/env python3
from pathlib import Path


def expect_contains(text: str, needle: str, context: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing `{needle}` in {context}")


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]

    problem_path = repo_root / "APDL" / "Ship_Panel_Problem.m"
    problem_text = problem_path.read_text(encoding="utf-8")
    expect_contains(
        problem_text,
        "[tasks(3).b_top_long, tasks(3).b_top_rib] = ...",
        str(problem_path),
    )
    expect_contains(
        problem_text,
        "obj.compute_task_position_eq_plate_widths(tasks(3), 3);",
        str(problem_path),
    )
    expect_contains(
        problem_text,
        "[tasks(4).b_top_long, tasks(4).b_top_rib] = ...",
        str(problem_path),
    )
    expect_contains(
        problem_text,
        "obj.compute_task_position_eq_plate_widths(tasks(4), 4);",
        str(problem_path),
    )

    expected = {
        "APDL/Task3_lower.mac": ("b_eq_plate_long = 1200", "b_eq_plate_rib = 800"),
        "APDL/Task3_upper.mac": ("b_eq_plate_long = 1200", "b_eq_plate_rib = 800"),
        "APDL/Task4_lower.mac": ("b_eq_plate_long = 1800", "b_eq_plate_rib = 1200"),
        "APDL/Task4_upper.mac": ("b_eq_plate_long = 1800", "b_eq_plate_rib = 1200"),
    }
    for macro_rel, needles in expected.items():
        macro_text = (repo_root / macro_rel).read_text(encoding="utf-8")
        for needle in needles:
            expect_contains(macro_text, needle, macro_rel)

    print("task34 eq plate width checks passed")


if __name__ == "__main__":
    main()
