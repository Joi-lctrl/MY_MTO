classdef Ship_Panel_Problem < handle
% Ship panel grillage optimization problem definition.
% Task 1: s_long=800, s_rib=2400, q1=6, t_plate=12, n_long=3 (12 vars)
% Task 2: s_long=1000, s_rib=3200, q1=25/3, t_plate=16, n_long=3 (12 vars)
% Task 3: s_long=1600, s_rib=1200, q1=12, t_plate=10, n_long=3 (20 vars)
% Task 4: s_long=2400, s_rib=1800, q1=50/3, t_plate=12, n_long=3 (20 vars)
% Task 5: s_long=2400, s_rib=800, q1=25/3, t_plate=12, n_long=5 (16 vars)
% Task 6: s_long=2400, s_rib=800, q1=6, t_plate=12, n_long=3, n_rib=6 (12 vars)
% Task 7: based on Task 3, q1=25/3 (12 vars)
% Task 8: s_long=3000, s_rib=1600, q1=10, t_plate=12, n_long=7, n_rib=9 (36 vars)
% Task 9: s_long=3000, s_rib=2000, q1=25, t_plate=14, n_long=7, n_rib=9 (36 vars)

properties
    T = 9  % Number of tasks
    Tasks struct
end

methods
    function obj = Ship_Panel_Problem()
        obj.Tasks = obj.defineTasks();
    end

    function [lb, x0, ub] = get_design_space(obj, task_id)
        t = obj.Tasks(task_id);
        lb = t.lb;
        ub = t.ub;
        x0 = (lb + ub) / 2;
    end

    function tasks = defineTasks(obj)
        % Variable order for tasks 1-2 and 5-7 (12 vars):
        % [h_web_L1, t_web_L1, b_bot_L1, t_bot_L1,   % center longitudinal free flange
        %  h_web_L2, t_web_L2, b_bot_L2, t_bot_L2,   % side longitudinal free flange
        %  h_web_R,  t_web_R,  b_bot_R,  t_bot_R]     % rib free flange
        %
        % Variable order for tasks 3-4 (20 vars):
        % [L1(4), L2(4), R1(4), R2(4), R3(4)]
        % Longitudinal physical order: [L2, L1, L2]
        % Rib physical order: [R3, R2, R1, R2, R3]
        %
        % n_long=5: same 12 vars, L3 (outer) = L2 (inner side)
        %
        % Variable order for tasks 8-9 (36 vars):
        % [L1(4), L2(4), L3(4), L4(4), R1(4), R2(4), R3(4), R4(4), R5(4)]
        % Longitudinal physical order: [L4, L3, L2, L1, L2, L3, L4]
        % Rib physical order: [R5, R4, R3, R2, R1, R2, R3, R4, R5]

        % Task 1
        tasks(1).name = 'Task1';
        tasks(1).s_long = 800;
        tasks(1).s_rib = 2400;
        tasks(1).q1 = 6;
        tasks(1).t_plate = 12;
        tasks(1).n_long = 3;
        tasks(1).n_rib = 5;
        tasks(1).long_group_count = 2;
        tasks(1).rib_group_count = 1;
        tasks(1).sigma_allow = 55;
        tasks(1).bend_allow = 33;    % 0.6 * sigma_allow
        tasks(1).shear_allow = 16.5; % 0.3 * sigma_allow
        tasks(1).b_top_long = 400;   % equivalent plate width for longitudinals
        tasks(1).b_top_rib = 133;    % equivalent plate width for ribs
        tasks(1).lb = [200, 7, 60, 7, 200, 7, 60, 7, 200, 7, 60, 7];
        tasks(1).ub = [400, 12, 160, 14, 400, 12, 160, 14, 400, 12, 160, 14];

        % Task 2
        tasks(2).name = 'Task2';
        tasks(2).s_long = 1000;
        tasks(2).s_rib = 3200;
        tasks(2).q1 = 25 / 3;
        tasks(2).t_plate = 16;
        tasks(2).n_long = 3;
        tasks(2).n_rib = 5;
        tasks(2).long_group_count = 2;
        tasks(2).rib_group_count = 1;
        tasks(2).sigma_allow = 60;
        tasks(2).bend_allow = 36;    % 0.6 * sigma_allow
        tasks(2).shear_allow = 18;   % 0.3 * sigma_allow
        tasks(2).b_top_long = 500;   % equivalent plate width for longitudinals
        tasks(2).b_top_rib = 166;    % equivalent plate width for ribs
        tasks(2).lb = [250, 8, 80, 8, 250, 8, 80, 8, 250, 8, 80, 8];
        tasks(2).ub = [480, 14, 200, 16, 480, 14, 200, 16, 480, 14, 200, 16];

        % Task 3: aligned with Task 8 parameter system, but using a 3x5 layout
        tasks(3).name = 'Task3';
        tasks(3).s_long = 1600;
        tasks(3).s_rib = 1200;
        tasks(3).q1 = 12;
        tasks(3).t_plate = 10;
        tasks(3).n_long = 3;
        tasks(3).n_rib = 5;
        tasks(3).long_group_count = 2;
        tasks(3).rib_group_count = 3;
        tasks(3).enable_group_slenderness = true;
        tasks(3).sigma_allow = 110;
        tasks(3).bend_allow = 66;    % 0.6 * sigma_allow
        tasks(3).shear_allow = 33;   % 0.3 * sigma_allow
        tasks(3).lambda_flange_long = 15;
        tasks(3).lambda_flange_rib = 15;
        tasks(3).enforce_rib_web_below_long_web = false;
        [tasks(3).b_top_long, tasks(3).b_top_rib] = ...
            obj.compute_task_position_eq_plate_widths(tasks(3), 3);
        task34_long_group_lb = [250, 5, 150, 10];
        task34_long_group_ub = [550, 11, 300, 20];
        task34_rib_group_lb = [150, 5, 150, 5];
        task34_rib_group_ub = [300, 11, 300, 11];
        tasks(3).lb = [repmat(task34_long_group_lb, 1, 2), repmat(task34_rib_group_lb, 1, 3)];
        tasks(3).ub = [repmat(task34_long_group_ub, 1, 2), repmat(task34_rib_group_ub, 1, 3)];

        % Task 4: aligned with Task 9 parameter system, but using a 3x5 layout
        tasks(4).name = 'Task4';
        tasks(4).s_long = 2400;
        tasks(4).s_rib = 1800;
        tasks(4).q1 = 50 / 3;
        tasks(4).t_plate = 12;
        tasks(4).n_long = 3;
        tasks(4).n_rib = 5;
        tasks(4).long_group_count = 2;
        tasks(4).rib_group_count = 3;
        tasks(4).enable_group_slenderness = true;
        tasks(4).sigma_allow = 220;
        tasks(4).bend_allow = 132;   % 0.6 * sigma_allow
        tasks(4).shear_allow = 66;   % 0.3 * sigma_allow
        tasks(4).lambda_flange_long = tasks(3).lambda_flange_long;
        tasks(4).lambda_flange_rib = tasks(3).lambda_flange_rib;
        tasks(4).enforce_rib_web_below_long_web = tasks(3).enforce_rib_web_below_long_web;
        [tasks(4).b_top_long, tasks(4).b_top_rib] = ...
            obj.compute_task_position_eq_plate_widths(tasks(4), 4);
        tasks(4).lb = tasks(3).lb;
        tasks(4).ub = tasks(3).ub;

        % Task 5: based on Task 4, n_rib=7 (add outer pair of ribs)
        tasks(5).name = 'Task5';
        tasks(5).s_long = tasks(4).s_long;
        tasks(5).s_rib = tasks(4).s_rib;
        tasks(5).q1 = tasks(4).q1;
        tasks(5).t_plate = tasks(4).t_plate;
        tasks(5).n_long = tasks(4).n_long;
        tasks(5).n_rib = 7;
        tasks(5).long_group_count = tasks(4).long_group_count;
        tasks(5).rib_group_count = 4;
        tasks(5).enable_group_slenderness = tasks(4).enable_group_slenderness;
        tasks(5).sigma_allow = tasks(4).sigma_allow;
        tasks(5).bend_allow = tasks(4).bend_allow;
        tasks(5).shear_allow = tasks(4).shear_allow;
        tasks(5).lambda_flange_long = tasks(4).lambda_flange_long;
        tasks(5).lambda_flange_rib = tasks(4).lambda_flange_rib;
        tasks(5).enforce_rib_web_below_long_web = tasks(4).enforce_rib_web_below_long_web;
        [tasks(5).b_top_long, tasks(5).b_top_rib] = ...
            obj.compute_task_position_eq_plate_widths(tasks(5), 5);
        tasks(5).lb = [tasks(4).lb, task34_rib_group_lb];
        tasks(5).ub = [tasks(4).ub, task34_rib_group_ub];

        % Task 6: based on Task 3, n_rib=6 (add one rib)
        tasks(6).name = 'Task6';
        tasks(6).s_long = 2400;
        tasks(6).s_rib = 800;
        tasks(6).q1 = 6;
        tasks(6).t_plate = 12;
        tasks(6).n_long = 3;
        tasks(6).n_rib = 6;
        tasks(6).long_group_count = 2;
        tasks(6).rib_group_count = 1;
        tasks(6).sigma_allow = 230;
        tasks(6).bend_allow = 138;   % 0.6 * sigma_allow
        tasks(6).shear_allow = 69;   % 0.3 * sigma_allow
        tasks(6).b_top_long = 133;   % equivalent plate width for longitudinals
        tasks(6).b_top_rib = 400;    % equivalent plate width for ribs
        tasks(6).lb = [250, 7, 100, 8, 250, 7, 100, 8, 120, 6, 50, 6];
        tasks(6).ub = [450, 12, 200, 14, 450, 12, 200, 14, 250, 11, 120, 12];

        % Task 7: based on Task 3, q1=25/3 (pure load variant)
        tasks(7).name = 'Task7';
        tasks(7).s_long = 2400;
        tasks(7).s_rib = 800;
        tasks(7).q1 = 25 / 3;
        tasks(7).t_plate = 12;
        tasks(7).n_long = 3;
        tasks(7).n_rib = 5;
        tasks(7).long_group_count = 2;
        tasks(7).rib_group_count = 1;
        tasks(7).sigma_allow = 100;
        tasks(7).bend_allow = 60;   % same allowable pair as Task 3
        tasks(7).shear_allow = 30;   % same allowable pair as Task 3
        tasks(7).b_top_long = 133;   % equivalent plate width for longitudinals
        tasks(7).b_top_rib = 400;    % equivalent plate width for ribs
        tasks(7).lb = [250, 7, 100, 8, 250, 7, 100, 8, 120, 6, 50, 6];
        tasks(7).ub = [450, 12, 200, 14, 450, 12, 200, 14, 250, 11, 120, 12];

        % Task 8: grouped 7-longitudinal, 9-rib layout with five rib groups
        tasks(8).name = 'Task8';
        tasks(8).s_long = 3000;
        tasks(8).s_rib = 1600;
        tasks(8).q1 = 10;
        tasks(8).t_plate = 12;
        tasks(8).n_long = 7;
        tasks(8).n_rib = 9;
        tasks(8).long_group_count = 4;
        tasks(8).rib_group_count = 5;
        tasks(8).enable_group_slenderness = true;
        tasks(8).sigma_allow = 400;
        tasks(8).bend_allow = 234;
        tasks(8).shear_allow = 117;
        tasks(8).lambda_flange_long = 15;
        tasks(8).lambda_flange_rib = 15;
        [tasks(8).b_top_long, tasks(8).b_top_rib] = ...
            obj.compute_task_position_eq_plate_widths(tasks(8), 8);
        task8_long_group_lb = [350, 6, 450, 12];
        task8_long_group_ub = [650, 12, 600, 22];
        task8_rib_group_lb = [200, 6, 350, 6];
        task8_rib_group_ub = [350, 12, 500, 12];
        tasks(8).lb = [repmat(task8_long_group_lb, 1, 4), repmat(task8_rib_group_lb, 1, 5)];
        tasks(8).ub = [repmat(task8_long_group_ub, 1, 4), repmat(task8_rib_group_ub, 1, 5)];

        % Task 9: grouped 7-longitudinal, 9-rib load variant with five rib groups
        tasks(9).name = 'Task9';
        tasks(9).s_long = 3000;
        tasks(9).s_rib = 2000;
        tasks(9).q1 = 25;
        tasks(9).t_plate = 14;
        tasks(9).n_long = 7;
        tasks(9).n_rib = 9;
        tasks(9).long_group_count = 4;
        tasks(9).rib_group_count = 5;
        tasks(9).enable_group_slenderness = true;
        tasks(9).sigma_allow = 900;
        tasks(9).bend_allow = 234;
        tasks(9).shear_allow = 117;
        tasks(9).lambda_flange_long = tasks(8).lambda_flange_long;
        tasks(9).lambda_flange_rib = tasks(8).lambda_flange_rib;
        [tasks(9).b_top_long, tasks(9).b_top_rib] = ...
            obj.compute_task_position_eq_plate_widths(tasks(9), 9);
        tasks(9).lb = [repmat(task34_long_group_lb, 1, 4), repmat(task34_rib_group_lb, 1, 5)];
        tasks(9).ub = [repmat(task34_long_group_ub, 1, 4), repmat(task34_rib_group_ub, 1, 5)];
    end

    function [long_widths, rib_widths] = compute_task_position_eq_plate_widths(obj, task, task_id)
        [long_ext, rib_ext] = obj.get_task_end_extensions(task_id, task);
        L_span = (task.n_rib - 1) * task.s_rib;
        W_span = (task.n_long - 1) * task.s_long;
        long_positions = 0:task.s_long:W_span;
        rib_positions = 0:task.s_rib:L_span;
        L_long = L_span + 2 * long_ext;
        L_rib = W_span + 2 * rib_ext;

        long_widths = obj.compute_position_plate_widths( ...
            long_positions, -rib_ext, W_span + rib_ext, L_long);
        rib_widths = obj.compute_position_plate_widths( ...
            rib_positions, -long_ext, L_span + long_ext, L_rib);
    end

    function widths = compute_position_plate_widths(~, positions, lower_bound, upper_bound, total_span)
        widths = zeros(1, numel(positions));
        span_limit = total_span / 6;

        for idx = 1:numel(positions)
            if idx == 1
                d_left = positions(idx) - lower_bound;
            else
                d_left = positions(idx) - positions(idx - 1);
            end

            if idx == numel(positions)
                d_right = upper_bound - positions(idx);
            else
                d_right = positions(idx + 1) - positions(idx);
            end

            widths(idx) = min(span_limit, (d_left + d_right) / 2);
        end
    end

    function [long_ext, rib_ext] = get_task_end_extensions(~, task_id, task)
        if any(task_id == [3, 4, 5, 8, 9])
            long_ext = task.s_rib;
            rib_ext = task.s_long / 2;
        else
            long_ext = task.s_rib / 2;
            rib_ext = task.s_long / 2;
        end
    end

    function [long_mesh_div, rib_mesh_div] = get_task_mesh_divisions(~, task_id)
        long_mesh_div = 20;
        if any(task_id == [8, 9])
            rib_mesh_div = 5;
        else
            rib_mesh_div = 5;
        end
    end

    function [long_widths, rib_widths] = get_member_eq_plate_widths(~, task)
        if isscalar(task.b_top_long)
            long_widths = repmat(task.b_top_long, 1, task.n_long);
        else
            long_widths = reshape(task.b_top_long, 1, []);
        end

        if isscalar(task.b_top_rib)
            rib_widths = repmat(task.b_top_rib, 1, task.n_rib);
        else
            rib_widths = reshape(task.b_top_rib, 1, []);
        end
    end

    function group_widths = collapse_member_widths_to_groups(~, member_widths, member_map, group_count)
        group_widths = nan(1, group_count);
        for idx = 1:numel(member_widths)
            group_id = member_map(idx);
            if isnan(group_widths(group_id))
                group_widths(group_id) = member_widths(idx);
            end
        end
    end

    function [long_groups, rib_groups] = parse_grouped_sections(~, x, task)
        long_group_count = task.long_group_count;
        rib_group_count = task.rib_group_count;
        long_var_count = 4 * long_group_count;
        rib_var_count = 4 * rib_group_count;

        long_groups = reshape(x(1:long_var_count), 4, long_group_count).';
        rib_groups = reshape(x(long_var_count + 1:long_var_count + rib_var_count), 4, rib_group_count).';
    end

    function long_map = get_long_group_map(~, task)
        if task.n_long == 7
            long_map = [4, 3, 2, 1, 2, 3, 4];
        elseif task.n_long == 5
            long_map = [2, 2, 1, 2, 2];
        else
            long_map = [2, 1, 2];
        end
    end

    function rib_map = get_rib_group_map(~, task)
        if task.rib_group_count == 5
            rib_map = [5, 4, 3, 2, 1, 2, 3, 4, 5];
        elseif task.rib_group_count == 4 && task.n_rib == 7
            rib_map = [4, 3, 2, 1, 2, 3, 4];
        elseif task.rib_group_count == 2 && task.n_rib == 9
            rib_map = [2, 2, 2, 1, 1, 1, 2, 2, 2];
        elseif task.rib_group_count == 3 && task.n_rib == 5
            rib_map = [3, 2, 1, 2, 3];
        else
            rib_map = ones(1, task.n_rib);
        end
    end

    function long_sec_map = get_long_section_map(~, task)
        if task.n_long == 7
            long_sec_map = [4, 3, 2, 1, 2, 3, 4];
        elseif task.n_long == 5
            long_sec_map = [4, 2, 1, 2, 4];
        else
            long_sec_map = [2, 1, 2];
        end
    end

    function rib_sec_map = get_rib_section_map(~, task)
        if task.rib_group_count == 5
            rib_sec_map = [9, 8, 7, 6, 5, 6, 7, 8, 9];
        elseif task.rib_group_count == 4 && task.n_rib == 7
            rib_sec_map = [6, 5, 4, 3, 4, 5, 6];
        elseif task.rib_group_count == 2 && task.n_rib == 9
            rib_sec_map = [6, 6, 6, 5, 5, 5, 6, 6, 6];
        elseif task.rib_group_count == 1 && task.n_rib == 9 && task.long_group_count == 4
            rib_sec_map = 5 * ones(1, task.n_rib);
        elseif task.rib_group_count == 3 && task.n_rib == 5
            rib_sec_map = [5, 4, 3, 4, 5];
        else
            rib_sec_map = 3 * ones(1, task.n_rib);
        end
    end

    function [sec_ids, group_ids, sec_names] = get_long_section_layout(~, task)
        if task.long_group_count == 4
            sec_ids = 1:4;
            group_ids = 1:4;
            sec_names = {'LONG_1', 'LONG_2', 'LONG_3', 'LONG_4'};
        elseif task.n_long == 5
            sec_ids = [1, 2, 4];
            group_ids = [1, 2, 2];
            sec_names = {'LONG_C', 'LONG_S', 'LONG_O'};
        else
            sec_ids = [1, 2];
            group_ids = [1, 2];
            sec_names = {'LONG_C', 'LONG_S'};
        end
    end

    function [sec_ids, group_ids, sec_names] = get_rib_section_layout(~, task)
        if task.rib_group_count == 5
            sec_ids = 5:9;
            group_ids = 1:5;
            sec_names = {'RIB_1', 'RIB_2', 'RIB_3', 'RIB_4', 'RIB_5'};
        elseif task.rib_group_count == 4 && task.n_rib == 7
            sec_ids = 3:6;
            group_ids = 1:4;
            sec_names = {'RIB_1', 'RIB_2', 'RIB_3', 'RIB_4'};
        elseif task.rib_group_count == 2 && task.n_rib == 9
            sec_ids = [5, 6];
            group_ids = [1, 2];
            sec_names = {'RIB_C3', 'RIB_O6'};
        elseif task.rib_group_count == 1 && task.n_rib == 9 && task.long_group_count == 4
            sec_ids = 5;
            group_ids = 1;
            sec_names = {'RIB'};
        elseif task.rib_group_count == 3 && task.n_rib == 5
            sec_ids = 3:5;
            group_ids = 1:3;
            sec_names = {'RIB_C', 'RIB_S', 'RIB_O'};
        else
            sec_ids = 3;
            group_ids = 1;
            sec_names = {'RIB'};
        end
    end

    function mac_str = generate_mac(obj, x, task_id)
        % Generate APDL macro string from design variables.
        % Supports legacy 12-variable layouts and grouped multi-group layouts.
        t = obj.Tasks(task_id);

        s_long = t.s_long;
        s_rib = t.s_rib;
        q1 = t.q1;
        t_plate = t.t_plate;
        n_long = t.n_long;
        n_rib = t.n_rib;
        t_eq_plate = t_plate;
        [long_ext, rib_ext] = obj.get_task_end_extensions(task_id, t);
        [long_mesh_div, rib_mesh_div] = obj.get_task_mesh_divisions(task_id);
        L_span = (n_rib - 1) * s_rib;
        W_span = (n_long - 1) * s_long;
        X_left = -long_ext;
        X_right = L_span + long_ext;
        Y_bottom = -rib_ext;
        Y_top = rib_ext + W_span;

        [long_groups, rib_groups] = obj.parse_grouped_sections(x, t);
        [long_member_eq, rib_member_eq] = obj.get_member_eq_plate_widths(t);
        long_sec_map = obj.get_long_section_map(t);
        rib_sec_map = obj.get_rib_section_map(t);
        long_group_eq = obj.collapse_member_widths_to_groups(long_member_eq, obj.get_long_group_map(t), t.long_group_count);
        rib_group_eq = obj.collapse_member_widths_to_groups(rib_member_eq, obj.get_rib_group_map(t), t.rib_group_count);
        [long_sec_ids, long_sec_group_ids, long_sec_names] = obj.get_long_section_layout(t);
        [rib_sec_ids, rib_sec_group_ids, rib_sec_names] = obj.get_rib_section_layout(t);

        mac = {};
        mac{end+1} = 'FINISH';
        mac{end+1} = '/CLEAR, START';
        mac{end+1} = sprintf('/TITLE, %s_opt', t.name);
        mac{end+1} = '/NOPR';
        mac{end+1} = '';
        mac{end+1} = '/PREP7';
        mac{end+1} = 'ET, 1, BEAM188';
        mac{end+1} = 'KEYOPT, 1, 4, 2';
        mac{end+1} = '';
        mac{end+1} = 'MP, EX, 1, 2.06e5';
        mac{end+1} = 'MP, PRXY, 1, 0.3';
        mac{end+1} = 'MP, DENS, 1, 7.85e-9';
        mac{end+1} = '';
        mac = [mac, obj.build_task_metadata_comment_lines(t)];

        % Section definitions:
        % W1/t1 = short/free flange, W2/t2 = long/equivalent-plate flange.
        for idx = 1:numel(long_sec_ids)
            group = long_sec_group_ids(idx);
            sec = long_groups(group, :);
            h_total = sec(4) + sec(1) + t_eq_plate;
            mac{end+1} = sprintf('SECTYPE, %d, BEAM, I, %s, 5', ...
                long_sec_ids(idx), long_sec_names{idx});
            mac{end+1} = sprintf('SECDATA, %g, %g, %g, %g, %g, %g', ...
                sec(3), long_group_eq(group), h_total, sec(4), t_eq_plate, sec(2));
        end
        for idx = 1:numel(rib_sec_ids)
            group = rib_sec_group_ids(idx);
            sec = rib_groups(group, :);
            h_total = sec(4) + sec(1) + t_eq_plate;
            mac{end+1} = sprintf('SECTYPE, %d, BEAM, I, %s, 5', ...
                rib_sec_ids(idx), rib_sec_names{idx});
            mac{end+1} = sprintf('SECDATA, %g, %g, %g, %g, %g, %g', ...
                sec(3), rib_group_eq(group), h_total, sec(4), t_eq_plate, sec(2));
        end
        mac{end+1} = '';

        % --- Keypoints ---
        pprow = n_rib + 2;  % points per longitudinal row (incl. extensions)

        % Longitudinal keypoints: KP(i,j) = i*pprow + j + 1
        for ii = 0:n_long-1
            Y_i = ii * s_long;
            for jj = 0:pprow-1
                kp = ii * pprow + jj + 1;
                if jj == 0
                    X_j = X_left;
                elseif jj == pprow - 1
                    X_j = X_right;
                else
                    X_j = (jj - 1) * s_rib;
                end
                mac{end+1} = sprintf('K, %d, %g, %g, 0', kp, X_j, Y_i);
            end
        end

        % Rib extension keypoints
        kp_base_rib = n_long * pprow;
        for rr = 0:n_rib-1
            X_r = rr * s_rib;
            kp_bot = kp_base_rib + 2*rr + 1;
            kp_top_r = kp_base_rib + 2*rr + 2;
            mac{end+1} = sprintf('K, %d, %g, %g, 0', kp_bot, X_r, Y_bottom);
            mac{end+1} = sprintf('K, %d, %g, %g, 0', kp_top_r, X_r, Y_top);
        end
        mac{end+1} = '';

        % --- Lines ---
        line_num = 0;
        long_line_ranges = zeros(n_long, 2);  % [first, last] line per longitudinal

        % Longitudinal lines
        for ii = 0:n_long-1
            first_line = line_num + 1;
            for jj = 0:pprow-2
                kp1 = ii * pprow + jj + 1;
                kp2 = ii * pprow + jj + 2;
                mac{end+1} = sprintf('L, %d, %d', kp1, kp2);
                line_num = line_num + 1;
            end
            long_line_ranges(ii+1, :) = [first_line, line_num];
        end

        % Rib lines
        rib_line_ranges = zeros(n_rib, 2);
        for rr = 0:n_rib-1
            first_line = line_num + 1;
            kp_bot = kp_base_rib + 2*rr + 1;
            kp_top_r = kp_base_rib + 2*rr + 2;

            % Bottom extension to first longitudinal
            kp_long_0 = 0 * pprow + (rr + 1) + 1;
            mac{end+1} = sprintf('L, %d, %d', kp_bot, kp_long_0);
            line_num = line_num + 1;

            % Between adjacent longitudinals
            for ii = 0:n_long-2
                kp1 = ii * pprow + (rr + 1) + 1;
                kp2 = (ii + 1) * pprow + (rr + 1) + 1;
                mac{end+1} = sprintf('L, %d, %d', kp1, kp2);
                line_num = line_num + 1;
            end

            % Last longitudinal to top extension
            kp_last = (n_long - 1) * pprow + (rr + 1) + 1;
            mac{end+1} = sprintf('L, %d, %d', kp_last, kp_top_r);
            line_num = line_num + 1;

            rib_line_ranges(rr+1, :) = [first_line, line_num];
        end
        mac{end+1} = '';

        % --- Orientation keypoints ---
        % Longitudinals: KP 1001+2*i (left), 1001+2*i+1 (right)
        for ii = 0:n_long-1
            Y_i = ii * s_long;
            kp_ori = 1001 + 2*ii;
            mac{end+1} = sprintf('K, %d, %g, %g, -1000', kp_ori, X_left, Y_i);
            mac{end+1} = sprintf('K, %d, %g, %g, -1000', kp_ori+1, X_right, Y_i);
        end
        % Ribs: use one orientation keypoint per full rib, matching the
        % hand-written Task3 macros.
        for rr = 0:n_rib-1
            X_r = rr * s_rib;
            kp_ori = 2001 + 2*rr;
            mac{end+1} = sprintf('K, %d, %g, %g, -1000', kp_ori, X_r, Y_bottom);
            mac{end+1} = sprintf('K, %d, %g, %g, -1000', kp_ori+1, X_r, Y_top);
        end
        mac{end+1} = '';

        % --- Mesh attributes ---
        % Longitudinals
        for ii = 0:n_long-1
            l1 = long_line_ranges(ii+1, 1);
            l2 = long_line_ranges(ii+1, 2);
            kp_ori = 1001 + 2*ii;
            sec = long_sec_map(ii+1);
            mac{end+1} = sprintf('LSEL, S, LINE, , %d, %d', l1, l2);
            mac{end+1} = sprintf('LATT, 1, , 1, , %d, , %d', kp_ori, sec);
            mac{end+1} = sprintf('LESIZE, ALL, , , %d', long_mesh_div);
        end
        % Ribs
        for rr = 0:n_rib-1
            l1 = rib_line_ranges(rr+1, 1);
            l2 = rib_line_ranges(rr+1, 2);
            kp_ori = 2001 + 2*rr;
            sec = rib_sec_map(rr+1);
            mac{end+1} = sprintf('LSEL, S, LINE, , %d, %d', l1, l2);
            mac{end+1} = sprintf('LATT, 1, , 1, , %d, , %d', kp_ori, sec);
            mac{end+1} = sprintf('LESIZE, ALL, , , %d', rib_mesh_div);
        end
        mac{end+1} = '';

        % Mesh
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = 'LMESH, ALL';
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = '';

        % Boundary conditions
        mac{end+1} = sprintf('NSEL, S, LOC, X, %g', X_left);
        mac{end+1} = 'D, ALL, UX, 0';
        mac{end+1} = 'D, ALL, UY, 0';
        mac{end+1} = 'D, ALL, UZ, 0';
        mac{end+1} = 'D, ALL, ROTX, 0';
        mac{end+1} = 'D, ALL, ROTY, 0';
        mac{end+1} = 'D, ALL, ROTZ, 0';
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = sprintf('NSEL, S, LOC, X, %g', X_right);
        mac{end+1} = 'D, ALL, UX, 0';
        mac{end+1} = 'D, ALL, UY, 0';
        mac{end+1} = 'D, ALL, UZ, 0';
        mac{end+1} = 'D, ALL, ROTX, 0';
        mac{end+1} = 'D, ALL, ROTY, 0';
        mac{end+1} = 'D, ALL, ROTZ, 0';
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = sprintf('NSEL, S, LOC, Y, %g', Y_bottom);
        mac{end+1} = 'D, ALL, UX, 0';
        mac{end+1} = 'D, ALL, UY, 0';
        mac{end+1} = 'D, ALL, UZ, 0';
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = sprintf('NSEL, S, LOC, Y, %g', Y_top);
        mac{end+1} = 'D, ALL, UX, 0';
        mac{end+1} = 'D, ALL, UY, 0';
        mac{end+1} = 'D, ALL, UZ, 0';
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = '';

        % Load (applied to ribs only)
        mac{end+1} = sprintf('ESEL, S, SEC, , %d, %d', rib_sec_ids(1), rib_sec_ids(end));
        mac{end+1} = sprintf('SFBEAM, ALL, 1, PRES, %g, %g', q1, q1);
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = '';

        % Solve
        mac{end+1} = 'FINISH';
        mac{end+1} = '/SOLU';
        mac{end+1} = 'ANTYPE, STATIC';
        mac{end+1} = 'OUTRES, ALL, LAST';
        mac{end+1} = 'OUTRES, MISC, LAST';
        mac{end+1} = 'SOLVE';
        mac{end+1} = 'FINISH';
        mac{end+1} = '';

        mac = [mac, obj.build_results_lines('results')];

        mac_str = strjoin(mac, newline);
    end

    function mac_str = generate_base_mesh_mac(obj, task_id, base_model_name)
        % Generate an APDL macro that builds geometry/mesh once and saves a
        % reusable database snapshot. Sections use the task midpoint design
        % only as placeholders for meshing; later evaluations overwrite the
        % same section IDs before solving.
        ctx = obj.get_task_context(task_id);
        [~, x0, ~] = obj.get_design_space(task_id);
        [long_groups, rib_groups] = obj.parse_grouped_sections(x0, ctx.task);

        mac = obj.build_model_preamble_lines(sprintf('/TITLE, %s_base', ctx.task.name));
        mac = [mac, ...
            obj.build_section_definition_lines(long_groups, rib_groups, ctx), ...
            obj.build_geometry_mesh_bc_load_lines(ctx), ...
            {sprintf('SAVE, %s, db', base_model_name), 'FINISH'}];

        mac_str = strjoin(mac, newline);
    end

    function mac_str = generate_mac_from_base(obj, x, task_id, base_model_name, results_target)
        % Generate an APDL macro that resumes a cached meshed database,
        % updates section definitions only, then solves and post-processes.
        ctx = obj.get_task_context(task_id);
        [long_groups, rib_groups] = obj.parse_grouped_sections(x, ctx.task);

        mac = {'FINISH', '/CLEAR, START', ...
               sprintf('/TITLE, %s_opt', ctx.task.name), ...
               '/NOPR', ...
               sprintf('RESUME, %s, db', base_model_name), ...
               '/PREP7', ''};
        mac = [mac, ...
            obj.build_section_definition_lines(long_groups, rib_groups, ctx), ...
            {'FINISH'}, ...
            obj.build_solve_lines(), ...
            obj.build_results_lines(results_target)];

        mac_str = strjoin(mac, newline);
    end

    function ctx = get_task_context(obj, task_id)
        t = obj.Tasks(task_id);

        [long_ext, rib_ext] = obj.get_task_end_extensions(task_id, t);

        L_span = (t.n_rib - 1) * t.s_rib;
        W_span = (t.n_long - 1) * t.s_long;
        [long_member_eq, rib_member_eq] = obj.get_member_eq_plate_widths(t);
        long_group_eq = obj.collapse_member_widths_to_groups( ...
            long_member_eq, obj.get_long_group_map(t), t.long_group_count);
        rib_group_eq = obj.collapse_member_widths_to_groups( ...
            rib_member_eq, obj.get_rib_group_map(t), t.rib_group_count);
        [long_sec_ids, long_sec_group_ids, long_sec_names] = obj.get_long_section_layout(t);
        [rib_sec_ids, rib_sec_group_ids, rib_sec_names] = obj.get_rib_section_layout(t);

        ctx = struct();
        ctx.task = t;
        ctx.task_id = task_id;
        ctx.t_eq_plate = t.t_plate;
        ctx.long_eq_plate_group = long_group_eq;
        ctx.rib_eq_plate_group = rib_group_eq;
        ctx.long_ext = long_ext;
        ctx.rib_ext = rib_ext;
        ctx.L_span = L_span;
        ctx.W_span = W_span;
        ctx.X_left = -long_ext;
        ctx.X_right = L_span + long_ext;
        ctx.Y_bottom = -rib_ext;
        ctx.Y_top = rib_ext + W_span;
        ctx.long_sec_map = obj.get_long_section_map(t);
        ctx.rib_sec_map = obj.get_rib_section_map(t);
        ctx.long_sec_ids = long_sec_ids;
        ctx.long_sec_group_ids = long_sec_group_ids;
        ctx.long_sec_names = long_sec_names;
        ctx.rib_sec_ids = rib_sec_ids;
        ctx.rib_sec_group_ids = rib_sec_group_ids;
        ctx.rib_sec_names = rib_sec_names;
        [ctx.long_mesh_div, ctx.rib_mesh_div] = obj.get_task_mesh_divisions(task_id);
    end

    function mac = build_model_preamble_lines(~, title_line)
        mac = {'FINISH', '/CLEAR, START', title_line, '/NOPR', '', ...
               '/PREP7', ...
               'ET, 1, BEAM188', ...
               'KEYOPT, 1, 4, 2', ...
               '', ...
               'MP, EX, 1, 2.06e5', ...
               'MP, PRXY, 1, 0.3', ...
               'MP, DENS, 1, 7.85e-9', ...
               ''};
    end

    function mac = build_task_metadata_comment_lines(~, task)
        mac = { ...
            '! Synced from Ship_Panel_Problem', ...
            sprintf('! s_long = %g', task.s_long), ...
            sprintf('! s_rib = %g', task.s_rib), ...
            sprintf('! q1 = %g', task.q1), ...
            sprintf('! t_plate = %g', task.t_plate), ...
            sprintf('! n_long = %d', task.n_long), ...
            sprintf('! n_rib = %d', task.n_rib), ...
            sprintf('! sigma_allow = %g', task.sigma_allow), ...
            sprintf('! bend_allow = %g', task.bend_allow), ...
            sprintf('! shear_allow = %g', task.shear_allow), ...
            ''};
    end

    function mac = build_section_definition_lines(~, long_groups, rib_groups, ctx)
        mac = {};

        for idx = 1:numel(ctx.long_sec_ids)
            group = ctx.long_sec_group_ids(idx);
            sec = long_groups(group, :);
            h_total = sec(4) + sec(1) + ctx.t_eq_plate;
            mac{end+1} = sprintf('SECTYPE, %d, BEAM, I, %s, 5', ...
                ctx.long_sec_ids(idx), ctx.long_sec_names{idx});
            mac{end+1} = sprintf('SECDATA, %g, %g, %g, %g, %g, %g', ...
                sec(3), ctx.long_eq_plate_group(group), h_total, sec(4), ctx.t_eq_plate, sec(2));
        end

        for idx = 1:numel(ctx.rib_sec_ids)
            group = ctx.rib_sec_group_ids(idx);
            sec = rib_groups(group, :);
            h_total = sec(4) + sec(1) + ctx.t_eq_plate;
            mac{end+1} = sprintf('SECTYPE, %d, BEAM, I, %s, 5', ...
                ctx.rib_sec_ids(idx), ctx.rib_sec_names{idx});
            mac{end+1} = sprintf('SECDATA, %g, %g, %g, %g, %g, %g', ...
                sec(3), ctx.rib_eq_plate_group(group), h_total, sec(4), ctx.t_eq_plate, sec(2));
        end

        mac{end+1} = '';
    end

    function mac = build_geometry_mesh_bc_load_lines(~, ctx)
        t = ctx.task;
        s_long = t.s_long;
        s_rib = t.s_rib;
        n_long = t.n_long;
        n_rib = t.n_rib;
        q1 = t.q1;

        mac = {};
        pprow = n_rib + 2;

        for ii = 0:n_long-1
            Y_i = ii * s_long;
            for jj = 0:pprow-1
                kp = ii * pprow + jj + 1;
                if jj == 0
                    X_j = ctx.X_left;
                elseif jj == pprow - 1
                    X_j = ctx.X_right;
                else
                    X_j = (jj - 1) * s_rib;
                end
                mac{end+1} = sprintf('K, %d, %g, %g, 0', kp, X_j, Y_i);
            end
        end

        kp_base_rib = n_long * pprow;
        for rr = 0:n_rib-1
            X_r = rr * s_rib;
            kp_bot = kp_base_rib + 2*rr + 1;
            kp_top_r = kp_base_rib + 2*rr + 2;
            mac{end+1} = sprintf('K, %d, %g, %g, 0', kp_bot, X_r, ctx.Y_bottom);
            mac{end+1} = sprintf('K, %d, %g, %g, 0', kp_top_r, X_r, ctx.Y_top);
        end
        mac{end+1} = '';

        line_num = 0;
        long_line_ranges = zeros(n_long, 2);
        for ii = 0:n_long-1
            first_line = line_num + 1;
            for jj = 0:pprow-2
                kp1 = ii * pprow + jj + 1;
                kp2 = ii * pprow + jj + 2;
                mac{end+1} = sprintf('L, %d, %d', kp1, kp2);
                line_num = line_num + 1;
            end
            long_line_ranges(ii+1, :) = [first_line, line_num];
        end

        rib_line_ranges = zeros(n_rib, 2);
        for rr = 0:n_rib-1
            first_line = line_num + 1;
            kp_bot = kp_base_rib + 2*rr + 1;
            kp_top_r = kp_base_rib + 2*rr + 2;
            kp_long_0 = 0 * pprow + (rr + 1) + 1;
            mac{end+1} = sprintf('L, %d, %d', kp_bot, kp_long_0);
            line_num = line_num + 1;

            for ii = 0:n_long-2
                kp1 = ii * pprow + (rr + 1) + 1;
                kp2 = (ii + 1) * pprow + (rr + 1) + 1;
                mac{end+1} = sprintf('L, %d, %d', kp1, kp2);
                line_num = line_num + 1;
            end

            kp_last = (n_long - 1) * pprow + (rr + 1) + 1;
            mac{end+1} = sprintf('L, %d, %d', kp_last, kp_top_r);
            line_num = line_num + 1;
            rib_line_ranges(rr+1, :) = [first_line, line_num];
        end
        mac{end+1} = '';

        for ii = 0:n_long-1
            Y_i = ii * s_long;
            kp_ori = 1001 + 2*ii;
            mac{end+1} = sprintf('K, %d, %g, %g, -1000', kp_ori, ctx.X_left, Y_i);
            mac{end+1} = sprintf('K, %d, %g, %g, -1000', kp_ori+1, ctx.X_right, Y_i);
        end
        for rr = 0:n_rib-1
            X_r = rr * s_rib;
            kp_ori = 2001 + 2*rr;
            mac{end+1} = sprintf('K, %d, %g, %g, -1000', kp_ori, X_r, ctx.Y_bottom);
            mac{end+1} = sprintf('K, %d, %g, %g, -1000', kp_ori+1, X_r, ctx.Y_top);
        end
        mac{end+1} = '';

        for ii = 0:n_long-1
            l1 = long_line_ranges(ii+1, 1);
            l2 = long_line_ranges(ii+1, 2);
            kp_ori = 1001 + 2*ii;
            sec = ctx.long_sec_map(ii+1);
            mac{end+1} = sprintf('LSEL, S, LINE, , %d, %d', l1, l2);
            mac{end+1} = sprintf('LATT, 1, , 1, , %d, , %d', kp_ori, sec);
            mac{end+1} = sprintf('LESIZE, ALL, , , %d', ctx.long_mesh_div);
        end
        for rr = 0:n_rib-1
            l1 = rib_line_ranges(rr+1, 1);
            l2 = rib_line_ranges(rr+1, 2);
            kp_ori = 2001 + 2*rr;
            sec = ctx.rib_sec_map(rr+1);
            mac{end+1} = sprintf('LSEL, S, LINE, , %d, %d', l1, l2);
            mac{end+1} = sprintf('LATT, 1, , 1, , %d, , %d', kp_ori, sec);
            mac{end+1} = sprintf('LESIZE, ALL, , , %d', ctx.rib_mesh_div);
        end
        mac{end+1} = '';

        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = 'LMESH, ALL';
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = '';

        mac{end+1} = sprintf('NSEL, S, LOC, X, %g', ctx.X_left);
        mac{end+1} = 'D, ALL, UX, 0';
        mac{end+1} = 'D, ALL, UY, 0';
        mac{end+1} = 'D, ALL, UZ, 0';
        mac{end+1} = 'D, ALL, ROTX, 0';
        mac{end+1} = 'D, ALL, ROTY, 0';
        mac{end+1} = 'D, ALL, ROTZ, 0';
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = sprintf('NSEL, S, LOC, X, %g', ctx.X_right);
        mac{end+1} = 'D, ALL, UX, 0';
        mac{end+1} = 'D, ALL, UY, 0';
        mac{end+1} = 'D, ALL, UZ, 0';
        mac{end+1} = 'D, ALL, ROTX, 0';
        mac{end+1} = 'D, ALL, ROTY, 0';
        mac{end+1} = 'D, ALL, ROTZ, 0';
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = sprintf('NSEL, S, LOC, Y, %g', ctx.Y_bottom);
        mac{end+1} = 'D, ALL, UX, 0';
        mac{end+1} = 'D, ALL, UY, 0';
        mac{end+1} = 'D, ALL, UZ, 0';
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = sprintf('NSEL, S, LOC, Y, %g', ctx.Y_top);
        mac{end+1} = 'D, ALL, UX, 0';
        mac{end+1} = 'D, ALL, UY, 0';
        mac{end+1} = 'D, ALL, UZ, 0';
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = '';

        mac{end+1} = sprintf('ESEL, S, SEC, , %d, %d', ctx.rib_sec_ids(1), ctx.rib_sec_ids(end));
        mac{end+1} = sprintf('SFBEAM, ALL, 1, PRES, %g, %g', q1, q1);
        mac{end+1} = 'ALLSEL, ALL';
        mac{end+1} = '';
    end

    function mac = build_solve_lines(~)
        mac = {'FINISH', ...
               '/SOLU', ...
               'ANTYPE, STATIC', ...
               'OUTRES, ALL, LAST', ...
               'OUTRES, MISC, LAST', ...
               'SOLVE', ...
               'FINISH', ...
               ''};
    end

    function mac = build_results_lines(~, results_target)
        if nargin < 2 || isempty(results_target)
            results_target = 'results';
        end

        mac = {'/POST1', ...
               'SET, LAST', ...
               '/ESHAPE, 1', ...
               '', ...
               '*GET, sx_max, SECR, ALL, S, X, MAX', ...
               '*GET, sx_min, SECR, ALL, S, X, MIN', ...
               '*GET, sxy_max, SECR, ALL, S, XY, MAX', ...
               '*GET, sxy_min, SECR, ALL, S, XY, MIN', ...
               '*GET, sxz_max, SECR, ALL, S, XZ, MAX', ...
               '*GET, sxz_min, SECR, ALL, S, XZ, MIN', ...
               '', ...
               'max_bend = ABS(sx_max)', ...
               '*IF,ABS(sx_min),GT,max_bend,THEN', ...
               '	max_bend = ABS(sx_min)', ...
               '*ENDIF', ...
               '', ...
               'max_shear = ABS(sxy_max)', ...
               '*IF,ABS(sxy_min),GT,max_shear,THEN', ...
               '	max_shear = ABS(sxy_min)', ...
               '*ENDIF', ...
               '*IF,ABS(sxz_max),GT,max_shear,THEN', ...
               '	max_shear = ABS(sxz_max)', ...
               '*ENDIF', ...
               '*IF,ABS(sxz_min),GT,max_shear,THEN', ...
               '	max_shear = ABS(sxz_min)', ...
               '*ENDIF', ...
               '', ...
               '*STATUS,max_bend', ...
               '*STATUS,max_shear', ...
               '', ...
               sprintf('*CFOPEN, %s, txt', results_target), ...
               '*VWRITE, sx_max', ...
               '(F20.6)', ...
               '*VWRITE, sx_min', ...
               '(F20.6)', ...
               '*VWRITE, sxy_max', ...
               '(F20.6)', ...
               '*VWRITE, sxy_min', ...
               '(F20.6)', ...
               '*VWRITE, sxz_max', ...
               '(F20.6)', ...
               '*VWRITE, sxz_min', ...
               '(F20.6)', ...
               '', ...
               '! Total structural mass from FEA model', ...
               'ALLSEL, ALL', ...
               '*GET, total_mass, ELEM, 0, MTOT, Z', ...
               '*VWRITE, total_mass', ...
               '(E20.10)', ...
               '*CFCLOS', ...
               'FINISH'};
    end

    function mass = compute_mass(obj, x, task_id)
        % Compute structural mass (kg) from design variables.
        % Supports legacy 12-variable layouts and grouped 36-variable layouts.
        t = obj.Tasks(task_id);
        rho = 7.85e-9; % t/mm^3

        s_long = t.s_long; s_rib = t.s_rib;
        n_long = t.n_long; n_rib = t.n_rib;
        t_top = t.t_plate;
        [long_member_eq, rib_member_eq] = obj.get_member_eq_plate_widths(t);
        [long_groups, rib_groups] = obj.parse_grouped_sections(x, t);
        long_map = obj.get_long_group_map(t);
        rib_map = obj.get_rib_group_map(t);

        [long_ext, rib_ext] = obj.get_task_end_extensions(task_id, t);
        L_long = (n_rib - 1) * s_rib + 2 * long_ext;
        L_rib = (n_long - 1) * s_long + 2 * rib_ext;

        vol = 0;
        for idx = 1:numel(long_map)
            sec = long_groups(long_map(idx), :);
            area = sec(1) * sec(2) + sec(3) * sec(4) + long_member_eq(idx) * t_top;
            vol = vol + area * L_long;
        end
        for idx = 1:numel(rib_map)
            sec = rib_groups(rib_map(idx), :);
            area = sec(1) * sec(2) + sec(3) * sec(4) + rib_member_eq(idx) * t_top;
            vol = vol + area * L_rib;
        end

        mass = rho * vol * 1e3; % convert from tonnes to kg
    end
end
end
