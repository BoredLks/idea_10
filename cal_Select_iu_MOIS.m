function [iu_indices, iu_flags] = cal_Select_iu_MOIS(h, user_per_community, total_users, iu_count_per_community, iu_coverage, T_small, B, P_iu, N0, K, epsilon, slowfading_dB, per_user_positions, sg_edge_weights)
%% MOIS多对一匹配选择IU (公式30-33, 36-38)
%  ★ 新增: 空间分散后处理 — 确保选出的IU尽量覆盖整个社区

% --- MOIS参数 ---
C_num = 3;
Q_cp_base      = floor(iu_count_per_community / C_num);
Q_cp_remainder = mod(iu_count_per_community, C_num);
Q_cp = ones(C_num, 1) * Q_cp_base;
for cp_idx = 1:Q_cp_remainder
    Q_cp(cp_idx) = Q_cp(cp_idx) + 1;
end

mu_mois      = 0.4;
nu_mois      = 0.4;
upsilon_mois = 0.2;
zeta_coeff   = 1.0;
S_cost_val   = 0.5;
rent_base    = [1.5; 2.0; 1.8];
battery_level = 0.5 + 0.5 * rand(total_users, 1);

%% 6.1 计算预备物理评分 (两趟法)
prelim_d2d_score = zeros(total_users, total_users);
R_max_pre = 0;

for m = 1:h
    com_start = (m-1) * user_per_community + 1;
    com_end   = m * user_per_community;
    for i = com_start:com_end
        for j = i+1:com_end
            total_rate = 0; valid_slots = 0;
            for t = 1:T_small
                dist_t = norm(per_user_positions(i,:,t) - per_user_positions(j,:,t));
                if dist_t > 0 && dist_t <= iu_coverage
                    slowfading_sd  = slowfading_dB / (10 * log10(exp(1)));
                    slowfading_avg = -slowfading_sd^2 / 2;
                    vartheta = lognrnd(slowfading_avg, slowfading_sd);
                    re = (randn() + 1i * randn()) / sqrt(2);
                    xi = abs(re)^2;
                    channel_gain = K * vartheta * xi * dist_t^(-epsilon);
                    R_inst = B * log2(1 + (P_iu * channel_gain) / N0);
                    if R_inst > R_max_pre, R_max_pre = R_inst; end
                    total_rate = total_rate + R_inst;
                    valid_slots = valid_slots + 1;
                end
            end
            if valid_slots > 0
                avg_rate = total_rate / valid_slots;
                prelim_d2d_score(i,j) = avg_rate;
                prelim_d2d_score(j,i) = avg_rate;
            end
        end
    end
end

if R_max_pre > 0
    for i = 1:total_users, prelim_d2d_score(i,i) = R_max_pre; end
    prelim_d2d_norm = prelim_d2d_score / R_max_pre;
else
    prelim_d2d_norm = zeros(total_users);
end

%% 6.2 逐社区执行MOIS匹配
iu_indices = zeros(h, iu_count_per_community);
iu_flags   = zeros(total_users, 1);

% 使用时间平均位置用于空间分散计算
avg_pos = mean(per_user_positions, 3);

