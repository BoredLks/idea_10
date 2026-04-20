function cache_decision = cal_cache_decision_2(h, total_users, F, iu_count_per_community, nf, v_chi_star, D_eg, D_iu, iu_indices)

%% 算法二：随机缓存 RA
cache_decision = zeros(total_users + h, F);% 初始化缓存决策

% SBS统一缓存随机文件
for m = 1:h
    sbs_idx = total_users + m;
    idx_RA_eg = randsample(1:F, D_eg/(nf * v_chi_star), false); 
    cache_decision(sbs_idx, idx_RA_eg) = 1;
end

% IU统一缓存随机文件
for m = 1:h
    for i = 1:iu_count_per_community
        iu_idx = iu_indices(m, i);
        idx_RA_iu = randsample(1:F, D_iu/(nf * v_chi_star), false); 
        cache_decision(iu_idx, idx_RA_iu) = 1;
    end
end
end