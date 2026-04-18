# cmd_interleave Runtime Course Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing `cmd-interleave-course` into a runtime-trace course that shows how `cmd_interleave.m` actually executes across files and explains MATLAB basics inline.

**Architecture:** Keep modules `01` through `05` as overview content. Rewrite modules `06` through `10` into execution-trace modules built from small runtime cards. Reuse the existing course shell and mostly reuse existing CSS classes, adding only minimal styling if the current components cannot clearly show current line, next jump, return point, and MATLAB meaning.

**Tech Stack:** Static HTML, existing `styles.css`, existing `main.js`, shell assembly via `cmd-interleave-course/build.sh`, static validation via `rg` and `bash`.

---

## File Map

**Modify**
- `cmd-interleave-course/_base.html`
- `cmd-interleave-course/modules/06-cmd-setup-line-by-line.html`
- `cmd-interleave-course/modules/07-cmd-loop-line-by-line.html`
- `cmd-interleave-course/modules/08-algorithm-bookkeeping-line-by-line.html`
- `cmd-interleave-course/modules/09-evaluation-and-problem-line-by-line.html`
- `cmd-interleave-course/modules/10-run-ansys-line-by-line.html`

**Optional Modify**
- `cmd-interleave-course/styles.css`
- `cmd-interleave-course/main.js`

**Build Output**
- `cmd-interleave-course/index.html`

**Reference Inputs**
- `docs/superpowers/specs/2026-04-01-cmd-interleave-runtime-course-design.md`
- `MTO/cmd_interleave.m`
- `MTO/Algorithms/Algorithm.m`
- `MTO/Problems/Real-world Applications/Ship Panel Grillage/Ship_Panel_MTSO.m`
- `APDL/run_ansys_eval.m`

### Task 1: Establish the Runtime-Trace Shell

**Files:**
- Modify: `cmd-interleave-course/_base.html`
- Optional Modify: `cmd-interleave-course/styles.css`
- Test: `cmd-interleave-course/index.html`

- [ ] **Step 1: Verify the current built page does not yet expose the requested runtime-trace labels**

Run:
```bash
rg -n "Next jump|Return point|MATLAB meaning|Current line" cmd-interleave-course/index.html
```

Expected:
```text
No matches
```

- [ ] **Step 2: Update the course shell so modules `06` through `10` are explicitly runtime-trace modules**

Write:
```html
<button class="nav-dot" data-target="module-6" data-tooltip="Runtime Start" role="tab" aria-label="Module 6: Runtime Start"></button>
<button class="nav-dot" data-target="module-7" data-tooltip="Runtime Loop" role="tab" aria-label="Module 7: Runtime Loop"></button>
<button class="nav-dot" data-target="module-8" data-tooltip="Runtime Bookkeeping" role="tab" aria-label="Module 8: Runtime Bookkeeping"></button>
<button class="nav-dot" data-target="module-9" data-tooltip="Runtime Evaluation" role="tab" aria-label="Module 9: Runtime Evaluation"></button>
<button class="nav-dot" data-target="module-10" data-tooltip="Runtime Solver" role="tab" aria-label="Module 10: Runtime Solver"></button>
```

- [ ] **Step 3: Add a reusable runtime-card markup pattern if existing classes are not enough**

Write:
```html
<div class="pattern-card runtime-card animate-in">
  <div class="pattern-icon">R</div>
  <h4 class="pattern-title">Current line</h4>
  <p class="pattern-desc"><code>cmd_interleave.m:L97</code></p>
  <h4 class="pattern-title">Next jump</h4>
  <p class="pattern-desc">No jump, remain in <code>cmd_interleave.m</code></p>
  <h4 class="pattern-title">Return point</h4>
  <p class="pattern-desc">Continue at <code>cmd_interleave.m:L98</code></p>
</div>
```

- [ ] **Step 4: If runtime cards need style separation, add only minimal CSS**

Write:
```css
.runtime-card code { word-break: break-word; }
.runtime-card .pattern-title { margin-top: var(--space-3); }
.runtime-card .pattern-title:first-of-type { margin-top: 0; }
```

- [ ] **Step 5: Rebuild to verify the shell still assembles**

Run:
```bash
cd cmd-interleave-course && bash build.sh
```

Expected:
```text
Built index.html — open it in your browser.
```

- [ ] **Step 6: Commit**

```bash
git add cmd-interleave-course/_base.html cmd-interleave-course/styles.css
git commit -m "Refine runtime course shell"
```

### Task 2: Rewrite Module 06 as Runtime Start

**Files:**
- Modify: `cmd-interleave-course/modules/06-cmd-setup-line-by-line.html`
- Test: `cmd-interleave-course/index.html`

