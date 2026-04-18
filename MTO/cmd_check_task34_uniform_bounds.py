#!/usr/bin/env python3
from pathlib import Path


def expect_contains(text: str, needle: str, context: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing `{needle}` in {context}")


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    problem_path = repo_root / "APDL" / "Ship_Panel_Problem.m"
    problem_text = problem_path.read_text(encoding="utf-8")

    expect_contains(problem_text, "task34_long_group_lb = [250, 5, 150, 10];", str(problem_path))
    expect_contains(problem_text, "task34_long_group_ub = [550, 11, 300, 20];", str(problem_path))
    expect_contains(problem_text, "task34_rib_group_lb = [150, 5, 150, 5];", str(problem_path))
    expect_contains(problem_text, "task34_rib_group_ub = [300, 11, 300, 11];", str(problem_path))
    expect_contains(problem_text, "tasks(3).rib_group_count = 3;", str(problem_path))
    expect_contains(problem_text, "tasks(4).rib_group_count = 3;", str(problem_path))
    expect_contains(
        problem_text,
        "tasks(3).lb = [repmat(task34_long_group_lb, 1, 2), repmat(task34_rib_group_lb, 1, 3)];",
        str(problem_path),
    )
    expect_contains(
        problem_text,
        "tasks(3).ub = [repmat(task34_long_group_ub, 1, 2), repmat(task34_rib_group_ub, 1, 3)];",
        str(problem_path),
    )
    expect_contains(problem_text, "tasks(3).sigma_allow = 110;", str(problem_path))
    expect_contains(problem_text, "tasks(3).bend_allow = 66;", str(problem_path))
    expect_contains(problem_text, "tasks(3).shear_allow = 33;", str(problem_path))
    expect_contains(problem_text, "tasks(3).lambda_flange_long = 15;", str(problem_path))
    expect_contains(problem_text, "tasks(3).lambda_flange_rib = 15;", str(problem_path))
    expect_contains(problem_text, "tasks(3).enforce_rib_web_below_long_web = false;", str(problem_path))
    expect_contains(problem_text, "tasks(4).lb = tasks(3).lb;", str(problem_path))
    expect_contains(problem_text, "tasks(4).ub = tasks(3).ub;", str(problem_path))
    expect_contains(problem_text, "tasks(4).sigma_allow = 220;", str(problem_path))
    expect_contains(problem_text, "tasks(4).bend_allow = 132;", str(problem_path))
    expect_contains(problem_text, "tasks(4).shear_allow = 66;", str(problem_path))
    expect_contains(problem_text, "tasks(4).lambda_flange_long = tasks(3).lambda_flange_long;", str(problem_path))
    expect_contains(problem_text, "tasks(4).lambda_flange_rib = tasks(3).lambda_flange_rib;", str(problem_path))
    expect_contains(problem_text, "tasks(4).enforce_rib_web_below_long_web = tasks(3).enforce_rib_web_below_long_web;", str(problem_path))

    eval_path = repo_root / "APDL" / "run_ansys_eval.m"
    eval_text = eval_path.read_text(encoding="utf-8")
    expect_contains(
        eval_text,
        "ncon = 2 + 2 * (long_group_count + rib_group_count) + count_additional_group_constraints(task);",
        str(eval_path),
    )
    expect_contains(
        eval_text,
        "con = [con_strength, build_group_constraints(x, task)];",
        str(eval_path),
    )
    expect_contains(
        eval_text,
        "lambda_flange_long = resolve_slenderness_limit(task, 'lambda_flange_long', 10);",
        str(eval_path),
    )
    expect_contains(
        eval_text,
        "lambda_flange_rib = resolve_slenderness_limit(task, 'lambda_flange_rib', 10);",
        str(eval_path),
    )

    sensitivity_path = repo_root / "MTO" / "cmd_task3_single_var_sensitivity.m"
    sensitivity_text = sensitivity_path.read_text(encoding="utf-8")
    expect_contains(
        sensitivity_text,
        "lambda_flange_long = resolve_slenderness_limit(task, 'lambda_flange_long', 10);",
        str(sensitivity_path),
    )
    expect_contains(
        sensitivity_text,
        "lambda_flange_rib = resolve_slenderness_limit(task, 'lambda_flange_rib', 10);",
        str(sensitivity_path),
    )

    expected_macros = {
        "APDL/Task3_lower.mac": (
            "h_web_L1 = 250",
            "t_web_L1 = 5",
            "b_bot_L1 = 150",
            "t_bot_L1 = 10",
            "h_web_L2 = 250",
            "t_web_L2 = 5",
            "b_bot_L2 = 150",
            "t_bot_L2 = 10",
            "h_web_R1 = 150",
            "t_web_R1 = 5",
            "b_bot_R1 = 150",
            "t_bot_R1 = 5",
            "h_web_R2 = 150",
            "t_web_R2 = 5",
            "b_bot_R2 = 150",
            "t_bot_R2 = 5",
            "h_web_R3 = 150",
            "t_web_R3 = 5",
            "b_bot_R3 = 150",
            "t_bot_R3 = 5",
            "sigma_allow = 110",
            "bend_allow = 66",
            "shear_allow = 33",
            "SECTYPE, 3, BEAM, I, RIB_C, 5",
            "SECTYPE, 4, BEAM, I, RIB_S, 5",
            "SECTYPE, 5, BEAM, I, RIB_O, 5",
            "ESEL, S, SEC, , 3, 5",
            "n_div_rib = 5",
        ),
        "APDL/Task3_upper.mac": (
            "h_web_L1 = 550",
            "t_web_L1 = 11",
            "b_bot_L1 = 300",
            "t_bot_L1 = 20",
            "h_web_L2 = 550",
            "t_web_L2 = 11",
            "b_bot_L2 = 300",
            "t_bot_L2 = 20",
            "h_web_R1 = 300",
            "t_web_R1 = 11",
            "b_bot_R1 = 300",
            "t_bot_R1 = 11",
            "h_web_R2 = 300",
            "t_web_R2 = 11",
            "b_bot_R2 = 300",
            "t_bot_R2 = 11",
            "h_web_R3 = 300",
            "t_web_R3 = 11",
            "b_bot_R3 = 300",
            "t_bot_R3 = 11",
            "sigma_allow = 110",
            "bend_allow = 66",
            "shear_allow = 33",
            "SECTYPE, 3, BEAM, I, RIB_C, 5",
            "SECTYPE, 4, BEAM, I, RIB_S, 5",
            "SECTYPE, 5, BEAM, I, RIB_O, 5",
            "ESEL, S, SEC, , 3, 5",
            "n_div_rib = 5",
        ),
        "APDL/Task4_lower.mac": (
            "h_web_L1 = 250",
            "t_web_L1 = 5",
            "b_bot_L1 = 150",
            "t_bot_L1 = 10",
            "h_web_L2 = 250",
            "t_web_L2 = 5",
            "b_bot_L2 = 150",
            "t_bot_L2 = 10",
            "h_web_R1 = 150",
            "t_web_R1 = 5",
            "b_bot_R1 = 150",
            "t_bot_R1 = 5",
            "h_web_R2 = 150",
            "t_web_R2 = 5",
            "b_bot_R2 = 150",
            "t_bot_R2 = 5",
            "h_web_R3 = 150",
            "t_web_R3 = 5",
            "b_bot_R3 = 150",
            "t_bot_R3 = 5",
            "sigma_allow = 220",
            "bend_allow = 132",
            "shear_allow = 66",
            "SECTYPE, 3, BEAM, I, RIB_C, 5",
            "SECTYPE, 4, BEAM, I, RIB_S, 5",
            "SECTYPE, 5, BEAM, I, RIB_O, 5",
            "ESEL, S, SEC, , 3, 5",
            "n_div_rib = 5",
        ),
        "APDL/Task4_upper.mac": (
            "h_web_L1 = 550",
            "t_web_L1 = 11",
            "b_bot_L1 = 300",
            "t_bot_L1 = 20",
            "h_web_L2 = 550",
            "t_web_L2 = 11",
            "b_bot_L2 = 300",
            "t_bot_L2 = 20",
            "h_web_R1 = 300",
            "t_web_R1 = 11",
            "b_bot_R1 = 300",
            "t_bot_R1 = 11",
            "h_web_R2 = 300",
            "t_web_R2 = 11",
            "b_bot_R2 = 300",
            "t_bot_R2 = 11",
            "h_web_R3 = 300",
            "t_web_R3 = 11",
            "b_bot_R3 = 300",
            "t_bot_R3 = 11",
            "sigma_allow = 220",
            "bend_allow = 132",
            "shear_allow = 66",
            "SECTYPE, 3, BEAM, I, RIB_C, 5",
            "SECTYPE, 4, BEAM, I, RIB_S, 5",
            "SECTYPE, 5, BEAM, I, RIB_O, 5",
            "ESEL, S, SEC, , 3, 5",
            "n_div_rib = 5",
        ),
    }
    for macro_rel, needles in expected_macros.items():
        macro_text = (repo_root / macro_rel).read_text(encoding="utf-8")
        for needle in needles:
            expect_contains(macro_text, needle, macro_rel)

    print("task34 uniform bound checks passed")


if __name__ == "__main__":
    main()
