%% inspect_results.m - 查看 MTOData.mat 和 MTOData_Temp.mat 的内容

% 另存 MTOData.mat 为 task34.mat
if isfile('MTOData.mat')
    copyfile('MTOData.mat', 'task34.mat');
    fprintf('已将 MTOData.mat 另存为 task34.mat\n');
end

for fname = {"MTOData.mat", "MTOData_Temp.mat"}
    fprintf('\n========== %s ==========\n', fname{1});
    if ~isfile(fname{1})
        fprintf('  文件不存在\n');
        continue;
    end
    d = load(fname{1});
    fnames = fieldnames(d);
    fprintf('  顶层变量: %s\n', strjoin(fnames, ', '));

    if isfield(d, 'MTOData')
        M = d.MTOData;
        sub = fieldnames(M);
        fprintf('  MTOData 字段: %s\n', strjoin(sub, ', '));

        if isfield(M, 'Problems')
            fprintf('  Problems: %s\n', strjoin(M.Problems, ', '));
        end
        if isfield(M, 'Algorithms')
            fprintf('  Algorithms: %s\n', strjoin(M.Algorithms, ', '));
        end
        if isfield(M, 'Reps')
            fprintf('  Reps: %d\n', M.Reps);
        end
        if isfield(M, 'T')
            fprintf('  T (任务数): %d\n', M.T);
        end
        if isfield(M, 'maxFE')
            fprintf('  maxFE: %d\n', M.maxFE);
        end
        if isfield(M, 'N')
            fprintf('  N (种群): %d\n', M.N);
        end

        % 打印每个算法每个rep每个task的最优结果
        if isfield(M, 'Results')
            R = M.Results;
            [nP, nA, nR] = size(R);
            fprintf('  Results size: [%d prob x %d algo x %d rep]\n', nP, nA, nR);
            for p = 1:nP
                for a = 1:nA
                    for r = 1:nR
                        res = R(p, a, r);
                        if isfield(res, 'Obj') && ~isempty(res.Obj)
                            nT = numel(res.Obj);
                            for t = 1:nT
                                obj_hist = res.Obj{t};
                                cv_hist = res.CV{t};
                                if ~isempty(obj_hist)
                                    best_obj = obj_hist(end);
                                    best_cv = cv_hist(end);
                                    fprintf('    Prob%d Algo%d Rep%d Task%d: BestObj=%.4f CV=%.4f (共%d代)\n', ...
                                        p, a, r, t, best_obj, best_cv, numel(obj_hist));
                                end
                            end
                        end
                    end
                end
            end
        end

        % 打印最终决策变量
        if isfield(M, 'Results')
            R = M.Results;
            [nP, nA, nR] = size(R);
            for p = 1:nP
                for a = 1:nA
                    for r = 1:nR
                        res = R(p, a, r);
                        if isfield(res, 'Dec') && ~isempty(res.Dec)
                            nT = numel(res.Dec);
                            for t = 1:nT
                                dec = res.Dec{t};
                                if ~isempty(dec)
                                    fprintf('    Prob%d Algo%d Rep%d Task%d Dec=[%s]\n', ...
                                        p, a, r, t, num2str(dec(end,:), '%.2f '));
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
