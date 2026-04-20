#!/usr/bin/env python3
from pathlib import Path


def expect_contains(text: str, needle: str, context: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing `{needle}` in {context}")


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    problem_path = repo_root / "APDL" / "Ship_Panel_Problem.m"
    problem_text = problem_path.read_text(encoding="utf-8")

    problem_needles = (
        "% Task 5: based on Task 4, n_rib=7 (add outer pair of ribs)",
        "tasks(5).s_long = tasks(4).s_long;",
        "tasks(5).s_rib = tasks(4).s_rib;",
        "tasks(5).q1 = tasks(4).q1;",
        "tasks(5).t_plate = tasks(4).t_plate;",
        "tasks(5).n_long = tasks(4).n_long;",
        "tasks(5).n_rib = 7;",
        "tasks(5).long_group_count = tasks(4).long_group_count;",
        "tasks(5).rib_group_count = 4;",
        "tasks(5).enable_group_slenderness = tasks(4).enable_group_slenderness;",
        "tasks(5).sigma_allow = tasks(4).sigma_allow;",
        "tasks(5).bend_allow = tasks(4).bend_allow;",
        "tasks(5).shear_allow = tasks(4).shear_allow;",
        "tasks(5).lambda_flange_long = tasks(4).lambda_flange_long;",
        "tasks(5).lambda_flange_rib = tasks(4).lambda_flange_rib;",
        "tasks(5).enforce_rib_web_below_long_web = tasks(4).enforce_rib_web_below_long_web;",
        "[tasks(5).b_top_long, tasks(5).b_top_rib] = ...",
        "obj.compute_task_position_eq_plate_widths(tasks(5), 5);",
        "tasks(5).lb = [tasks(4).lb, task34_rib_group_lb];",
        "tasks(5).ub = [tasks(4).ub, task34_rib_group_ub];",
        "elseif task.rib_group_count == 4 && task.n_rib == 7",
        "rib_map = [4, 3, 2, 1, 2, 3, 4];",
        "rib_sec_map = [6, 5, 4, 3, 4, 5, 6];",
        "sec_ids = 3:6;",
        "group_ids = 1:4;",
        "sec_names = {'RIB_1', 'RIB_2', 'RIB_3', 'RIB_4'};",
        "if any(task_id == [3, 4, 5, 8, 9])",
    )
    for needle in problem_needles:
        expect_contains(problem_text, needle, str(problem_path))

    expected_common = (
        "/TITLE, Task5_opt",
        "! Synced from Ship_Panel_Problem",
        "! s_long = 2400",
        "! s_rib = 1800",
        "! q1 = 16.6667",
        "! t_plate = 12",
        "! n_long = 3",
        "! n_rib = 7",
        "! sigma_allow = 220",
        "! bend_allow = 132",
        "! shear_allow = 66",
        "SECTYPE, 1, BEAM, I, LONG_C, 5",
        "SECTYPE, 2, BEAM, I, LONG_S, 5",
        "SECTYPE, 3, BEAM, I, RIB_1, 5",
        "SECTYPE, 4, BEAM, I, RIB_2, 5",
        "SECTYPE, 5, BEAM, I, RIB_3, 5",
        "SECTYPE, 6, BEAM, I, RIB_4, 5",
        "LATT, 1, , 1, , 1001, , 2",
        "LATT, 1, , 1, , 1003, , 1",
        "LATT, 1, , 1, , 1005, , 2",
        "LATT, 1, , 1, , 2001, , 6",
        "LATT, 1, , 1, , 2003, , 5",
        "LATT, 1, , 1, , 2005, , 4",
        "LATT, 1, , 1, , 2007, , 3",
        "LATT, 1, , 1, , 2009, , 4",
        "LATT, 1, , 1, , 2011, , 5",
        "LATT, 1, , 1, , 2013, , 6",
        "ESEL, S, SEC, , 3, 6",
        "SFBEAM, ALL, 1, PRES, 16.6667, 16.6667",
        "max_bend = ABS(sx_max)",
        "*STATUS,max_bend",
        "max_shear = ABS(sxy_max)",
        "*STATUS,max_shear",
    )
    expected_by_macro = {
        "APDL/task5_lower.mac": (
            "SECDATA, 150, 2400, 272, 10, 12, 5",
            "SECDATA, 150, 1800, 272, 10, 12, 5",
            "SECDATA, 150, 1200, 167, 5, 12, 5",
        ),
        "APDL/task5_upper.mac": (
            "SECDATA, 300, 2400, 582, 20, 12, 11",
            "SECDATA, 300, 1800, 582, 20, 12, 11",
            "SECDATA, 300, 1200, 323, 11, 12, 11",
        ),
    }

    for macro_rel, macro_needles in expected_by_macro.items():
        macro_text = (repo_root / macro_rel).read_text(encoding="utf-8")
        for needle in expected_common + macro_needles:
            expect_contains(macro_text, needle, macro_rel)
        if macro_text.count("LESIZE, ALL, , , 20") != 3:
            raise AssertionError(f"{macro_rel} should use 3 longitudinal mesh rows with LESIZE 20")
        if macro_text.count("LESIZE, ALL, , , 5") != 7:
            raise AssertionError(f"{macro_rel} should use 7 rib mesh rows with LESIZE 5")

    print("task5 Task4-plus-two-ribs checks passed")


if __name__ == "__main__":
    main()
