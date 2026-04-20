#!/usr/bin/env python3
import re
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
    expect_contains(problem_text, "% Task 8: s_long=3000, s_rib=1600, q1=10, t_plate=12, n_long=7, n_rib=9 (36 vars)", str(problem_path))
    expect_contains(problem_text, "% Task 9: s_long=3000, s_rib=2000, q1=25, t_plate=14, n_long=7, n_rib=9 (36 vars)", str(problem_path))
    expect_contains(problem_text, "tasks(8).t_plate = 12;", str(problem_path))
    expect_contains(problem_text, "tasks(9).t_plate = 14;", str(problem_path))
    expect_contains(problem_text, "tasks(8).rib_group_count = 5;", str(problem_path))
    expect_contains(problem_text, "tasks(9).rib_group_count = 5;", str(problem_path))
    expect_contains(problem_text, "tasks(8).lambda_flange_long = 15;", str(problem_path))
    expect_contains(problem_text, "tasks(8).lambda_flange_rib = 15;", str(problem_path))
    expect_contains(problem_text, "tasks(9).lambda_flange_long = tasks(8).lambda_flange_long;", str(problem_path))
    expect_contains(problem_text, "tasks(9).lambda_flange_rib = tasks(8).lambda_flange_rib;", str(problem_path))
    expect_contains(problem_text, "task8_long_group_lb = [350, 6, 450, 12];", str(problem_path))
    expect_contains(problem_text, "task8_long_group_ub = [650, 12, 600, 22];", str(problem_path))
    expect_contains(problem_text, "task8_rib_group_lb = [200, 6, 350, 6];", str(problem_path))
    expect_contains(problem_text, "task8_rib_group_ub = [350, 12, 500, 12];", str(problem_path))

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
        expect_contains(macro_text, "KEYOPT, 1, 4, 2", macro_rel)
        expect_contains(macro_text, "! s_long = 3000", macro_rel) if "Task8" in macro_rel else None
        expect_contains(macro_text, "! s_long = 3000", macro_rel) if "Task9" in macro_rel else None
        expect_contains(macro_text, "! t_plate = 12", macro_rel) if "Task8" in macro_rel else None
        expect_contains(macro_text, "! t_plate = 14", macro_rel) if "Task9" in macro_rel else None
        if macro_rel.endswith("lower.mac"):
            expect_contains(macro_text, "SECDATA, 450, 2666.67, 362, 12, 12, 6", macro_rel) if "Task8" in macro_rel else None
            expect_contains(macro_text, "SECDATA, 450, 2250, 362, 12, 12, 6", macro_rel) if "Task8" in macro_rel else None
            expect_contains(macro_text, "SECDATA, 150, 3000, 274, 10, 14, 5", macro_rel) if "Task9" in macro_rel else None
            expect_contains(macro_text, "SECDATA, 150, 2250, 274, 10, 14, 5", macro_rel) if "Task9" in macro_rel else None
            expect_contains(macro_text, "SECDATA, 350, 1600, 212, 6, 12, 6", macro_rel) if "Task8" in macro_rel else None
            expect_contains(macro_text, "SECDATA, 150, 2000, 169, 5, 14, 5", macro_rel) if "Task9" in macro_rel else None
        else:
            expect_contains(macro_text, "SECDATA, 600, 2666.67, 662, 22, 12, 12", macro_rel) if "Task8" in macro_rel else None
            expect_contains(macro_text, "SECDATA, 600, 2250, 662, 22, 12, 12", macro_rel) if "Task8" in macro_rel else None
            expect_contains(macro_text, "SECDATA, 300, 3000, 584, 20, 14, 11", macro_rel) if "Task9" in macro_rel else None
            expect_contains(macro_text, "SECDATA, 300, 2250, 584, 20, 14, 11", macro_rel) if "Task9" in macro_rel else None
            expect_contains(macro_text, "SECDATA, 500, 1600, 362, 12, 12, 12", macro_rel) if "Task8" in macro_rel else None
            expect_contains(macro_text, "SECDATA, 300, 2000, 325, 11, 14, 11", macro_rel) if "Task9" in macro_rel else None
        for sec_id in range(5, 10):
            expect_contains(macro_text, f"SECTYPE, {sec_id}, BEAM, I, RIB_{sec_id - 4}, 5", macro_rel)
        expect_contains(macro_text, "ESEL, S, SEC, , 5, 9", macro_rel)
        for row, sec_id in enumerate(expected_latt):
            kp_ori = 2001 + 2 * row
            expect_contains(macro_text, f"LATT, 1, , 1, , {kp_ori}, , {sec_id}", macro_rel)
        if re.search(r"^LATT, 1, , 1, , 2\d+, 2\d+,", macro_text, re.MULTILINE):
            raise AssertionError(f"{macro_rel} should not use segmented rib LATT with both KB and KE")
        if macro_text.count("LESIZE, ALL, , , 20") != 16:
            raise AssertionError(f"{macro_rel} should use 16 mesh rows with LESIZE 20")
        if "LESIZE, ALL, , , 5" in macro_text:
            raise AssertionError(f"{macro_rel} should not keep LESIZE 5 for ribs")

    print("task89 five-rib-group checks passed")


if __name__ == "__main__":
    main()
