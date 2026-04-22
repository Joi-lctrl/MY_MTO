clear; clc;
cd(fileparts(mfilename('fullpath')));
repo_root = fileparts(pwd);
addpath(genpath(pwd));
addpath(genpath(fullfile(repo_root, 'APDL')));

ship_prob = Ship_Panel_Problem();

expected_dim = containers.Map({8, 9}, {36, 32});
expected_rib_groups = containers.Map({8, 9}, {5, 4});
expected_constraints = containers.Map({8, 9}, {20, 18});
expected_rib_group_map = containers.Map( ...
    {8, 9}, ...
    {[5, 4, 3, 2, 1, 2, 3, 4, 5], [4, 4, 3, 2, 1, 2, 3, 4, 4]});
expected_rib_section_map = containers.Map( ...
    {8, 9}, ...
    {[9, 8, 7, 6, 5, 6, 7, 8, 9], [8, 8, 7, 6, 5, 6, 7, 8, 8]});
expected_rib_sec_range = containers.Map({8, 9}, {'5, 9', '5, 8'});

for task_id = [8 9]
    [lb, x0, ub] = ship_prob.get_design_space(task_id);
    task = ship_prob.Tasks(task_id);
    dim = expected_dim(task_id);
    rib_group_count = expected_rib_groups(task_id);

    assert(numel(lb) == dim, 'Task%d lb should have %d vars.', task_id, dim);
    assert(numel(ub) == dim, 'Task%d ub should have %d vars.', task_id, dim);
    assert(numel(x0) == dim, 'Task%d x0 should have %d vars.', task_id, dim);
    assert(task.rib_group_count == rib_group_count, ...
        'Task%d should expose %d rib variable groups.', task_id, rib_group_count);

    if task_id == 8
        expected_long_lb = [350, 7, 180, 12];
        expected_long_ub = [650, 13, 300, 22];
    else
        expected_long_lb = [350, 7, 180, 12];
        expected_long_ub = [700, 14, 300, 22];
    end
    expected_rib_lb = [150, 4, 180, 12];
    expected_rib_ub = [300, 10, 300, 22];
    assert(isequal(lb(1:16), repmat(expected_long_lb, 1, 4)), ...
        'Task%d longitudinal lower bounds mismatch.', task_id);
    assert(isequal(ub(1:16), repmat(expected_long_ub, 1, 4)), ...
        'Task%d longitudinal upper bounds mismatch.', task_id);
    assert(isequal(lb(17:end), repmat(expected_rib_lb, 1, rib_group_count)), ...
        'Task%d rib lower bounds mismatch.', task_id);
    assert(isequal(ub(17:end), repmat(expected_rib_ub, 1, rib_group_count)), ...
        'Task%d rib upper bounds mismatch.', task_id);

    x_probe = 1:dim;
    [long_groups, rib_groups] = ship_prob.parse_grouped_sections(x_probe, task);
    assert(isequal(long_groups, reshape(1:16, 4, 4).'), ...
        'Task%d longitudinal variable order mismatch.', task_id);
    assert(isequal(rib_groups, reshape(17:dim, 4, rib_group_count).'), ...
        'Task%d rib variable order mismatch.', task_id);
    assert(isequal(ship_prob.get_long_group_map(task), [4, 3, 2, 1, 2, 3, 4]), ...
        'Task%d longitudinal symmetric map mismatch.', task_id);
    assert(isequal(ship_prob.get_rib_group_map(task), expected_rib_group_map(task_id)), ...
        'Task%d rib group map mismatch.', task_id);
    assert(isequal(ship_prob.get_long_section_map(task), [4, 3, 2, 1, 2, 3, 4]), ...
        'Task%d longitudinal section map mismatch.', task_id);
    assert(isequal(ship_prob.get_rib_section_map(task), expected_rib_section_map(task_id)), ...
        'Task%d rib section map mismatch.', task_id);
    assert(numel(get_ship_constraint_names(task_id)) == expected_constraints(task_id), ...
        'Task%d constraint count mismatch.', task_id);

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
    assert(numel(strfind(mac, 'SECTYPE,')) == 4 + rib_group_count, ...
        'Task%d grouped section count mismatch.', task_id);
    assert(numel(strfind(mac, 'LESIZE, ALL, , , 20')) == 7, ...
        'Task%d should create 7 longitudinal rows with mesh size 20.', task_id);
    assert(numel(strfind(mac, 'LESIZE, ALL, , , 5')) == 9, ...
        'Task%d should create 9 rib rows with mesh size 5.', task_id);
    assert(contains(mac, ['ESEL, S, SEC, , ', expected_rib_sec_range(task_id)]), ...
        'Task%d should select only rib sections for SFBEAM loading.', task_id);
    assert(contains(mac, sprintf('SFBEAM, ALL, 1, PRES, %g, %g', task.q1, task.q1)), ...
        'Task%d should use the SFBEAM face-1 rib load.', task_id);
    assert(~contains(mac, 'F, ALL, FZ'), ...
        'Task%d should not keep the temporary global FZ load block.', task_id);
    assert(~contains(mac, 'FCUM, ADD'), ...
        'Task%d should not keep the temporary FZ accumulation block.', task_id);
end

prob = Ship_Panel_MTSO();
prob.ActiveTasks = [8 9];
prob.setTasks();
assert(all(prob.D == [36 32]), 'Ship_Panel_MTSO should expose [36 32] dimensions for tasks 8/9.');

fprintf('task8/task9 definition checks passed.\n');
