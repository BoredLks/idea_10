function cache_decision = cal_cache_decision_3(h, user_per_community, total_users, F, iu_count_per_community, nf, v_chi_star, D_eg, D_iu, iu_indices, user_file_req_prob)

%% 算法三：混合缓存 HC
cache_decision = zeros(total_users + h, F);% 初始化缓存决策

% 计算SBS能缓存的文件数量
files_per_sbs = D_eg/(nf * v_chi_star);
files_per_iu = D_iu/(nf * v_chi_star);

% SBS缓存最流行的文件
for m = 1:h
    sbs_cached_files = zeros(1,min(files_per_sbs, F));
    sbs_idx = total_users + m;
    global_popularity = mean(user_file_req_prob((m-1) * user_per_community + 1 : m * user_per_community, :), 1);
    [~, popularity_ranking] = sort(global_popularity, 'descend');

    for file_rank = 1:min(files_per_sbs, F)
        f = popularity_ranking(file_rank);
        cache_decision(sbs_idx, f) = 1;
        sbs_cached_files(file_rank) = f;
    end

    % IU缓存除SBS已缓存外的其他流行文件
    remaining_files = popularity_ranking(~ismember(popularity_ranking, sbs_cached_files));

    for i = 1:iu_count_per_community
        iu_idx = iu_indices(m, i);

        for file_rank = 1:min(files_per_iu, length(remaining_files))
            f = remaining_files(file_rank);
            cache_decision(iu_idx, f) = 1;
        end
    end
end





end