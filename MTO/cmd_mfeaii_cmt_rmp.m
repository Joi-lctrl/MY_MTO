%% cmd_mfeaii_cmt_rmp.m - MFEA-II on CMT benchmarks with real-time RMP plot
% Usage: cd('MTO'); run('cmd_mfeaii_cmt_rmp.m')

clear; clc; close all;
cd(fileparts(mfilename('fullpath')));
addpath(genpath(pwd));

%% ===== Configuration =====
prob_names = {'CMT1', 'CMT2', 'CMT3', 'CMT4', 'CMT5', 'CMT6', 'CMT7', 'CMT8', 'CMT9'};
Reps = 1;
Global_Seed = 2333;

%% ===== Run each CMT problem =====
for pi = 1:numel(prob_names)
    pname = prob_names{pi};
    fprintf('\n============ %s ============\n', pname);

    % Create problem
    prob = eval([pname, '()']);
    prob.setTasks();
    nTask = prob.T;
    nPairs = nTask * (nTask - 1) / 2;

    % Create algorithm
    algo = MFEA_II();
    algo.Result_Num = 50;
    algo.Save_Dec = false;

    % --- RMP real-time figure ---
    fig_rmp = figure('Name', sprintf('%s - MFEA-II RMP', pname), ...
        'Position', [100 + 30*pi, 100 + 30*pi, 600, 350]);
    ax_rmp = axes(fig_rmp);
    hold(ax_rmp, 'on'); grid(ax_rmp, 'on');
    title(ax_rmp, sprintf('%s: MFEA-II RMP (T=%d)', pname, nTask));
    xlabel(ax_rmp, 'Generation');
    ylabel(ax_rmp, 'RMP');
    ylim(ax_rmp, [0 1]);
    rmp_colors = lines(max(nPairs, 1));
    h_rmp = gobjects(nPairs, 1);
    pair_idx = 0;
    for ti = 1:nTask
        for tj = (ti+1):nTask
            pair_idx = pair_idx + 1;
            h_rmp(pair_idx) = animatedline(ax_rmp, ...
                'Color', rmp_colors(pair_idx,:), 'LineWidth', 2, ...
                'Marker', '.', 'MarkerSize', 6, ...
                'DisplayName', sprintf('RMP(T%d,T%d)', ti, tj));
        end
    end
    legend(ax_rmp, 'Location', 'best');
    drawnow;

    % --- Convergence figure ---
    fig_conv = figure('Name', sprintf('%s - Convergence', pname), ...
        'Position', [120 + 30*pi, 80 + 30*pi, 900, 350]);
    ax_conv = gobjects(1, nTask);
    h_obj = gobjects(1, nTask);
    h_cv  = gobjects(1, nTask);
    for t = 1:nTask
        ax_conv(t) = subplot(1, nTask, t);
        hold(ax_conv(t), 'on'); grid(ax_conv(t), 'on');
        title(ax_conv(t), sprintf('Task %d', t));
        xlabel(ax_conv(t), 'FE');
        ylabel(ax_conv(t), 'Best Obj / CV');
        h_obj(t) = animatedline(ax_conv(t), ...
            'Color', [0 0.447 0.741], 'LineWidth', 1.5, ...
            'DisplayName', 'Obj');
        h_cv(t) = animatedline(ax_conv(t), ...
            'Color', [0.850 0.325 0.098], 'LineStyle', '--', 'LineWidth', 1, ...
            'DisplayName', 'CV');
        legend(ax_conv(t), 'Location', 'northeast');
    end
    drawnow;

    % --- Bind live update callback ---
    algo.Check_Status_Fn = @() live_rmp_update( ...
        algo, nTask, h_rmp, h_obj, h_cv, fig_rmp, fig_conv);

    % --- Run ---
    rng(Global_Seed);
    algo.reset();
    algo.run(prob);

    % --- Print final RMP ---
    if ~isempty(algo.RMPTrace)
        final_rmp = algo.RMPTrace{end};
        fprintf('%s final RMP:\n', pname);
        for ti = 1:nTask
            for tj = (ti+1):nTask
                fprintf('  RMP(T%d,T%d) = %.4f\n', ti, tj, final_rmp(ti,tj));
            end
        end
    end

    % --- Print final results ---
    tmp = algo.getResult(prob);
    for t = 1:nTask
        obj_hist = [tmp(t, :).Obj];
        fprintf('  Task %d: final Obj = %.6f\n', t, obj_hist(end));
    end

    fprintf('按任意键继续下一个问题 (或 Ctrl+C 终止)...\n');
    pause;
end

fprintf('\n===== All CMT problems completed =====\n');

%% ======================== Local Function ================================

function live_rmp_update(algo, nTask, h_rmp, h_obj, h_cv, fig_rmp, fig_conv)
% Per-generation callback: update RMP + convergence plots

% Update convergence
if isvalid(fig_conv)
    fe = algo.FE;
    for t = 1:nTask
        if ~isempty(algo.Best) && numel(algo.Best) >= t && ~isempty(algo.Best{t})
            addpoints(h_obj(t), fe, algo.Best{t}.Obj);
            addpoints(h_cv(t),  fe, algo.Best{t}.CV);
        end
    end
end

% Update RMP
if isvalid(fig_rmp) && isprop(algo, 'RMPTrace') && ~isempty(algo.RMPTrace)
    gen = numel(algo.RMPTrace);
    cur_rmp = algo.RMPTrace{gen};
    pair_idx = 0;
    for ti = 1:nTask
        for tj = (ti+1):nTask
            pair_idx = pair_idx + 1;
            addpoints(h_rmp(pair_idx), gen, cur_rmp(ti, tj));
        end
    end
end

drawnow('limitrate');
end