- [ ] **Step 1: Verify the current module does not yet expose runtime jump language**

Run:
```bash
rg -n "Ship_Panel_MTSO.setTasks|Return point|Current line" cmd-interleave-course/modules/06-cmd-setup-line-by-line.html
```

Expected:
```text
Matches are incomplete or missing runtime-card labels
```

- [ ] **Step 2: Rewrite module `06` around runtime cards for startup and setup**

Write:
```html
<section class="module" id="module-6">
  <div class="module-content">
    <header class="module-header animate-in">
      <span class="module-number">06</span>
      <h1 class="module-title">Runtime Start</h1>
      <p class="module-subtitle">从脚本启动开始, 看 MATLAB 真实先执行哪几行, 以及第一次跨文件跳转在哪里发生。</p>
    </header>
  </div>
</section>
```

- [ ] **Step 3: Add a runtime step for `clear; clc; close all;`, `cd(...)`, and `addpath(...)`**

Write:
```html
<div class="pattern-card runtime-card animate-in">
  <div class="pattern-icon">1</div>
  <h4 class="pattern-title">Current line</h4>
  <p class="pattern-desc"><code>cmd_interleave.m:L4-L6</code></p>
  <h4 class="pattern-title">What happens here</h4>
  <p class="pattern-desc">清空工作区、切到脚本目录、把仓库子目录加入 MATLAB 路径。</p>
  <h4 class="pattern-title">Next jump</h4>
  <p class="pattern-desc">No jump, remain in <code>cmd_interleave.m</code>.</p>
  <h4 class="pattern-title">Return point</h4>
  <p class="pattern-desc">Continue at <code>cmd_interleave.m:L8</code>.</p>
</div>
```

- [ ] **Step 4: Add a runtime step for `prob.setTasks();` with explicit cross-file jump**

Write:
```html
<div class="pattern-card runtime-card animate-in">
  <div class="pattern-icon">2</div>
  <h4 class="pattern-title">Current line</h4>
  <p class="pattern-desc"><code>cmd_interleave.m:L29</code></p>
  <h4 class="pattern-title">Next jump</h4>
  <p class="pattern-desc">Jump to <code>Ship_Panel_MTSO.setTasks</code>.</p>
  <h4 class="pattern-title">Return point</h4>
  <p class="pattern-desc">Back to <code>cmd_interleave.m:L31</code>.</p>
</div>
```

- [ ] **Step 5: Add first-appearance MATLAB basics for `cell(...)`, `nan(...)`, and `gobjects(...)`**

Write:
```html
<div class="callout callout-info animate-in">
  <div class="callout-icon">i</div>
  <div class="callout-content">
    <strong class="callout-title">MATLAB meaning</strong>
    <p><code>cell(nAlgo,1)</code> 会创建一个 <code>nAlgo x 1</code> 的 cell 容器。每个格子能装任意类型, 这里用来装每个算法自己的结果表。</p>
  </div>
</div>
```

- [ ] **Step 6: Rebuild and verify module `06` contains runtime labels and basic MATLAB terms**

Run:
```bash
cd cmd-interleave-course && bash build.sh
rg -n "module-6|Current line|Next jump|Return point|cell\\(|nan\\(|gobjects\\(" index.html
```

Expected:
```text
Matches for module-6 and all requested terms
```

- [ ] **Step 7: Commit**

```bash
git add cmd-interleave-course/modules/06-cmd-setup-line-by-line.html cmd-interleave-course/index.html
git commit -m "Rewrite runtime start module"
```

### Task 3: Rewrite Modules 07 and 08 as Runtime Loop + Runtime Bookkeeping

**Files:**
- Modify: `cmd-interleave-course/modules/07-cmd-loop-line-by-line.html`
- Modify: `cmd-interleave-course/modules/08-algorithm-bookkeeping-line-by-line.html`
- Test: `cmd-interleave-course/index.html`

- [ ] **Step 1: Verify the current runtime modules do not yet show caller/callee/return-point detail for the loop**

Run:
```bash
rg -n "algo.run\\(prob\\)|Algorithm.notTerminated|Return point" cmd-interleave-course/modules/07-cmd-loop-line-by-line.html cmd-interleave-course/modules/08-algorithm-bookkeeping-line-by-line.html
```

Expected:
```text
Matches exist but do not yet cover the full caller -> callee -> return structure
```

- [ ] **Step 2: Rewrite module `07` so `algo.run(prob)` becomes an explicit jump card**

