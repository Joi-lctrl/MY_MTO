%% plot_CEDA_diag.m
% Visualize diagnostic log from CEDA-MP-Diag
% Usage: run CEDA-MP-Diag first, then run this script
%
% Example:
%   mto({CEDA_MP_Diag()}, {CMT6()}, 'Reps', 1, 'Global_Seed', 2333);
%   plot_CEDA_diag;  % or: plot_CEDA_diag('CEDA_Diag_Log.mat');

function plot_CEDA_diag(logfile)
if nargin < 1
    logfile = 'CEDA_Diag_Log.mat';
end

data = load(logfile);
Log = data.Log;
T = Log.T;
nGen = Log.TotalGen;
gens = 1:nGen;

fprintf('Problem: %s | Tasks: %d | Generations: %d | RMP1: %.3f\n', ...
    Log.ProbName, T, nGen, Log.RMP1);

%% Figure 1: Transfer Quality - Is transfer helpful?
figure('Name', 'Transfer Quality Analysis', 'Position', [50 50 1200 800]);
for t = 1:T
    % Transfer vs Normal average rank
    subplot(T, 3, (t - 1) * 3 + 1);
    plot(gens, Log.Trans_AvgRank(:, t), 'b-', 'LineWidth', 1); hold on;
    plot(gens, Log.Normal_AvgRank(:, t), 'r-', 'LineWidth', 1);
    midline = yline(mean([Log.Trans_AvgRank(:, t); Log.Normal_AvgRank(:, t)], 'omitnan'), ...
        'k--', 'LineWidth', 0.5);
    legend('Transfer', 'Normal', 'Location', 'best');
    title(sprintf('T%d Avg Rank (lower=better)', t));
    xlabel('Gen'); ylabel('Rank');
    grid on;

    % Transfer vs Normal success rate (top half)
    subplot(T, 3, (t - 1) * 3 + 2);
    plot(gens, Log.Trans_SuccRate(:, t), 'b-', 'LineWidth', 1); hold on;
    plot(gens, Log.Normal_SuccRate(:, t), 'r-', 'LineWidth', 1);
    yline(0.5, 'k--', 'LineWidth', 0.5);
    legend('Transfer', 'Normal', 'Location', 'best');
    title(sprintf('T%d Top-Half Rate', t));
    xlabel('Gen'); ylabel('Rate');
    ylim([0, 1]);
    grid on;

    % Transfer count
    subplot(T, 3, (t - 1) * 3 + 3);
    bar(gens, [Log.N_Trans(:, t), Log.N_Normal(:, t)], 'stacked');
    legend('Transfer', 'Normal', 'Location', 'best');
    title(sprintf('T%d Offspring Composition', t));
    xlabel('Gen'); ylabel('Count');
    grid on;
end
sgtitle('Transfer Quality: Is knowledge transfer helping?');

%% Figure 2: Population Convergence
figure('Name', 'Population Convergence', 'Position', [100 100 1200 800]);
for t = 1:T
    % Best Obj
    subplot(T, 3, (t - 1) * 3 + 1);
    semilogy(gens, Log.Pop1_BestObj(:, t), 'b-', 'LineWidth', 1.5); hold on;
    semilogy(gens, Log.Pop2_BestObj(:, t), 'r-', 'LineWidth', 1.5);
    legend('Pop1 (relaxed)', 'Pop2 (strict)', 'Location', 'best');
    title(sprintf('T%d Best Feasible Obj', t));
    xlabel('Gen'); ylabel('Obj');
    grid on;

    % Mean CV
    subplot(T, 3, (t - 1) * 3 + 2);
    semilogy(gens, max(Log.Pop1_MeanCV(:, t), 1e-16), 'b-', 'LineWidth', 1.5); hold on;
    semilogy(gens, max(Log.Pop2_MeanCV(:, t), 1e-16), 'r-', 'LineWidth', 1.5);
    plot(gens, max(Log.Epsilon(:, t), 1e-16), 'k--', 'LineWidth', 1);
    legend('Pop1 MeanCV', 'Pop2 MeanCV', 'Epsilon', 'Location', 'best');
    title(sprintf('T%d Constraint Violation', t));
    xlabel('Gen'); ylabel('CV');
    grid on;

    % Feasibility rate
    subplot(T, 3, (t - 1) * 3 + 3);
    plot(gens, Log.Pop1_FeasRate(:, t), 'b-', 'LineWidth', 1.5); hold on;
    plot(gens, Log.Pop2_FeasRate(:, t), 'r-', 'LineWidth', 1.5);
    legend('Pop1 (relaxed)', 'Pop2 (strict)', 'Location', 'best');
    title(sprintf('T%d Feasible Ratio', t));
    xlabel('Gen'); ylabel('Ratio');
    ylim([0, 1]);
    grid on;
end
sgtitle('Population Convergence & Constraint Handling');

%% Figure 3: Diversity & Partner Selection
figure('Name', 'Diversity & Partners', 'Position', [150 150 1200 600]);
for t = 1:T
    % Diversity
    subplot(T, 2, (t - 1) * 2 + 1);
    plot(gens, Log.Pop1_Diversity(:, t), 'b-', 'LineWidth', 1.5); hold on;
    plot(gens, Log.Pop2_Diversity(:, t), 'r-', 'LineWidth', 1.5);
    legend('Pop1', 'Pop2', 'Location', 'best');
    title(sprintf('T%d Dec Diversity (mean std)', t));
    xlabel('Gen'); ylabel('Diversity');
    grid on;

    % Partner task histogram
    subplot(T, 2, (t - 1) * 2 + 2);
    partners = Log.Partner(:, t);
    histogram(partners, 'BinMethod', 'integers');
    title(sprintf('T%d Partner Task Distribution', t));
    xlabel('Partner Task'); ylabel('Count');
    grid on;
end
sgtitle('Diversity & Partner Task Selection');

%% Figure 4: Transfer quality summary per phase
figure('Name', 'Transfer by Phase', 'Position', [200 200 1000 400]);
n_phases = 4;
phase_size = floor(nGen / n_phases);
phase_names = {};
for t = 1:T
    trans_better = zeros(1, n_phases);
    for p = 1:n_phases
        idx_start = (p - 1) * phase_size + 1;
        if p == n_phases
            idx_end = nGen;
        else
            idx_end = p * phase_size;
        end
        phase_trans = Log.Trans_AvgRank(idx_start:idx_end, t);
        phase_normal = Log.Normal_AvgRank(idx_start:idx_end, t);
        % Fraction of generations where transfer was better
        valid = ~isnan(phase_trans) & ~isnan(phase_normal);
        if any(valid)
            trans_better(p) = mean(phase_trans(valid) < phase_normal(valid));
        end
        if t == 1
            pct1 = round(idx_start / nGen * 100);
            pct2 = round(idx_end / nGen * 100);
            phase_names{p} = sprintf('%d%%-%d%%', pct1, pct2);
        end
    end
    subplot(1, T, t);
    bar(trans_better);
    xticklabels(phase_names);
    yline(0.5, 'k--');
    ylim([0, 1]);
    title(sprintf('T%d: Transfer Better Fraction', t));
    xlabel('Evolution Phase'); ylabel('Fraction');
    grid on;
end
sgtitle('When is transfer beneficial? (>0.5 = transfer helps)');

fprintf('\nDiagnostic plots complete.\n');
fprintf('Key insight: If Transfer AvgRank is consistently HIGHER than Normal,\n');
fprintf('then transfer is HURTING performance and RMP should be reduced.\n');
end
