%% cmd_ceda_mapping_animation.m - CEDA domain adaptation mapping animation
% Visualizes the step-by-step mapping: x' = (x - μs) Cs^{-1/2} Ct^{1/2} + μt
% Also demonstrates the dual-channel improvement (feasible vs infeasible)
%
% Usage: cd('MTO'); run('cmd_ceda_mapping_animation.m')

clear; clc; close all;
rng(42);

%% ===== Generate synthetic 2D populations =====
Ns = 40;  % source population size
Nt = 40;  % target population size

% Source task: two clusters (feasible near center, infeasible spread out)
mu_s_feas = [2, 3];
C_s_feas  = [0.8 0.3; 0.3 0.5];
mu_s_inf  = [5, 1];
C_s_inf   = [1.5 -0.4; -0.4 1.2];

n_s_feas = round(Ns * 0.5);
n_s_inf  = Ns - n_s_feas;
Xs_feas = mvnrnd(mu_s_feas, C_s_feas, n_s_feas);
Xs_inf  = mvnrnd(mu_s_inf, C_s_inf, n_s_inf);
Xs = [Xs_feas; Xs_inf];
s_labels = [ones(n_s_feas,1); zeros(n_s_inf,1)]; % 1=feasible, 0=infeasible

% Target task: different distribution
mu_t_feas = [8, 7];
C_t_feas  = [0.6 -0.2; -0.2 0.9];
mu_t_inf  = [6, 9];
C_t_inf   = [1.0 0.5; 0.5 1.8];

n_t_feas = round(Nt * 0.5);
n_t_inf  = Nt - n_t_feas;
Xt_feas = mvnrnd(mu_t_feas, C_t_feas, n_t_feas);
Xt_inf  = mvnrnd(mu_t_inf, C_t_inf, n_t_inf);
Xt = [Xt_feas; Xt_inf];
t_labels = [ones(n_t_feas,1); zeros(n_t_inf,1)];

%% ===== Animation 1: Standard CEDA mapping (single channel) =====
fig1 = figure('Name', 'CEDA Single-Channel Mapping', ...
    'Position', [50 100 1200 800], 'Color', 'w');

% Compute single-channel statistics (mixed feasible + infeasible)
mu_s = mean(Xs, 1);
mu_t = mean(Xt, 1);
Cs = cov(Xs) + 1e-6 * eye(2);
Ct = cov(Xt) + 1e-6 * eye(2);
CsInvSqrt = mat_inv_sqrt(Cs);
CtSqrt = mat_sqrt(Ct);

% Transformation steps for source points mapped to target space
step0 = Xs;                              % original
step1 = Xs - mu_s;                       % centering
step2 = step1 * CsInvSqrt;              % whitening
step3 = step2 * CtSqrt;                 % coloring
step4 = step3 + mu_t;                   % shifting

steps = {step0, step1, step2, step3, step4};
step_titles = {
    'Step 0: Source population (original)', ...
    'Step 1: Centering  x - \mu_s', ...
    'Step 2: Whitening  \times C_s^{-1/2}', ...
    'Step 3: Coloring   \times C_t^{1/2}', ...
    'Step 4: Shifting   + \mu_t  (mapped result)'};

