clear; clc;
cd(fileparts(mfilename('fullpath')));
repo_root = fileparts(pwd);
addpath(genpath(pwd));
addpath(genpath(fullfile(repo_root, 'APDL')));

ship_prob = Ship_Panel_Problem();

assert(ship_prob.T >= 9, 'Expected Ship_Panel_Problem to expose task8 and task9.');

for task_id = [8 9]
    [lb, x0, ub] = ship_prob.get_design_space(task_id);
    assert(numel(lb) == 36, 'Task%d lb should have 36 vars.', task_id);
    assert(numel(ub) == 36, 'Task%d ub should have 36 vars.', task_id);
    assert(numel(x0) == 36, 'Task%d x0 should have 36 vars.', task_id);
    if task_id == 8
        expected_long_lb = [350, 6, 450, 12];
        expected_long_ub = [650, 12, 600, 22];
        expected_rib_lb = [200, 6, 350, 6];
        expected_rib_ub = [350, 12, 500, 12];
    else
        expected_long_lb = [250, 5, 150, 10];
        expected_long_ub = [550, 11, 300, 20];
        expected_rib_lb = [150, 5, 150, 5];
        expected_rib_ub = [300, 11, 300, 11];
    end
    assert(isequal(lb(1:16), repmat(expected_long_lb, 1, 4)), ...
        'Task%d longitudinal lower bounds mismatch.', task_id);
    assert(isequal(ub(1:16), repmat(expected_long_ub, 1, 4)), ...
        'Task%d longitudinal upper bounds mismatch.', task_id);
    assert(isequal(lb(17:36), repmat(expected_rib_lb, 1, 5)), ...
        'Task%d rib lower bounds mismatch.', task_id);
    assert(isequal(ub(17:36), repmat(expected_rib_ub, 1, 5)), ...
        'Task%d rib upper bounds mismatch.', task_id);

    task = ship_prob.Tasks(task_id);
    con_names = get_ship_constraint_names(task_id);
    x_probe = 1:36;
    [long_groups, rib_groups] = ship_prob.parse_grouped_sections(x_probe, task);
    assert(isequal(long_groups, reshape(1:16, 4, 4).'), ...
        'Task%d longitudinal variable order mismatch.', task_id);
    assert(isequal(rib_groups, reshape(17:36, 4, 5).'), ...
        'Task%d rib variable order mismatch.', task_id);
    assert(isequal(ship_prob.get_long_group_map(task), [4, 3, 2, 1, 2, 3, 4]), ...
        'Task%d longitudinal symmetric map mismatch.', task_id);
    assert(isequal(ship_prob.get_rib_group_map(task), [5, 4, 3, 2, 1, 2, 3, 4, 5]), ...
        'Task%d rib group map should collapse the 9 ribs into 5 symmetric groups.', task_id);
    assert(isequal(ship_prob.get_long_section_map(task), [4, 3, 2, 1, 2, 3, 4]), ...
        'Task%d longitudinal section map mismatch.', task_id);
    assert(isequal(ship_prob.get_rib_section_map(task), [9, 8, 7, 6, 5, 6, 7, 8, 9]), ...
        'Task%d rib section map should point the 9 ribs to 5 symmetric sections.', task_id);
    assert(numel(con_names) == 20, 'Task%d should expose 20 constraints.', task_id);

    if task_id == 8
        expected_long = [2250, repmat(16000 / 6, 1, 5), 2250];
        expected_rib = 1600 * ones(1, 9);
    else
        expected_long = [2250, 3000, 3000, 3000, 3000, 3000, 2250];
        expected_rib = 2000 * ones(1, 9);
    end
    assert(isequal(task.b_top_long, expected_long), ...
        'Task%d longitudinal equivalent plate widths mismatch.', task_id);
    assert(isequal(task.b_top_rib, expected_rib), ...
        'Task%d rib equivalent plate widths mismatch.', task_id);

    mass = ship_prob.compute_mass(x0, task_id);
    assert(isfinite(mass) && mass > 0, 'Task%d mass should be positive.', task_id);

    mac = ship_prob.generate_mac(x0, task_id);
    assert(contains(mac, 'LONG_4'), 'Task%d macro should define the 4th longitudinal group.', task_id);
    assert(contains(mac, 'SECTYPE, 5, BEAM, I, RIB_1, 5'), ...
        'Task%d macro should define the center rib group.', task_id);
    assert(contains(mac, 'SECTYPE, 9, BEAM, I, RIB_5, 5'), ...
        'Task%d macro should define the outer rib group.', task_id);
    assert(numel(strfind(mac, 'SECTYPE,')) == 9, 'Task%d should define 9 grouped sections.', task_id);
    assert(numel(strfind(mac, 'LONG_')) >= 4, 'Task%d should define 4 longitudinal groups.', task_id);
    assert(numel(strfind(mac, 'RIB_')) >= 5, ...
        'Task%d should define all 5 rib groups.', task_id);
    assert(numel(strfind(mac, 'LESIZE, ALL, , , 20')) == 16, ...
        'Task%d should create 7 longitudinal rows and 9 rib rows with mesh size 20.', task_id);
    assert(~contains(mac, 'LESIZE, ALL, , , 5'), ...
        'Task%d should no longer keep rib mesh size 5.', task_id);
    assert(contains(mac, 'ESEL, S, SEC, , 5, 9'), ...
        'Task%d should load all 5 rib sections.', task_id);

    long_sec_map = ship_prob.get_long_section_map(task);
    rib_sec_map = ship_prob.get_rib_section_map(task);
    for ii = 0:6
        kp_ori = 1001 + 2 * ii;
        sec = long_sec_map(ii + 1);
        assert(contains(mac, sprintf('LATT, 1, , 1, , %d, , %d', kp_ori, sec)), ...
            'Task%d longitudinal LATT map mismatch at row %d.', task_id, ii + 1);
    end
    for rr = 0:8
        kp_ori = 2001 + 2 * rr;
        sec = rib_sec_map(rr + 1);
        assert(contains(mac, sprintf('LATT, 1, , 1, , %d, , %d', kp_ori, sec)), ...
            'Task%d rib LATT map mismatch at row %d.', task_id, rr + 1);
    end
end

prob = Ship_Panel_MTSO();
prob.ActiveTasks = [8 9];
prob.setTasks();
assert(all(prob.D == [36 36]), 'Ship_Panel_MTSO should expose [36 36] dimensions for tasks 8/9.');

for k = 1:prob.T
    x = repmat(prob.Lb{k}, 2, 1);
    [obj, con] = prob.Fnc{k}(x);
    assert(all(size(obj) == [2, 1]), 'Task%d objective shape mismatch.', prob.ActiveTasks(k));
    assert(all(size(con) == [2, 20]), 'Task%d should return 2x20 constraints.', prob.ActiveTasks(k));
end

fprintf('task8/task9 definition checks passed.\n');