Write:
```html
<div class="pattern-card runtime-card animate-in">
  <div class="pattern-icon">3</div>
  <h4 class="pattern-title">Current line</h4>
  <p class="pattern-desc"><code>cmd_interleave.m:L121</code></p>
  <h4 class="pattern-title">Next jump</h4>
  <p class="pattern-desc">Jump into the selected algorithm class via <code>algo.run(prob)</code>.</p>
  <h4 class="pattern-title">Return point</h4>
  <p class="pattern-desc">Back to <code>cmd_interleave.m:L122</code> after the algorithm finishes.</p>
</div>
```

- [ ] **Step 3: Add detailed MATLAB basics for `containers.Map`, anonymous functions, and `rng(...)`**

Write:
```html
<div class="callout callout-info animate-in">
  <div class="callout-icon">i</div>
  <div class="callout-content">
    <strong class="callout-title">MATLAB meaning</strong>
    <p><code>@() live_update_with_earlystop(...)</code> 不是立刻执行函数, 而是创建一个“以后再调用”的匿名函数句柄。</p>
  </div>
</div>
```

- [ ] **Step 4: Rewrite module `08` so `Algorithm.notTerminated` is presented as an execution checkpoint**

Write:
```html
<div class="pattern-card runtime-card animate-in">
  <div class="pattern-icon">4</div>
  <h4 class="pattern-title">Current line</h4>
  <p class="pattern-desc"><code>Algorithm.m:L118-L152</code></p>
  <h4 class="pattern-title">What happens here</h4>
  <p class="pattern-desc">记录单目标最好解、记下 FE、统计种群大小、然后触发脚本注册的状态回调。</p>
  <h4 class="pattern-title">Next jump</h4>
  <p class="pattern-desc">Jump to <code>algo.Check_Status_Fn()</code> at the end of the bookkeeping pass.</p>
</div>
```

- [ ] **Step 5: Add first-appearance basics for `size(x,1)`, `numel(x)`, and `zeros(...)` where they first make sense**

Write:
```html
<div class="callout callout-info animate-in">
  <div class="callout-icon">i</div>
  <div class="callout-content">
    <strong class="callout-title">MATLAB meaning</strong>
    <p><code>zeros(n,1)</code> 会生成一个 <code>n x 1</code> 的 double 全 0 列向量。这里它通常用来提前占位, 让后面的循环逐个把值写进去。</p>
  </div>
</div>
```

- [ ] **Step 6: Rebuild and verify runtime jump phrases are present**

Run:
```bash
cd cmd-interleave-course && bash build.sh
rg -n "algo.run\\(prob\\)|Algorithm.notTerminated|Current line|Next jump|Return point|zeros\\(" index.html
```

Expected:
```text
Matches for all listed phrases
```

- [ ] **Step 7: Commit**

```bash
git add cmd-interleave-course/modules/07-cmd-loop-line-by-line.html cmd-interleave-course/modules/08-algorithm-bookkeeping-line-by-line.html cmd-interleave-course/index.html
git commit -m "Add runtime loop and bookkeeping trace"
```

### Task 4: Rewrite Modules 09 and 10 as Evaluation Trace + Solver Trace

**Files:**
- Modify: `cmd-interleave-course/modules/09-evaluation-and-problem-line-by-line.html`
- Modify: `cmd-interleave-course/modules/10-run-ansys-line-by-line.html`
- Test: `cmd-interleave-course/index.html`

- [ ] **Step 1: Verify the current modules do not yet clearly show the full evaluation call stack**

Run:
```bash
rg -n "Algorithm.Evaluation|Ship_Panel_MTSO.evalTaskBatch|run_ansys_eval|Return point" cmd-interleave-course/modules/09-evaluation-and-problem-line-by-line.html cmd-interleave-course/modules/10-run-ansys-line-by-line.html
```

Expected:
```text
Matches exist but do not yet fully explain the nested return path
```

- [ ] **Step 2: Rewrite module `09` as nested execution cards**

Write:
```html
<div class="pattern-card runtime-card animate-in">
  <div class="pattern-icon">5</div>
  <h4 class="pattern-title">Current line</h4>
  <p class="pattern-desc"><code>Algorithm.m:L184</code></p>
  <h4 class="pattern-title">Next jump</h4>
  <p class="pattern-desc">Jump to <code>Prob.evaluate(x, t)</code>, which resolves to the task function built inside <code>Ship_Panel_MTSO</code>.</p>
  <h4 class="pattern-title">Return point</h4>
  <p class="pattern-desc">Back to <code>Algorithm.m:L186</code>.</p>
</div>
```

- [ ] **Step 3: Add MATLAB basics for matrix scaling and `reshape(con,1,[])`**

Write:
```html
<div class="callout callout-info animate-in">
  <div class="callout-icon">i</div>
  <div class="callout-content">
    <strong class="callout-title">MATLAB meaning</strong>
    <p><code>reshape(con,1,[])</code> 会把约束向量强制整理成一行, 其中 <code>[]</code> 表示剩余长度由 MATLAB 自动推断。</p>
  </div>
</div>
```

