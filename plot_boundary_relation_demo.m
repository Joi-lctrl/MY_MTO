clc; clear; close all;

figure('Color', 'w', 'Position', [80 80 1400 620]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

%% Task 1
task1.x_range = [-2.5, 2.5];
task1.y_range = [-2.5, 2.5];
task1.f = @(x1, x2) 0.7 * (x1 + 0.6).^2 + 1.0 * (x2 + 0.2).^2 + 0.25 * sin(1.8 * x1) .* cos(2.2 * x2);
task1.g = @(x1, x2) 0.9 * x1 - 0.7 * x2 + 0.15;
task1.feas_xy = [-0.95 -0.55;
                 -0.72 -0.42;
                 -0.86 -0.25;
                 -0.58 -0.62;
                 -0.63 -0.33;
                 -0.78 -0.48];
task1.ep_xy = [-0.22 -0.78;
               -0.08 -0.66;
               -0.12 -0.92;
                0.04 -0.74;
               -0.18 -0.56;
                0.10 -0.86];
task1.title = 'Task 1';

%% Task 2
task2.x_range = [-2.5, 2.5];
task2.y_range = [-2.5, 2.5];
task2.f = @(x1, x2) 0.55 * (x1 - 0.7).^2 + 1.25 * (x2 - 0.15).^2 + 0.22 * cos(2.1 * x1) .* sin(1.7 * x2);
task2.g = @(x1, x2) -0.65 * x1 - 0.85 * x2 - 0.05;
task2.feas_xy = [0.18 0.78;
                 0.34 0.58;
                 0.55 0.66;
                 0.28 0.94;
                 0.46 0.84;
                 0.12 0.62];
task2.ep_xy = [0.62 0.18;
               0.86 0.06;
               0.74 -0.12;
               0.96 0.22;
               0.68 0.32;
               0.88 -0.08];
task2.title = 'Task 2';

PlotTask(task1);
PlotTask(task2);

function PlotTask(task)
    nexttile;

    [x1, x2] = meshgrid(linspace(task.x_range(1), task.x_range(2), 140), ...
                        linspace(task.y_range(1), task.y_range(2), 140));
    f = task.f(x1, x2);
    g = task.g(x1, x2);

    feasible_mask = g <= 0;
    infeasible_mask = ~feasible_mask;

    f_feas = f;
    f_infeas = f;
    f_feas(infeasible_mask) = NaN;
    f_infeas(feasible_mask) = NaN;

    surf(x1, x2, f_feas, 'EdgeColor', 'none', 'FaceAlpha', 0.92, 'FaceColor', [0.62 0.82 0.62]);
    hold on;
    surf(x1, x2, f_infeas, 'EdgeColor', 'none', 'FaceAlpha', 0.55, 'FaceColor', [0.93 0.68 0.68]);
    shading interp;

    xb = linspace(task.x_range(1), task.x_range(2), 400);
    yb = nan(size(xb));
    for i = 1:numel(xb)
        x = xb(i);
        cands = linspace(task.y_range(1), task.y_range(2), 800);
        [~, idx] = min(abs(task.g(x * ones(size(cands)), cands)));
        if abs(task.g(x, cands(idx))) < 1e-2
            yb(i) = cands(idx);
        end
    end
    mask = ~isnan(yb);
    xb = xb(mask);
    yb = yb(mask);
    zb = task.f(xb, yb);
    plot3(xb, yb, zb, 'r-', 'LineWidth', 3);

    feas_z = task.f(task.feas_xy(:, 1), task.feas_xy(:, 2));
    ep_z = task.f(task.ep_xy(:, 1), task.ep_xy(:, 2));
    mu_f = mean(task.feas_xy, 1);
    mu_e = mean(task.ep_xy, 1);
    mu_fz = task.f(mu_f(1), mu_f(2));
    mu_ez = task.f(mu_e(1), mu_e(2));

    scatter3(task.feas_xy(:, 1), task.feas_xy(:, 2), feas_z, 75, ...
        [0.1 0.6 0.2], 'filled', 'MarkerEdgeColor', 'k');
    scatter3(task.ep_xy(:, 1), task.ep_xy(:, 2), ep_z, 75, ...
        [0.6 0.35 0.1], 'filled', 'MarkerEdgeColor', 'k');

    scatter3(mu_f(1), mu_f(2), mu_fz, 140, [0.0 0.45 0.0], 'filled', 'd');
    scatter3(mu_e(1), mu_e(2), mu_ez, 140, [0.55 0.25 0.05], 'filled', 'd');

    quiver3(mu_f(1), mu_f(2), mu_fz, ...
            mu_e(1) - mu_f(1), mu_e(2) - mu_f(2), mu_ez - mu_fz, ...
            0, 'k', 'LineWidth', 2, 'MaxHeadSize', 0.8);

    text(mu_f(1), mu_f(2), mu_fz + 0.12, '\mu_f', 'FontSize', 12, 'FontWeight', 'bold');
    text(mu_e(1), mu_e(2), mu_ez + 0.12, '\mu_{ep}', 'FontSize', 12, 'FontWeight', 'bold');
    text(mu_f(1) + 0.12, mu_f(2), mu_fz + 0.24, 'v_{be}', 'FontSize', 12, 'FontWeight', 'bold');

    xlabel('x_1', 'FontSize', 12);
    ylabel('x_2', 'FontSize', 12);
    zlabel('f(x_1, x_2)', 'FontSize', 12);
    title(task.title, 'FontSize', 14);

    legend({'Feasible region', 'Infeasible region', 'Constraint boundary', ...
            'Feasible population', 'Ep population', 'Feasible center', ...
            'Ep center', 'Relation vector'}, ...
            'Location', 'northeastoutside');

    view(46, 26);
    grid on;
    box on;
    camlight headlight;
    lighting gouraud;
end
