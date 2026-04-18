function [improved, state] = evaluate_ceda_dw_earlystop_progress( ...
    cur_best, cur_cv, prev_best, prev_cv, prev_has_feasible, tol)
% Evaluate whether the current generation made progress for CEDA-DW early stop.
% Before a task becomes feasible, progress is defined by lower CV.
% After a task becomes feasible, progress is defined by lower objective.

if nargin < 6 || isempty(tol)
    tol = 1e-6;
end

state = struct();
state.prev_best = prev_best;
state.prev_cv = prev_cv;
state.prev_has_feasible = prev_has_feasible;

improved_mask = false(size(cur_cv));

for t = 1:numel(cur_cv)
    if ~isfinite(cur_cv(t))
        continue;
    end

    cur_has_feasible = cur_cv(t) <= tol;
    if cur_has_feasible
        if ~prev_has_feasible(t) || cur_best(t) < prev_best(t) - tol
            improved_mask(t) = true;
        end
        state.prev_has_feasible(t) = true;
        if cur_best(t) < state.prev_best(t)
            state.prev_best(t) = cur_best(t);
        end
        state.prev_cv(t) = 0;
    else
        if cur_cv(t) < prev_cv(t) - tol
            improved_mask(t) = true;
        end
        if cur_cv(t) < state.prev_cv(t)
            state.prev_cv(t) = cur_cv(t);
        end
    end
end

improved = any(improved_mask);
end
