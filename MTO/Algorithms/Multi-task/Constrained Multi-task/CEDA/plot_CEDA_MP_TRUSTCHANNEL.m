function plot_CEDA_MP_TRUSTCHANNEL(logfile)
% Visualize trust-channel diagnostics from CEDA_MP_TRUSTCHANNEL.
% Example:
%   mto({CEDA_MP_TRUSTCHANNEL()}, {CMT5()}, 'Reps', 1, 'Global_Seed', 2333);
%   plot_CEDA_MP_TRUSTCHANNEL;

if nargin < 1
    logfile = 'CEDA_MP_TRUSTCHANNEL_Log.mat';
end

data = load(logfile);
Log = data.Log;
T = Log.T;
nGen = Log.TotalGen;
gens = 1:nGen;

fprintf('Problem: %s | Tasks: %d | Generations: %d\n', Log.ProbName, T, nGen);

figure('Name', 'Trust-Channel State Counts', 'Position', [50 50 1200 800]);
for t = 1:T
    subplot(T, 1, t);
    plot(gens, Log.StateCountF(:, t), 'g-', 'LineWidth', 1.5); hold on;
    plot(gens, Log.StateCountB(:, t), 'b-', 'LineWidth', 1.5);
    plot(gens, Log.StateCountI(:, t), 'r-', 'LineWidth', 1.5);
    legend('F', 'B', 'I', 'Location', 'best');
    title(sprintf('Task %d State Counts', t));
    xlabel('Generation');
    ylabel('Count');
    grid on;
end
sgtitle('Trust-Channel State Population');

figure('Name', 'Trust-Channel Mean Trust', 'Position', [80 80 1200 800]);
for t = 1:T
    subplot(T, 1, t);
    plot(gens, Log.TrustMeanF(:, t), 'g-', 'LineWidth', 1.5); hold on;
    plot(gens, Log.TrustMeanB(:, t), 'b-', 'LineWidth', 1.5);
    plot(gens, Log.TrustMeanI(:, t), 'r-', 'LineWidth', 1.5);
    ylim([0, 1]);
    legend('F', 'B', 'I', 'Location', 'best');
    title(sprintf('Task %d Mean Trust', t));
    xlabel('Generation');
    ylabel('Trust');
    grid on;
end
sgtitle('Mean Trust by State Channel');

figure('Name', 'Trust-Channel Accepted Transfers', 'Position', [110 110 1200 800]);
for t = 1:T
    subplot(T, 1, t);
    bar(gens, [Log.AcceptCountF(:, t), Log.AcceptCountB(:, t), Log.AcceptCountI(:, t)], 'stacked');
    legend('F', 'B', 'I', 'Location', 'best');
    title(sprintf('Task %d Accepted Transfers', t));
    xlabel('Generation');
    ylabel('Count');
    grid on;
end
sgtitle('Accepted Transfers by State Channel');

figure('Name', 'Trust-Channel Constraint Gains', 'Position', [140 140 1200 800]);
for t = 1:T
    subplot(T, 2, 2 * t - 1);
    bar(gens, [Log.CVImproveCountF(:, t), Log.CVImproveCountB(:, t), Log.CVImproveCountI(:, t)], 'stacked');
    legend('F', 'B', 'I', 'Location', 'best');
    title(sprintf('Task %d CV Improvements', t));
    xlabel('Generation');
    ylabel('Count');
    grid on;

    subplot(T, 2, 2 * t);
    bar(gens, [Log.BecomeFeasibleCountF(:, t), Log.BecomeFeasibleCountB(:, t), Log.BecomeFeasibleCountI(:, t)], 'stacked');
    legend('F', 'B', 'I', 'Location', 'best');
    title(sprintf('Task %d Become Feasible', t));
    xlabel('Generation');
    ylabel('Count');
    grid on;
end
sgtitle('Constraint Improvement Diagnostics');
end
