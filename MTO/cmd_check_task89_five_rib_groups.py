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
    problem_path = repo_root / "APDL" / "Ship_Panel_Problem.m"
    problem_text = problem_path.read_text(encoding="utf-8")

    expect_contains(problem_text, "% Task 8: s_long=3000, s_rib=1600, q1=15, t_plate=12, n_long=7, n_rib=9 (36 vars)", str(problem_path))
    expect_contains(problem_text, "% Task 9: s_long=3000, s_rib=2000, q1=15, t_plate=16, n_long=7, n_rib=9 (32 vars)", str(problem_path))
    expect_contains(problem_text, "tasks(8).rib_group_count = 5;", str(problem_path))
    expect_contains(problem_text, "tasks(9).rib_group_count = 4;", str(problem_path))
    expect_contains(problem_text, "task9_long_group_lb = [350, 7, 180, 12];", str(problem_path))
    expect_contains(problem_text, "task9_long_group_ub = [700, 14, 300, 22];", str(problem_path))
    expect_contains(problem_text, "tasks(9).lb = [repmat(task9_long_group_lb, 1, 4),", str(problem_path))
    expect_contains(problem_text, "repmat(task8_rib_group_lb, 1, tasks(9).rib_group_count)]", str(problem_path))
    expect_contains(problem_text, "rib_map = [4, 4, 3, 2, 1, 2, 3, 4, 4];", str(problem_path))
    expect_contains(problem_text, "rib_sec_map = [8, 8, 7, 6, 5, 6, 7, 8, 8];", str(problem_path))
    expect_contains(problem_text, "sec_ids = 5:8;", str(problem_path))

    macro_expectations = {
        "APDL/Task8_lower.mac": {"rib_range": "5, 9", "load": "15, 15", "outer_sec": "9", "forbidden_sec": None},
        "APDL/Task8_upper.mac": {"rib_range": "5, 9", "load": "15, 15", "outer_sec": "9", "forbidden_sec": None},
        "APDL/Task9_lower.mac": {"rib_range": "5, 8", "load": "15, 15", "outer_sec": "8", "forbidden_sec": "9"},
        "APDL/Task9_upper.mac": {"rib_range": "5, 8", "load": "15, 15", "outer_sec": "8", "forbidden_sec": "9"},
    }

    for macro_rel, expected in macro_expectations.items():
        macro_path = repo_root / macro_rel
        macro_text = macro_path.read_text(encoding="utf-8")
        expect_contains(macro_text, "KEYOPT, 1, 4, 2", macro_rel)
        expect_contains(macro_text, f"ESEL, S, SEC, , {expected['rib_range']}", macro_rel)
        expect_contains(macro_text, f"SFBEAM, ALL, 1, PRES, {expected['load']}", macro_rel)
        expect_contains(macro_text, f"LATT, 1, , 1, , 2001, , {expected['outer_sec']}", macro_rel)
        expect_contains(macro_text, f"LATT, 1, , 1, , 2017, , {expected['outer_sec']}", macro_rel)
        if expected["forbidden_sec"] is not None:
            expect_not_contains(macro_text, f"SECTYPE, {expected['forbidden_sec']}, BEAM, I, RIB_", macro_rel)
        if "F, ALL, FZ" in macro_text:
            raise AssertionError(f"{macro_rel} should not keep the temporary global FZ load block")
        if "FCUM, ADD" in macro_text:
            raise AssertionError(f"{macro_rel} should not keep the temporary FZ accumulation block")
        if macro_text.count("LESIZE, ALL, , , 20") != 7:
            raise AssertionError(f"{macro_rel} should use 7 longitudinal mesh rows with LESIZE 20")
        if macro_text.count("LESIZE, ALL, , , 5") != 9:
            raise AssertionError(f"{macro_rel} should use 9 rib mesh rows with LESIZE 5")

    print("task89 rib-group checks passed")


if __name__ == "__main__":
    main()
