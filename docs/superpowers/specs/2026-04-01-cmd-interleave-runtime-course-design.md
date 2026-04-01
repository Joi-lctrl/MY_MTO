# cmd_interleave Runtime Course Design

Date: 2026-04-01

## Goal

Extend the existing `cmd-interleave-course/` output from a concept-first course into a runtime-trace course that shows how the project actually executes when a user runs `cmd_interleave.m`.

The new course should answer four concrete questions:

1. What file and line executes first?
2. When execution leaves the current file, which `.m` file does it jump to next, and why?
3. After that callee returns, which line resumes in the caller?
4. What MATLAB object, array, or scalar does each key line create or mutate?

The learner is assumed to have little or no MATLAB background. The course therefore needs to explain both control flow and MATLAB basics such as `zeros`, `cell`, `nan`, `struct`, `gobjects`, `size`, `numel`, `reshape`, anonymous functions, and function handles.

## Non-Goals

- This change does not turn the course into a full debugger.
- This change does not instrument MATLAB at runtime.
- This change does not attempt to explain every helper function in the repository.
- This change does not replace the existing overview modules; it extends them.

## User Experience

The course remains a static single-page HTML artifact in `cmd-interleave-course/index.html`, but the new content shifts from “what these components are” to “how execution moves through them.”

The learner should be able to follow an execution trace like this:

`cmd_interleave.m` setup
-> `Ship_Panel_MTSO.setTasks`
-> back to `cmd_interleave.m`
-> `algo.run(prob)`
-> `Algorithm.notTerminated`
-> `Algorithm.Evaluation`
-> `Ship_Panel_MTSO.evalTaskBatch`
-> `run_ansys_eval`
-> back up the stack
-> `save(...)`

Each runtime step should present:

- Current file and line range
- Why execution is at this location
- If a call occurs, the exact next file/function jumped to
- What returns back to the caller
- Variable-shape explanations for MATLAB expressions on that step

## Recommended Approach

Keep the existing first five overview modules, then add a second layer of “runtime trace” modules that behaves like a guided execution replay.

This is preferred over rewriting the entire course because:

- The existing overview still provides the mental model needed before line-by-line tracing
- A trace-only course would be harder to enter for a new learner
- Replacing the whole course would create unnecessary churn in already good content

## Output Structure

The existing directory layout stays the same:

```text
cmd-interleave-course/
  _base.html
  _footer.html
  build.sh
  styles.css
  main.js
  modules/
    01-...
    ...
    10-...
  index.html
```

Only HTML content and the course shell are changed. Existing CSS and JS are reused unless a very small additive change is required to support the trace layout.

## Module Plan

### Existing overview layer

Modules `01` through `05` remain in place and continue to cover the high-level story:

- What `cmd_interleave` is
- Which components participate
- What a rep is
- How decision variables become engineering results
- What gets saved

### New runtime-trace layer

Add a second layer that follows actual execution:

- `06` Runtime start: `cmd_interleave.m` setup, configuration, problem construction
- `07` Runtime loop: plotting setup, rep loop, callbacks, save path
- `08` Runtime bookkeeping: `Algorithm.notTerminated`
- `09` Runtime evaluation path: `Algorithm.Evaluation` and `Ship_Panel_MTSO`
- `10` Runtime solver wrapper: `run_ansys_eval`

These runtime modules are not just line-by-line translations. They are execution cards.

## Interaction Design

The new runtime modules should use a repeated card structure rather than one huge code dump.

Each runtime step card should contain these fields:

- `Current line`
  - Example: `cmd_interleave.m:L97`
- `What happens here`
  - Example: “Reset the random number generator for this rep”
- `MATLAB meaning`
  - Example: “`rng(seeds(rep))` seeds MATLAB’s global random stream with one scalar integer”
- `Next jump`
  - Example: “No jump, remain in `cmd_interleave.m`”
  - Or: “Jump to `Ship_Panel_MTSO.setTasks`”
- `Return point`
  - Example: “Back to `cmd_interleave.m:L99`”

For function calls, the trace card must explicitly show caller, callee, and return point. This is the core of the requested user experience.

## MATLAB Basics Layer

The runtime modules must explain basic MATLAB constructors and operators when they first appear in the execution path.

Required explanations include:

- `zeros(n,1)`
  - Creates an `n x 1` double column vector filled with `0`
