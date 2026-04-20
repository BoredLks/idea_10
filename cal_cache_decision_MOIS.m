function cache_decision = cal_cache_decision_MOIS(h, total_users, F, iu_count_per_community, nf, v_chi_star, D_eg, D_iu, iu_indices, cache_preference)

%% 算法零：本文所提出的算法
% 初始化缓存决策
cache_decision = zeros(total_users + h, F);

% 处理SBS的缓存决策（确保不重复）
sbs_cache_space = zeros(h, 1); % 跟踪每个SBS已使用的缓存空间
cached_files_by_sbs = false(1, F); % 跟踪已被任何SBS缓存的文件
% 处理IU的缓存决策
iu_cache_space = zeros(total_users, 1); % 跟踪每个IU已使用的缓存空间

for m = 1:h
    sbs_idx = total_users + m;

    % 获取此SBS的缓存偏好
    sbs_preferences = cache_preference(sbs_idx, :);
    % 移除已被其他SBS缓存的文件
    sbs_preferences(cached_files_by_sbs) = -inf;
    % 根据偏好排序文件
    [sorted_pref, file_indices] = sort(sbs_preferences, 'descend');

    % 按偏好顺序尝试缓存文件
    for idx = 1:length(file_indices)
        f = file_indices(idx);
        if sorted_pref(idx) > 0 % 只考虑有正偏好的文件
            % 检查缓存空间是否足够
            if sbs_cache_space(m) + nf * v_chi_star <= D_eg
                cache_decision(sbs_idx, f) = 1;
                sbs_cache_space(m) = sbs_cache_space(m) + nf * v_chi_star;
                cached_files_by_sbs(f) = true; % 标记文件已被SBS缓存
            else
                break; % 空间不足，停止缓存
            end
        else
            break; % 无正偏好，停止缓存
        end
    end
end

for m = 1:h
    for i = 1:iu_count_per_community
        iu_idx = iu_indices(m, i);

        % 获取此IU的缓存偏好
        iu_preferences = cache_preference(iu_idx, :);
        % 根据偏好排序文件
        [sorted_pref, file_indices] = sort(iu_preferences, 'descend');

        % 按偏好顺序尝试缓存文件
        for idx = 1:length(file_indices)
            f = file_indices(idx);
            if sorted_pref(idx) > 0 % 只考虑有正偏好的文件
                % 检查缓存空间是否足够
                if iu_cache_space(iu_idx) + nf * v_chi_star <= D_iu
                    cache_decision(iu_idx, f) = 1;
                    iu_cache_space(iu_idx) = iu_cache_space(iu_idx) + nf * v_chi_star;
                else
                    break; % 空间不足，停止缓存
                end
            else
                break; % 无正偏好，停止缓存
            end
        end
    end
end

end