function names = get_ship_constraint_names(task_id)
% Return ordered constraint names for a ship panel task.

ship_prob = Ship_Panel_Problem();
task = ship_prob.Tasks(task_id);

names = {'g_bend', 'g_shear'};

has_group_slenderness = false;
if isfield(task, 'enable_group_slenderness')
    has_group_slenderness = logical(task.enable_group_slenderness);
end

has_rib_web_below_long_web = false;
if isfield(task, 'enforce_rib_web_below_long_web')
    has_rib_web_below_long_web = logical(task.enforce_rib_web_below_long_web);
end

if has_group_slenderness
    for g = 1:task.long_group_count
        names{end + 1} = sprintf('g_web_L%d', g); %#ok<AGROW>
        names{end + 1} = sprintf('g_flange_L%d', g); %#ok<AGROW>
    end
    for g = 1:task.rib_group_count
        names{end + 1} = sprintf('g_web_R%d', g); %#ok<AGROW>
        names{end + 1} = sprintf('g_flange_R%d', g); %#ok<AGROW>
    end
    if has_rib_web_below_long_web
        names{end + 1} = 'g_rib_web_le_long_web'; %#ok<AGROW>
    end
else
    names{end + 1} = 'g_aux1';
    names{end + 1} = 'g_aux2';
end
end
