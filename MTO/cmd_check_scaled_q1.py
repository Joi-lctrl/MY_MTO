#!/usr/bin/env python3
import math
import re
from pathlib import Path


EXPECTED_Q1 = {
    1: 6.0,
    2: 25.0 / 3.0,
    3: 12.0,
    4: 50.0 / 3.0,
    5: 25.0 / 3.0,
    6: 6.0,
    7: 25.0 / 3.0,
    8: 10.0,
    9: 25.0,
}

BOUND_MACROS = {
    1: ("APDL/Task1_lower.mac", "APDL/Task1_upper.mac"),
    2: ("APDL/Task2_lower.mac.txt", "APDL/Task2_upper.mac.txt"),
    3: ("APDL/Task3_lower.mac", "APDL/Task3_upper.mac"),
    4: ("APDL/Task4_lower.mac", "APDL/Task4_upper.mac"),
    5: ("APDL/task5_lower.mac", "APDL/task5_upper.mac"),
    6: ("APDL/Task6_lower.mac", "APDL/Task6_upper.mac"),
    7: ("APDL/Task7_lower.mac", "APDL/Task7_upper.mac"),
    8: ("APDL/Task8_lower.mac", "APDL/Task8_upper.mac"),
    9: ("APDL/Task9_lower.mac", "APDL/Task9_upper.mac"),
}


def eval_scalar(expr: str) -> float:
    return float(eval(expr, {"__builtins__": {}}, {}))


def expect_close(actual: float, expected: float, context: str) -> None:
    if not math.isclose(actual, expected, rel_tol=1e-9, abs_tol=1e-9):
        raise AssertionError(f"{context}: expected {expected}, got {actual}")


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    problem_path = repo_root / "APDL" / "Ship_Panel_Problem.m"
    problem_text = problem_path.read_text(encoding="utf-8")

    for task_id, expected in EXPECTED_Q1.items():
        match = re.search(
            rf"tasks\({task_id}\)\.q1\s*=\s*([^;]+);",
            problem_text,
        )
        if not match:
            raise AssertionError(f"Missing tasks({task_id}).q1 in {problem_path}")
        actual = eval_scalar(match.group(1).strip())
        expect_close(actual, expected, f"Ship_Panel_Problem task {task_id} q1")

    for task_id, macro_pair in BOUND_MACROS.items():
        expected = EXPECTED_Q1[task_id]
        for macro_rel in macro_pair:
            macro_path = repo_root / macro_rel
            text = macro_path.read_text(encoding="utf-8")

            q1_match = re.search(r"^q1\s*=\s*([^\n\r]+)", text, re.MULTILINE)
            if q1_match:
                q1_expr = q1_match.group(1).split("!")[0].strip()
                actual = eval_scalar(q1_expr)
                expect_close(actual, expected, f"{macro_rel} q1")

            comment_match = re.search(r"!\s*q1\s*=\s*([^\n\r]+)", text)
            if comment_match:
                actual = eval_scalar(comment_match.group(1).strip())
                expect_close(actual, expected, f"{macro_rel} comment q1")

            load_match = re.search(
                r"SFBEAM,\s*ALL,\s*1,\s*PRES,\s*([^,\n\r]+),\s*([^,\n\r]+)",
                text,
            )
            if not load_match:
                raise AssertionError(f"Missing SFBEAM load in {macro_rel}")

            first = load_match.group(1).strip()
            second = load_match.group(2).strip()
            if first != "q1":
                expect_close(eval_scalar(first), expected, f"{macro_rel} SFBEAM first load")
            if second != "q1":
                expect_close(eval_scalar(second), expected, f"{macro_rel} SFBEAM second load")

    print("scaled q1 checks passed")


if __name__ == "__main__":
    main()