- `cell(nAlgo,1)`
  - Creates a cell array container of that size, with each slot initially empty
- `nan(...)`
  - Creates a numeric array filled with “not-a-number” placeholders
- `gobjects(...)`
  - Creates placeholder graphics-object arrays for figure handles
- `struct(...)`
  - Creates a struct with named fields
- `numel(x)`
  - Returns how many elements are in `x`
- `size(x,1)`
  - Returns the number of rows in `x`
- `reshape(con,1,[])`
  - Forces data into one row while letting MATLAB infer the remaining length
- `@() ...`
  - Creates an anonymous function handle
- `Prob.makeTaskFcn(task_id)`
  - Produces a function handle capturing `task_id`

These explanations should be short, concrete, and tied to the current runtime step. They should not become a detached MATLAB glossary page.

## Trace Boundaries

The runtime trace should cover the primary path only.

Covered:

- `cmd_interleave.m`
- `Ship_Panel_MTSO.setTasks`
- `Algorithm.notTerminated`
- `Algorithm.Evaluation`
- `Ship_Panel_MTSO.evalTaskBatch`
- `run_ansys_eval`

Referenced but not fully expanded:

- `parse_results`
- `find_ansys_exe`
- cleanup helpers
- all internals of the chosen optimization algorithm class

Reason:

The user asked for the real execution flow of `cmd_interleave`, especially jumps across files. Expanding all internals of GA or CEDA would break focus and make the course too long.

## Content Rules

- Keep real file names and line numbers visible
- Explain jumps in the same order MATLAB follows them
- Use exact variable names from the code
- Prefer “what object exists after this line” over abstract explanation
- When a line is only a section comment or `end`, mention it briefly or merge it into adjacent commentary
- Avoid pretending the course is generated from dynamic tracing; it is a statically authored runtime walkthrough

## Implementation Notes

### `_base.html`

Update the navigation to make the second half of the course clearly runtime-oriented. Titles should signal trace behavior, not just deeper explanation.

### Module content

Rewrite the new runtime modules to use a consistent execution-card pattern:

- small code snippet
- detailed line explanations
- next jump / return point blocks
- optional callout for MATLAB basics

### Existing modules

The first five modules can stay mostly intact. Only small cross-links may be added so the runtime layer feels connected rather than bolted on.

### CSS / JS

Prefer not to change `styles.css` or `main.js`.

If the runtime cards need stronger visual distinction, add minimal additive markup using existing component classes:

- `translation-block`
- `callout`
- `pattern-card`
- `badge-item`

Only change CSS if the existing classes are clearly insufficient.

## Error Handling in the Course

The runtime content must explicitly describe how failures are handled in the actual code:

- Missing APDL directory
- Failure to write macro file
- Missing ANSYS executable
- Non-zero ANSYS exit status
- Failure to parse results
- Error-to-penalty conversion in `evalTaskBatch`

This is important because the user specifically wants the real run path, not just the happy path.

## Testing and Validation

Validation for this documentation change is static:

1. Rebuild `cmd-interleave-course/index.html` using `bash build.sh`
2. Verify the final page contains all runtime modules and nav dots
3. Verify the final page contains file names and key line-number markers from the trace
4. Verify key call path terms exist:
   - `cmd_interleave.m`
   - `Ship_Panel_MTSO.setTasks`
   - `Algorithm.notTerminated`
   - `Algorithm.Evaluation`
   - `run_ansys_eval`
5. Verify MATLAB basics terms exist:
   - `zeros`
   - `cell`
   - `nan`
   - `gobjects`
   - `struct`

Runtime execution in MATLAB is not required for this content change.

## Risks

### Risk: page becomes too long

Mitigation:

- keep execution cards small
- use one screen per logical jump or micro-phase
- do not inline helper implementations unless they are on the primary path

### Risk: explanations become repetitive

Mitigation:

- treat each card as a concrete stack event
- vary focus across cards: control flow, data shape, or failure handling

### Risk: learner confuses static walkthrough with live tracing

Mitigation:

- explicitly state this is a reconstructed execution path based on source reading

## Final Recommendation

Implement the runtime-trace layer as an additive extension of the existing course.

That keeps the current strong overview, adds the requested “where does execution jump next” narrative, and introduces MATLAB basics exactly where the learner needs them.
