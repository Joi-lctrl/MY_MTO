#!/usr/bin/env python3
import math
import re
from pathlib import Path


EXPECTED = {
    8: {"sigma_allow": 400.0, "bend_allow": 150.0, "shear_allow": 75.0},
    9: {"sigma_allow": 900.0, "bend_allow": 150.0, "shear_allow": 75.0},
}

MACROS = {
    8: ("APDL/Task8_lower.mac", "APDL/Task8_upper.mac"),
    9: ("APDL/Task9_lower.mac", "APDL/Task9_upper.mac"),
}


def expect_close(actual: float, expected: float, context: str) -> None:
    if not math.isclose(actual, expected, rel_tol=1e-9, abs_tol=1e-9):
        raise AssertionError(f"{context}: expected {expected}, got {actual}")


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    problem_path = repo_root / "APDL" / "Ship_Panel_Problem.m"
    problem_text = problem_path.read_text(encoding="utf-8")

    for task_id, expected_values in EXPECTED.items():
        for field, expected in expected_values.items():
            match = re.search(
                rf"tasks\({task_id}\)\.{field}\s*=\s*([^;]+);",
                problem_text,
            )
            if not match:
                raise AssertionError(f"Missing tasks({task_id}).{field} in {problem_path}")
            actual = float(eval(match.group(1).strip(), {"__builtins__": {}}, {}))
            expect_close(actual, expected, f"Ship_Panel_Problem task {task_id} {field}")

        for macro_rel in MACROS[task_id]:
            macro_path = repo_root / macro_rel
            text = macro_path.read_text(encoding="utf-8")
            for field, expected in expected_values.items():
                match = re.search(rf"!\s*{field}\s*=\s*([^\n\r]+)", text)
                if not match:
                    raise AssertionError(f"Missing {field} comment in {macro_rel}")
                actual = float(eval(match.group(1).strip(), {"__builtins__": {}}, {}))
                expect_close(actual, expected, f"{macro_rel} {field}")

    print("task89 allowables checks passed")


if __name__ == "__main__":
    main()
