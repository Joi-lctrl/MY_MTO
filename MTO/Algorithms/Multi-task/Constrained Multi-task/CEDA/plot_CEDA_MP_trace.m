function plot_CEDA_MP_trace(logfile)
% Visualize trace log from CEDA_MP_Trace.
% Example:
%   mto({CEDA_MP_Trace()}, {CMT5()}, 'Reps', 1, 'Global_Seed', 2333);
%   plot_CEDA_MP_trace;

if nargin < 1
    logfile = 'CEDA_MP_Trace_Log.mat';
end

data = load(logfile);
Log = data.Log;
T = Log.T;
gens = 1:Log.TotalGen;

fprintf('Problem: %s | Tasks: %d | RMP1: %.3f | RMP2: %.3f\n', ...
    Log.ProbName, T, Log.RMP1, Log.RMP2);

%% Figure 1: strict vs relaxed ranking of transfer offspring
figure('Name', 'Transfer Offspring Quality', 'Position', [80 80 1300 800]);
for t = 1:T
    subplot(T, 3, (t - 1) * 3 + 1);
    plot(gens, Log.Off1_Trans_AvgRankStrict(:, t), 'b-', 'LineWidth', 1); hold on;
    plot(gens, Log.Off1_Normal_AvgRankStrict(:, t), 'r-', 'LineWidth', 1);
    title(sprintf('T%d Strict Rank', t));
    xlabel('Gen'); ylabel('Avg Rank');
    legend('Transfer', 'Normal', 'Location', 'best');
    grid on;

    subplot(T, 3, (t - 1) * 3 + 2);
    plot(gens, Log.Off1_Trans_AvgRankRelaxed(:, t), 'b-', 'LineWidth', 1); hold on;
    plot(gens, Log.Off1_Normal_AvgRankRelaxed(:, t), 'r-', 'LineWidth', 1);
    title(sprintf('T%d Relaxed Rank', t));
    xlabel('Gen'); ylabel('Avg Rank');
    legend('Transfer', 'Normal', 'Location', 'best');
    grid on;

    subplot(T, 3, (t - 1) * 3 + 3);
    plot(gens, Log.Epsilon(:, t), 'k--', 'LineWidth', 1.2); hold on;
    semilogy(gens, max(Log.Pop1_Pre_MeanCV(:, t), 1e-16), 'b-', 'LineWidth', 1);
    semilogy(gens, max(Log.Pop2_Pre_MeanCV(:, t), 1e-16), 'r-', 'LineWidth', 1);
    title(sprintf('T%d Epsilon / MeanCV', t));
    xlabel('Gen'); ylabel('CV');
    legend('Epsilon', 'Pop1 MeanCV', 'Pop2 MeanCV', 'Location', 'best');
    grid on;
end
sgtitle('Strict vs Relaxed View of Transfer Quality');

%% Figure 2: offspring survival into Pop1 / Pop2
figure('Name', 'Transfer Survival', 'Position', [120 120 1300 800]);
for t = 1:T
    subplot(T, 3, (t - 1) * 3 + 1);
    plot(gens, Log.Pop1_TransSurvivalRate(:, t), 'b-', 'LineWidth', 1.2); hold on;
    plot(gens, Log.Pop1_NormalSurvivalRate(:, t), 'r-', 'LineWidth', 1.2);
    yline(0.5, 'k--');
    title(sprintf('T%d Pop1 Survival', t));
    xlabel('Gen'); ylabel('Rate');
    legend('Transfer', 'Normal', 'Location', 'best');
    ylim([0, 1]);
    grid on;

    subplot(T, 3, (t - 1) * 3 + 2);
    plot(gens, Log.Pop2_TransSurvivalRate(:, t), 'b-', 'LineWidth', 1.2); hold on;
    plot(gens, Log.Pop2_NormalSurvivalRate(:, t), 'r-', 'LineWidth', 1.2);
    yline(0.5, 'k--');
    title(sprintf('T%d Pop2 Survival', t));
    xlabel('Gen'); ylabel('Rate');
    legend('Transfer', 'Normal', 'Location', 'best');
    ylim([0, 1]);
    grid on;

    subplot(T, 3, (t - 1) * 3 + 3);
    bar(gens, [Log.Pop1_SelectedOff1Count(:, t), Log.Pop1_SelectedOff2Count(:, t)], 'stacked');
    title(sprintf('T%d Pop1 Selected Offspring', t));
    xlabel('Gen'); ylabel('Count');
    legend('From Offspring1', 'From Offspring2', 'Location', 'best');
    grid on;
end
sgtitle('Do Transfer Offspring Actually Survive Selection?');

%% Figure 3: pre/post population effect
figure('Name', 'Population Effect', 'Position', [160 160 1300 800]);
for t = 1:T
    subplot(T, 3, (t - 1) * 3 + 1);
    semilogy(gens, max(Log.Pop1_Pre_BestFeasibleObj(:, t), 1e-16), 'b--', 'LineWidth', 1); hold on;
    semilogy(gens, max(Log.Pop1_Post_BestFeasibleObj(:, t), 1e-16), 'b-', 'LineWidth', 1.5);
    semilogy(gens, max(Log.Pop2_Post_BestFeasibleObj(:, t), 1e-16), 'r-', 'LineWidth', 1.2);
    title(sprintf('T%d Best Feasible Obj', t));
    xlabel('Gen'); ylabel('Obj');
    legend('Pop1 Pre', 'Pop1 Post', 'Pop2 Post', 'Location', 'best');
    grid on;

    subplot(T, 3, (t - 1) * 3 + 2);
    plot(gens, Log.Pop1_Pre_FeasRate(:, t), 'b--', 'LineWidth', 1); hold on;
    plot(gens, Log.Pop1_Post_FeasRate(:, t), 'b-', 'LineWidth', 1.5);
    plot(gens, Log.Pop2_Post_FeasRate(:, t), 'r-', 'LineWidth', 1.2);
    title(sprintf('T%d Feasible Ratio', t));
    xlabel('Gen'); ylabel('Ratio');
    legend('Pop1 Pre', 'Pop1 Post', 'Pop2 Post', 'Location', 'best');
    ylim([0, 1]);
    grid on;

    subplot(T, 3, (t - 1) * 3 + 3);
    plot(gens, Log.Pop1_Post_Diversity(:, t), 'b-', 'LineWidth', 1.5); hold on;
    plot(gens, Log.Pop2_Post_Diversity(:, t), 'r-', 'LineWidth', 1.2);
    title(sprintf('T%d Diversity', t));
    xlabel('Gen'); ylabel('Mean Std');
    legend('Pop1 Post', 'Pop2 Post', 'Location', 'best');
    grid on;
end
sgtitle('Population Change Before and After Selection');
end