for m = 1:h
    com_start = (m-1) * user_per_community + 1;
    com_end   = m * user_per_community;
    com_users = com_start:com_end;
    N_com     = user_per_community;

    % === 公式(36): 重要性度量 ===
    W_importance = zeros(N_com, N_com);
    for ii = 1:N_com
        gi = com_users(ii);
        for jj = 1:N_com
            if ii ~= jj
                gj = com_users(jj);
                e_pg_ij = prelim_d2d_norm(gi, gj);
                e_sg_ij = sg_edge_weights(gi, gj);
                c_ij    = min(battery_level(gi), battery_level(gj));
                W_importance(ii, jj) = mu_mois * e_pg_ij + nu_mois * e_sg_ij + upsilon_mois * c_ij;
            end
        end
    end

    sum_w = sum(W_importance, 2);
    max_sw = max(sum_w); if max_sw == 0, max_sw = 1; end

    d2d_check = prelim_d2d_score(com_start:com_end, com_start:com_end);
    N_neighbors = cell(N_com, 1);
    for ii = 1:N_com, N_neighbors{ii} = find(d2d_check(ii, :) > 0); end

    % === CP效用 + MOIS匹配 ===
    S_rent_m = zeros(C_num, N_com);
    for cp = 1:C_num
        for ii = 1:N_com
            S_rent_m(cp, ii) = rent_base(cp) * (0.5 + sum_w(ii)/max_sw) * (0.9 + 0.2*rand());
        end
    end
    mn_r = min(S_rent_m(:)); mx_r = max(S_rent_m(:));
    if mx_r > mn_r, S_rent_m = (S_rent_m - mn_r)/(mx_r - mn_r); else, S_rent_m = ones(C_num, N_com); end

    S_CP_m = zeros(C_num, N_com);
    for cp = 1:C_num
        for ii = 1:N_com
            S_CP_m(cp, ii) = zeta_coeff * sum(W_importance(ii, N_neighbors{ii})) - S_rent_m(cp, ii);
        end
    end

    PR_CP_m = zeros(C_num, N_com);
    for cp = 1:C_num, [~, si] = sort(S_CP_m(cp,:), 'descend'); PR_CP_m(cp,:) = si; end

    S_UE_m = zeros(N_com, C_num);
    for ii = 1:N_com
        for cp = 1:C_num, S_UE_m(ii,cp) = S_rent_m(cp,ii) - S_cost_val; end
    end

    % MOIS匹配主循环
    Y_m = zeros(C_num, N_com); cp_count_m = zeros(C_num,1);
    ue_owner_m = zeros(N_com,1);
    cp_reject_m = cell(C_num,1); for cp=1:C_num, cp_reject_m{cp}=[]; end
    cp_next_rank = ones(C_num,1);

    for iter = 1:(N_com*C_num+50)
        if all(cp_count_m >= Q_cp), break; end
        proposals = cell(N_com,1); any_p = false;
        for cp = 1:C_num
            if cp_count_m(cp) >= Q_cp(cp), continue; end
            while cp_next_rank(cp) <= N_com
                ue_l = PR_CP_m(cp, cp_next_rank(cp)); cp_next_rank(cp) = cp_next_rank(cp)+1;
                if ismember(ue_l, cp_reject_m{cp}), continue; end
                proposals{ue_l}(end+1) = cp; any_p = true; break;
            end
        end
        if ~any_p, break; end
        for ue_l = 1:N_com
            inc = proposals{ue_l}; if isempty(inc), continue; end
            cur = ue_owner_m(ue_l);
            if cur>0, cands=[inc,cur]; else, cands=inc; end
            bcp=-1; bv=-inf;
            for kk=1:length(cands), if S_UE_m(ue_l,cands(kk))>bv, bv=S_UE_m(ue_l,cands(kk)); bcp=cands(kk); end, end
            if cur>0 && bcp~=cur
                Y_m(cur,ue_l)=0; cp_count_m(cur)=cp_count_m(cur)-1; cp_reject_m{cur}(end+1)=ue_l;
            end
            if cur==0||bcp~=cur
                ue_owner_m(ue_l)=bcp; Y_m(bcp,ue_l)=1; cp_count_m(bcp)=cp_count_m(bcp)+1;
            end
            for kk=1:length(inc), if inc(kk)~=bcp, cp_reject_m{inc(kk)}(end+1)=ue_l; end, end
        end
    end

    % 提取MOIS候选
    mois_selected = find(sum(Y_m,1) > 0);

    % ================================================================
    % ★★★ 空间分散后处理: 从MOIS候选 + 全部用户中贪心选择IU ★★★
    % 目标: 选出的IU覆盖尽量多的社区用户
    % ================================================================
    
    % 计算每个用户作为IU时能覆盖的用户数
    cover_count = zeros(N_com, 1);
    for ii = 1:N_com
        gi = com_users(ii);
        cnt = 0;
        for jj = 1:N_com
            gj = com_users(jj);
            if ii ~= jj
                dist_ij = norm(avg_pos(gi,:) - avg_pos(gj,:));
                if dist_ij <= iu_coverage
                    cnt = cnt + 1;
                end
            end
        end
        cover_count(ii) = cnt;
    end
    
    % MOIS候选的重要性分数 (用于优先选择)
    importance_score = sum_w;
    % MOIS候选获得额外加分
    mois_bonus = zeros(N_com, 1);
    mois_bonus(mois_selected) = max(importance_score) * 0.3;
    
    % 综合分数 = 重要性 + MOIS加分 + 覆盖能力
    max_cover = max(cover_count); if max_cover == 0, max_cover = 1; end
    combined_score = importance_score / max_sw + ...
                     mois_bonus / max(max(mois_bonus),1) + ...
                     cover_count / max_cover;
    
    % 贪心选择: 每轮选综合分数最高的, 然后降低其覆盖区内其他候选的分数
    selected_local = [];
    covered_users = false(N_com, 1);
    remaining = 1:N_com;
    
    for round = 1:iu_count_per_community
        if isempty(remaining), break; end
        
        % 计算新增覆盖价值
        selection_score = zeros(length(remaining), 1);
        for idx = 1:length(remaining)
            ii = remaining(idx);
            gi = com_users(ii);
            new_covered = 0;
            for jj = 1:N_com
                if ~covered_users(jj)
                    gj = com_users(jj);
                    if norm(avg_pos(gi,:) - avg_pos(gj,:)) <= iu_coverage
                        new_covered = new_covered + 1;
                    end
                end
            end
            % 分数 = 新增覆盖用户数 × 基础分
            selection_score(idx) = new_covered * (1 + combined_score(ii));
        end
        
        [~, best_idx] = max(selection_score);
        best_local = remaining(best_idx);
        selected_local(end+1) = best_local;
        
        % 更新已覆盖用户
        gi = com_users(best_local);
        for jj = 1:N_com
            gj = com_users(jj);
            if norm(avg_pos(gi,:) - avg_pos(gj,:)) <= iu_coverage
                covered_users(jj) = true;
            end
        end
        
        remaining(best_idx) = [];
    end

    % 转为全局索引
    selected_global = com_users(selected_local);
    iu_indices(m, :) = selected_global;
    iu_flags(selected_global) = 1;
    
    coverage_pct = sum(covered_users) / N_com * 100;
    % fprintf('  社区%d: IU覆盖率=%.0f%% (%d/%d用户)\n', m, coverage_pct, sum(covered_users), N_com);
end

end