% Determine axis limits across all steps
all_pts = [Xs; Xt; cell2mat(steps')];
ax_margin = 2;
xlims = [min(all_pts(:,1)) - ax_margin, max(all_pts(:,1)) + ax_margin];
ylims = [min(all_pts(:,2)) - ax_margin, max(all_pts(:,2)) + ax_margin];

n_interp = 30; % frames between steps
pause_frames = 15; % pause at each step

for si = 1:numel(steps)-1
    from = steps{si};
    to   = steps{si+1};

    for f = 0:n_interp + pause_frames
        clf(fig1);
        alpha = min(f / n_interp, 1.0);
        cur = from + alpha * (to - from);

        ax = axes(fig1); %#ok<LAXES>
        hold(ax, 'on');

        % Draw target population (always visible as reference)
        scatter(ax, Xt(t_labels==1, 1), Xt(t_labels==1, 2), 60, ...
            [0.5 0.8 0.5], 'filled', 'MarkerEdgeColor', [0 0.5 0], ...
            'DisplayName', 'Target (feasible)');
        scatter(ax, Xt(t_labels==0, 1), Xt(t_labels==0, 2), 60, ...
            [0.8 0.5 0.5], 'filled', 'MarkerEdgeColor', [0.5 0 0], ...
            'DisplayName', 'Target (infeasible)');

        % Draw current source points
        scatter(ax, cur(s_labels==1, 1), cur(s_labels==1, 2), 80, ...
            [0.2 0.4 0.9], 'filled', 'MarkerEdgeColor', [0 0 0.6], ...
            'Marker', 'd', 'DisplayName', 'Source (feasible)');
        scatter(ax, cur(s_labels==0, 1), cur(s_labels==0, 2), 80, ...
            [0.9 0.6 0.2], 'filled', 'MarkerEdgeColor', [0.6 0.3 0], ...
            'Marker', 'd', 'DisplayName', 'Source (infeasible)');

        % Draw ellipses for target distribution
        draw_ellipse(ax, mu_t_feas, C_t_feas, [0 0.5 0], '--');
        draw_ellipse(ax, mu_t_inf, C_t_inf, [0.5 0 0], '--');

        % Draw mean markers
        if alpha >= 1
            plot(ax, mu_t(1), mu_t(2), 'p', 'MarkerSize', 15, ...
                'MarkerFaceColor', [0 0.7 0], 'MarkerEdgeColor', 'k', ...
                'HandleVisibility', 'off');
        end

        xlim(ax, xlims); ylim(ax, ylims);
        grid(ax, 'on');
        legend(ax, 'Location', 'northwest', 'FontSize', 9);
        set(ax, 'FontSize', 11);

        if alpha < 1
            progress = sprintf(' (%.0f%%)', alpha * 100);
        else
            progress = '';
        end
        title(ax, sprintf('Single-Channel CEDA Mapping\n%s%s', ...
            step_titles{si+1}, progress), 'FontSize', 13);

        % Formula annotation
        annotation(fig1, 'textbox', [0.15 0.01 0.7 0.06], ...
            'String', "x' = (x - \mu_s) \times C_s^{-1/2} \times C_t^{1/2} + \mu_t", ...
            'FontSize', 12, 'HorizontalAlignment', 'center', ...
            'EdgeColor', 'none', 'FontWeight', 'bold');

        drawnow;
        pause(0.03);
    end
end

fprintf('Single-channel animation done. Press any key for dual-channel...\n');
pause;

%% ===== Animation 2: Dual-Channel mapping =====
fig2 = figure('Name', 'CEDA Dual-Channel Mapping', ...
    'Position', [80 80 1400 600], 'Color', 'w');

% Feasible channel statistics
mu_sf = mean(Xs_feas, 1);
mu_tf = mean(Xt_feas, 1);
Csf = cov(Xs_feas) + 1e-6 * eye(2);
Ctf = cov(Xt_feas) + 1e-6 * eye(2);

% Infeasible channel statistics
mu_si = mean(Xs_inf, 1);
mu_ti = mean(Xt_inf, 1);
Csi = cov(Xs_inf) + 1e-6 * eye(2);
Cti = cov(Xt_inf) + 1e-6 * eye(2);

% Feasible channel mapping
feas_mapped = (Xs_feas - mu_sf) * mat_inv_sqrt(Csf) * mat_sqrt(Ctf) + mu_tf;
% Infeasible channel mapping
inf_mapped  = (Xs_inf - mu_si) * mat_inv_sqrt(Csi) * mat_sqrt(Cti) + mu_ti;

% Also compute single-channel result for comparison
single_mapped = step4;

channel_names = {'Feasible Channel', 'Infeasible Channel'};
src_data = {Xs_feas, Xs_inf};
dst_data = {feas_mapped, inf_mapped};
src_colors = {[0.2 0.4 0.9], [0.9 0.6 0.2]};
tgt_ref_data = {Xt_feas, Xt_inf};
tgt_ref_colors = {[0.5 0.8 0.5], [0.8 0.5 0.5]};
mu_src = {mu_sf, mu_si};
mu_tgt = {mu_tf, mu_ti};
C_tgt = {Ctf, Cti};
edge_colors_t = {[0 0.5 0], [0.5 0 0]};

n_interp2 = 40;

for f = 0:n_interp2 + pause_frames
    clf(fig2);
    alpha = min(f / n_interp2, 1.0);

    for ch = 1:2
        ax = subplot(1, 3, ch, 'Parent', fig2);
        hold(ax, 'on');

        % Target reference
        scatter(ax, tgt_ref_data{ch}(:,1), tgt_ref_data{ch}(:,2), 50, ...
            tgt_ref_colors{ch}, 'filled', 'MarkerEdgeColor', edge_colors_t{ch}, ...
            'DisplayName', sprintf('Target (%s)', lower(channel_names{ch})));
        draw_ellipse(ax, mu_tgt{ch}, C_tgt{ch}, edge_colors_t{ch}, '--');

        % Interpolated source
        cur = src_data{ch} + alpha * (dst_data{ch} - src_data{ch});
        scatter(ax, cur(:,1), cur(:,2), 70, src_colors{ch}, 'filled', ...
            'Marker', 'd', 'MarkerEdgeColor', 'k', ...
            'DisplayName', sprintf('Source (%s)', lower(channel_names{ch})));

        xlim(ax, xlims); ylim(ax, ylims);
        grid(ax, 'on');
        title(ax, channel_names{ch}, 'FontSize', 12);
        legend(ax, 'Location', 'northwest', 'FontSize', 8);
        set(ax, 'FontSize', 10);
    end

    % Third subplot: combined result comparison
    ax3 = subplot(1, 3, 3, 'Parent', fig2);
    hold(ax3, 'on');

    % Target
    scatter(ax3, Xt(t_labels==1,1), Xt(t_labels==1,2), 40, ...
        [0.5 0.8 0.5], 'filled', 'MarkerEdgeColor', [0 0.5 0], ...
        'DisplayName', 'Target (feas)');
    scatter(ax3, Xt(t_labels==0,1), Xt(t_labels==0,2), 40, ...
        [0.8 0.5 0.5], 'filled', 'MarkerEdgeColor', [0.5 0 0], ...
        'DisplayName', 'Target (infeas)');

    % Single-channel (gray, for comparison)
    scatter(ax3, single_mapped(s_labels==1,1), single_mapped(s_labels==1,2), 40, ...
        [0.7 0.7 0.7], 'filled', 'Marker', 'o', ...
        'DisplayName', 'Single-ch mapped');
    scatter(ax3, single_mapped(s_labels==0,1), single_mapped(s_labels==0,2), 40, ...
        [0.7 0.7 0.7], 'filled', 'Marker', 'o', ...
        'HandleVisibility', 'off');

    % Dual-channel result
    if alpha > 0.01
        cur_f = src_data{1} + alpha * (dst_data{1} - src_data{1});
        cur_i = src_data{2} + alpha * (dst_data{2} - src_data{2});
        scatter(ax3, cur_f(:,1), cur_f(:,2), 70, [0.2 0.4 0.9], 'filled', ...
            'Marker', 'd', 'MarkerEdgeColor', [0 0 0.6], ...
            'DisplayName', 'Dual-ch feas');
        scatter(ax3, cur_i(:,1), cur_i(:,2), 70, [0.9 0.6 0.2], 'filled', ...
            'Marker', 'd', 'MarkerEdgeColor', [0.6 0.3 0], ...
            'DisplayName', 'Dual-ch infeas');
    end

    xlim(ax3, xlims); ylim(ax3, ylims);
    grid(ax3, 'on');
    title(ax3, 'Comparison: Single vs Dual Channel', 'FontSize', 12);
    legend(ax3, 'Location', 'northwest', 'FontSize', 8);
    set(ax3, 'FontSize', 10);

    sgtitle(fig2, sprintf('Dual-Channel CEDA Mapping (%.0f%%)', alpha*100), ...
        'FontSize', 14, 'FontWeight', 'bold');

    drawnow;
    pause(0.03);
end

fprintf('Dual-channel animation done. Press any key for archive demo...\n');
pause;

%% ===== Animation 3: Archive augmentation effect =====
fig3 = figure('Name', 'Archive Augmentation', ...
    'Position', [100 60 1000 500], 'Color', 'w');

% Simulate archive: high-quality infeasible solutions near feasibility boundary
n_arc = 8;
mu_arc = (mu_s_feas + mu_s_inf) / 2 + [0.5, 0.3]; % between feas and infeas
C_arc = [0.3 0.1; 0.1 0.2];
Xs_arc = mvnrnd(mu_arc, C_arc, n_arc);

% Infeasible channel without archive
inf_only = Xs_inf;
mu_si_no = mean(inf_only, 1);
Csi_no = cov(inf_only) + 1e-6 * eye(2);

% Infeasible channel with archive augmentation
inf_aug = [Xs_inf; Xs_arc];
mu_si_aug = mean(inf_aug, 1);
Csi_aug = cov(inf_aug) + 1e-6 * eye(2);

mapped_no_arc  = (Xs_inf - mu_si_no) * mat_inv_sqrt(Csi_no) * mat_sqrt(Cti) + mu_ti;
mapped_with_arc = (Xs_inf - mu_si_aug) * mat_inv_sqrt(Csi_aug) * mat_sqrt(Cti) + mu_ti;

for f = 0:n_interp2 + pause_frames
    clf(fig3);
    alpha = min(f / n_interp2, 1.0);

    % Left: without archive
    ax1 = subplot(1, 2, 1, 'Parent', fig3);
    hold(ax1, 'on');
    scatter(ax1, Xt_inf(:,1), Xt_inf(:,2), 50, [0.8 0.5 0.5], 'filled', ...
        'MarkerEdgeColor', [0.5 0 0], 'DisplayName', 'Target (infeas)');
    draw_ellipse(ax1, mu_ti, Cti, [0.5 0 0], '--');

    cur_no = Xs_inf + alpha * (mapped_no_arc - Xs_inf);
    scatter(ax1, cur_no(:,1), cur_no(:,2), 70, [0.9 0.6 0.2], 'filled', ...
        'Marker', 'd', 'MarkerEdgeColor', 'k', 'DisplayName', 'Source infeas');

    draw_ellipse(ax1, mu_si_no, Csi_no, [0.9 0.6 0.2], ':');
    xlim(ax1, xlims); ylim(ax1, ylims);
    grid(ax1, 'on');
    title(ax1, 'Without Archive', 'FontSize', 12);
    legend(ax1, 'Location', 'northwest', 'FontSize', 8);

    % Right: with archive
    ax2 = subplot(1, 2, 2, 'Parent', fig3);
    hold(ax2, 'on');
    scatter(ax2, Xt_inf(:,1), Xt_inf(:,2), 50, [0.8 0.5 0.5], 'filled', ...
        'MarkerEdgeColor', [0.5 0 0], 'DisplayName', 'Target (infeas)');
    draw_ellipse(ax2, mu_ti, Cti, [0.5 0 0], '--');

    cur_aug = Xs_inf + alpha * (mapped_with_arc - Xs_inf);
    scatter(ax2, cur_aug(:,1), cur_aug(:,2), 70, [0.9 0.6 0.2], 'filled', ...
        'Marker', 'd', 'MarkerEdgeColor', 'k', 'DisplayName', 'Source infeas');

    % Show archive points
    scatter(ax2, Xs_arc(:,1), Xs_arc(:,2), 100, [0.6 0.2 0.8], 'filled', ...
        'Marker', 'p', 'MarkerEdgeColor', [0.3 0 0.5], ...
        'DisplayName', 'Archive');

    draw_ellipse(ax2, mu_si_aug, Csi_aug, [0.6 0.2 0.8], ':');
    xlim(ax2, xlims); ylim(ax2, ylims);
    grid(ax2, 'on');
    title(ax2, 'With Archive Augmentation', 'FontSize', 12);
    legend(ax2, 'Location', 'northwest', 'FontSize', 8);

    sgtitle(fig3, sprintf('Archive Effect on Infeasible Channel (%.0f%%)', alpha*100), ...
        'FontSize', 14, 'FontWeight', 'bold');

    drawnow;
    pause(0.03);
end

fprintf('\nAll animations done!\n');

%% ======================== Helper Functions ================================

function A = mat_sqrt(C)
[V, E] = eig((C + C') / 2);
e = max(real(diag(E)), 1e-12);
A = V * diag(sqrt(e)) * V';
end

function A = mat_inv_sqrt(C)
[V, E] = eig((C + C') / 2);
e = max(real(diag(E)), 1e-12);
A = V * diag(1 ./ sqrt(e)) * V';
end

function draw_ellipse(ax, mu, C, color, style)
theta = linspace(0, 2*pi, 100);
[V, D] = eig(C);
r = [cos(theta); sin(theta)];
e = V * sqrt(D) * r * 2; % 2-sigma ellipse
plot(ax, mu(1) + e(1,:), mu(2) + e(2,:), style, ...
    'Color', color, 'LineWidth', 1.5, 'HandleVisibility', 'off');
plot(ax, mu(1), mu(2), '+', 'Color', color, 'MarkerSize', 12, ...
    'LineWidth', 2, 'HandleVisibility', 'off');
end