- [ ] **Step 4: Rewrite module `10` as the ANSYS call wrapper with explicit failure paths**

Write:
```html
<div class="pattern-card runtime-card animate-in">
  <div class="pattern-icon">6</div>
  <h4 class="pattern-title">Current line</h4>
  <p class="pattern-desc"><code>run_ansys_eval.m:L70-L91</code></p>
  <h4 class="pattern-title">What happens here</h4>
  <p class="pattern-desc">查找 ANSYS 可执行文件, 拼系统命令, 调用批处理, 若失败则立刻改成惩罚结果。</p>
  <h4 class="pattern-title">Return point</h4>
  <p class="pattern-desc">Back to <code>Ship_Panel_MTSO.evalTaskBatch</code> with <code>obj</code>, <code>con</code>, and <code>extra</code>.</p>
</div>
```

- [ ] **Step 5: Add explicit cards for `struct(...)` and solver-failure-to-penalty behavior**

Write:
```html
<div class="callout callout-warning animate-in">
  <div class="callout-icon">!</div>
  <div class="callout-content">
    <strong class="callout-title">MATLAB meaning</strong>
    <p><code>struct('error', false, ...)</code> 会创建一个带命名字段的结构体。这里它像一个小记录本, 用来把错误标志、应力和质量等附加信息一起带回上层。</p>
  </div>
</div>
```

- [ ] **Step 6: Rebuild and verify the full runtime path is visible**

Run:
```bash
cd cmd-interleave-course && bash build.sh
rg -n "Algorithm.Evaluation|Ship_Panel_MTSO.evalTaskBatch|run_ansys_eval|reshape\\(|struct\\(" index.html
```

Expected:
```text
Matches for all listed phrases
```

- [ ] **Step 7: Commit**

```bash
git add cmd-interleave-course/modules/09-evaluation-and-problem-line-by-line.html cmd-interleave-course/modules/10-run-ansys-line-by-line.html cmd-interleave-course/index.html
git commit -m "Add runtime evaluation and solver trace"
```

### Task 5: Final Build, Coverage Check, and Cleanup

**Files:**
- Modify: `cmd-interleave-course/index.html`
- Test: `cmd-interleave-course/index.html`

- [ ] **Step 1: Rebuild the full course**

Run:
```bash
cd cmd-interleave-course && bash build.sh
```

Expected:
```text
Built index.html — open it in your browser.
```

- [ ] **Step 2: Verify the final page has all ten modules**

Run:
```bash
rg -c "<section class=\"module\"" cmd-interleave-course/index.html
```

Expected:
```text
10
```

- [ ] **Step 3: Verify runtime-trace markers exist**

Run:
```bash
rg -n "Current line|Next jump|Return point|MATLAB meaning" cmd-interleave-course/index.html
```

Expected:
```text
Multiple matches across modules 06-10
```

- [ ] **Step 4: Verify the core call path is present**

Run:
```bash
rg -n "cmd_interleave.m|Ship_Panel_MTSO.setTasks|Algorithm.notTerminated|Algorithm.Evaluation|run_ansys_eval" cmd-interleave-course/index.html
```

Expected:
```text
Matches for all five path markers
```

- [ ] **Step 5: Verify MATLAB basics are present**

Run:
```bash
rg -n "zeros\\(|cell\\(|nan\\(|gobjects\\(|struct\\(|reshape\\(" cmd-interleave-course/index.html
```

Expected:
```text
Matches for all listed basics
```

- [ ] **Step 6: Commit**

```bash
git add cmd-interleave-course
git commit -m "Turn cmd interleave course into runtime trace"
```

## Self-Review

### Spec coverage

- Runtime-trace presentation: covered by Tasks 1 through 4
- Caller -> callee -> return-point explanations: covered by Tasks 2 through 4
- MATLAB basics inline: covered by Tasks 2 through 4
- Primary-path-only scope: enforced by Task 4 notes and file list
- Static validation: covered by Task 5

### Placeholder scan

- No `TODO`, `TBD`, or “implement later” markers remain
- Every task includes exact file paths
- Every verification step includes concrete commands

### Type consistency

- Module numbering is consistent with the current course layout
- Runtime card terminology is consistent: `Current line`, `Next jump`, `Return point`, `MATLAB meaning`
- Core file/function names match the repository:
  - `cmd_interleave.m`
  - `Ship_Panel_MTSO.setTasks`
  - `Algorithm.notTerminated`
  - `Algorithm.Evaluation`
  - `run_ansys_eval`
