from pathlib import Path


repo = Path("/mnt/c/Users/HUAWEI/Documents/GitHub/MY_MTO")

run_ansys = (repo / "APDL" / "run_ansys_eval.m").read_text(encoding="utf-8")
assert "[job_name '*.stat']" in run_ansys, "run_ansys_eval cleanup must delete .stat files"

compare_script = (repo / "MTO" / "cmd_ship_panel_compare.m").read_text(encoding="utf-8")
assert "cfg.cleanup = cleanup_apdl;" in compare_script, "cmd_ship_panel_compare must honor cleanup_apdl"
assert "cfg.cleanup = false;" not in compare_script, "hardcoded cleanup=false should be removed"

gitignore_text = (repo / ".gitignore").read_text(encoding="utf-8")
assert "APDLRESULTS_MTO/**/*.stat" in gitignore_text, ".gitignore must ignore generated .stat files"

stat_count = sum(1 for _ in (repo / "APDLRESULTS_MTO").rglob("*.stat"))
assert stat_count == 0, f"expected no .stat files under APDLRESULTS_MTO, found {stat_count}"

print("apdl stat cleanup checks passed")
