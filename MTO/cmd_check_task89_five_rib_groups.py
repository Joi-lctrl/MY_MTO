#!/usr/bin/env python3
from pathlib import Path


def expect_contains(text: str, needle: str, context: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing `{needle}` in {context}")


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]

    problem_path = repo_root / "APDL" / "Ship_Panel_Problem.m"
    problem_text = problem_path.read_text(encoding="utf-8")
    expect_contains(problem_text, "Variable order for tasks 8-9 (36 vars):", str(problem_path))
    expect_contains(problem_text, "% [L1(4), L2(4), L3(4), L4(4), R1(4), R2(4), R3(4), R4(4), R5(4)]", str(problem_path))
    expect_contains(problem_text, "% Task 8: s_long=1600, s_rib=1200, q1=18, t_plate=10, n_long=7, n_rib=9 (36 vars)", str(problem_path))
    expect_contains(problem_text, "% Task 9: s_long=2400, s_rib=1800, q1=25, t_plate=12, n_long=7, n_rib=9 (36 vars)", str(problem_path))
    expect_contains(problem_text, "tasks(8).rib_group_count = 5;", str(problem_path))
    expect_contains(problem_text, "tasks(9).rib_group_count = 5;", str(problem_path))
    expect_contains(problem_text, "tasks(8).lb = [repmat([250, 4, 120, 10], 1, 4), repmat([250, 4, 120, 10], 1, 5)];", str(problem_path))
    expect_contains(problem_text, "tasks(8).ub = [repmat([550, 10, 220, 20], 1, 4), repmat([550, 10, 220, 20], 1, 5)];", str(problem_path))

    definition_path = repo_root / "MTO" / "cmd_check_task89_definition.m"
    definition_text = definition_path.read_text(encoding="utf-8")
    expect_contains(definition_text, "assert(numel(lb) == 36", str(definition_path))
    expect_contains(definition_text, "assert(isequal(ship_prob.get_rib_group_map(task), [5, 4, 3, 2, 1, 2, 3, 4, 5])", str(definition_path))
    expect_contains(definition_text, "assert(isequal(ship_prob.get_rib_section_map(task), [9, 8, 7, 6, 5, 6, 7, 8, 9])", str(definition_path))
    expect_contains(definition_text, "assert(numel(con_names) == 20", str(definition_path))
    expect_contains(definition_text, "assert(all(prob.D == [36 36])", str(definition_path))
    expect_contains(definition_text, "assert(all(size(con) == [2, 20])", str(definition_path))
    expect_contains(definition_text, "assert(numel(strfind(mac, 'LESIZE, ALL, , , 20')) == 16", str(definition_path))
    expect_contains(definition_text, "assert(~contains(mac, 'LESIZE, ALL, , , 5')", str(definition_path))

    expected_latt = [9, 8, 7, 6, 5, 6, 7, 8, 9]
    for macro_rel in [
        "APDL/Task8_lower.mac",
        "APDL/Task8_upper.mac",
        "APDL/Task9_lower.mac",
        "APDL/Task9_upper.mac",
    ]:
        macro_path = repo_root / macro_rel
        macro_text = macro_path.read_text(encoding="utf-8")
        for sec_id in range(5, 10):
            expect_contains(macro_text, f"SECTYPE, {sec_id}, BEAM, I, RIB_{sec_id - 4}, 5", macro_rel)
        expect_contains(macro_text, "ESEL, S, SEC, , 5, 9", macro_rel)
        for row, sec_id in enumerate(expected_latt):
            kp_ori = 2001 + 2 * row
            expect_contains(macro_text, f"LATT, 1, , 1, , {kp_ori}, , {sec_id}", macro_rel)
        if macro_text.count("LESIZE, ALL, , , 20") != 16:
            raise AssertionError(f"{macro_rel} should use 16 mesh rows with LESIZE 20")
        if "LESIZE, ALL, , , 5" in macro_text:
            raise AssertionError(f"{macro_rel} should not keep LESIZE 5 for ribs")

    print("task89 five-rib-group checks passed")


if __name__ == "__main__":
    main()
