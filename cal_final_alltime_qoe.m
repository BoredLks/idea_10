function final_alltime_qoe = cal_final_alltime_qoe(iu_count_per_community, nf, chi, Delta_t, alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, eta, epsilon_conv, max_iterations, iu_flags, user_file_req_prob, cache_decision, community_users, requested_videos, download_rates, task_assignment, initial_wait_times, r_decision, r_previous, lambda, mu_sbs, mu_iu, buffer_state)
%% =====================================================================
%%  新 QoE 模型  —— 公式 (29)
%%  QoE = ω1·ln(z) − ω2·(z − z_prev)² − ω3·WT − ω4·z·Δt/(BF + ξ)
%% =====================================================================
omega1 = alpha_qoe;
omega2 = beta_qoe;
omega3 = gamma_qoe;
omega4 = delta_qoe;
%% [FIX-3] xi_buf 从 1e-3 改为 1.0
%  原值 1e-3 导致缓冲区空时压力项爆炸 (ω4*z/0.001 = 200z)，
%  引发分辨率剧烈振荡。改为 1.0 后压力范围从 [0.02z, 200z]
%  收窄为 [0.018z, 0.2z]，约 10 倍差距，优化更平稳。
xi_buf = 1.0;

%% 预计算：标记哪些用户是"IU自缓存命中"
is_self_cached = false(length(community_users), 1);
for i = 1:length(community_users)
    user_idx = community_users(i);
    if iu_flags(user_idx) == 1 && cache_decision(user_idx, requested_videos(i)) == 1
        is_self_cached(i) = true;
    end
end

%% 迭代优化
final_alltime_qoe = 0;

for t = 1:nf
    convergence_lagrange = [];
    convergence_QoE = [];

    % ---------- 时隙间状态更新 ----------
    if t == 1
        for i = 1:length(community_users)
            r_previous(i, t) = chi(randi(length(chi)));
        end
    else
        r_previous(:, t) = r_decision(:, t-1);
        initial_wait_times(:) = 0;
        for i = 1:length(community_users)
            buffer_state(i, t) = max(0, min(D_bf, ...
                buffer_state(i, t-1) + (download_rates(i,t-1) - r_decision(i,t-1)) * Delta_t));
        end
    end

    %% ================ 主优化循环（Stage A：拉格朗日迭代）================
    for iter = 1:max_iterations

        % ---- 计算当前负载 ----
        sbs_load = 0;
        iu_load = zeros(1, iu_count_per_community);

        for n = 1:length(community_users)
            if task_assignment(n,t) == 0 && ~is_self_cached(n)
                sbs_load = sbs_load + r_decision(n,t);
            end
        end
        for n = 1:iu_count_per_community
            for m_idx = 1:length(community_users)
                if task_assignment(m_idx,t) == n && ~is_self_cached(m_idx)
                    iu_load(n) = iu_load(n) + r_decision(m_idx,t);
                end
            end
        end

        lagrange = 0;
        qoe_all_user = 0;

        % ---- 计算拉格朗日函数值 —— 公式 (43) ----
        for i = 1:length(community_users)
            Bu_current = buffer_state(i, t);
            z_cur = max(r_decision(i,t), 1e-6);

            % 新 QoE 公式 (29)
            qoe_i = omega1 * log(z_cur) ...
                   - omega2 * (z_cur - r_previous(i,t))^2 ...
                   - omega3 * initial_wait_times(i) ...
                   - omega4 * z_cur * Delta_t / (Bu_current + xi_buf);

            % λ 惩罚（每个用户一项）
            lambda_penalty = lambda(i,t) * (r_decision(i,t) - download_rates(i,t));

            lagrange = lagrange + qoe_i - lambda_penalty;
            qoe_all_user = qoe_all_user + qoe_i;
        end

        % μ 惩罚——SBS 节点（仅一项）
        lagrange = lagrange - mu_sbs(t) * (sbs_load - p_sbs);

        % μ 惩罚——每个 IU 节点（各一项）
        for n = 1:iu_count_per_community
            lagrange = lagrange - mu_iu(n,t) * (iu_load(n) - p_iu);
        end

        % ---- 检查收敛性 ----
        convergence_QoE(end+1) = qoe_all_user;
        convergence_lagrange(end+1) = lagrange;
        if iter > 1
            change = abs(convergence_lagrange(end) - convergence_lagrange(end-1));
            if change < epsilon_conv
                break;
            end
        end

        %% ============ 步骤1: 更新分辨率决策 —— 公式 (52)~(63) ============
        for i = 1:length(community_users)

            % IU缓存命中 → 最高分辨率，跳过
            if is_self_cached(i)
                r_decision(i, t) = chi(end);
                continue;
            end

            Bu_current = buffer_state(i, t);

            % 确定 μ 值
            if task_assignment(i,t) == 0
                mu_val = mu_sbs(t);
            else
                mu_val = mu_iu(task_assignment(i,t), t);
            end

            % 公式 (52): φ = ω4·Δt/(BF+ξ) + λ + μ
            phi_val = omega4 * Delta_t / (Bu_current + xi_buf) + lambda(i,t) + mu_val;

            % 公式 (54)~(63): 二次方程求正根
            b_coeff = phi_val - 2 * omega2 * r_previous(i, t);
            discriminant = b_coeff^2 + 8 * omega1 * omega2;
            r_new = (-b_coeff + sqrt(discriminant)) / (4 * omega2);

            % 截断到可行域 —— 公式 (62)
            r_new = min(r_new, download_rates(i, t));
            r_new = max(r_new, 1e-6);
            r_decision(i, t) = r_new;
        end

        %% ============ 步骤2: 更新对偶变量 —— 公式 (64) ============
        % 更新 λ
        for i = 1:length(community_users)
            lambda(i,t) = max(0, lambda(i,t) + eta * (r_decision(i,t) - download_rates(i,t)));
        end

        % 重新计算负载
        sbs_load = 0;
        iu_load = zeros(1, iu_count_per_community);
        for n = 1:length(community_users)
            if task_assignment(n,t) == 0 && ~is_self_cached(n)
                sbs_load = sbs_load + r_decision(n,t);
            end
        end
        mu_sbs(t) = max(0, mu_sbs(t) + eta * (sbs_load - p_sbs));

        for n = 1:iu_count_per_community
            for m_idx = 1:length(community_users)
                if task_assignment(m_idx,t) == n && ~is_self_cached(m_idx)
                    iu_load(n) = iu_load(n) + r_decision(m_idx,t);
                end
            end
            mu_iu(n,t) = max(0, mu_iu(n,t) + eta * (iu_load(n) - p_iu));
        end

    end % iter 循环结束

    %% ================ 分辨率恢复到离散值（Stage B + C）================
    r_final = zeros(length(community_users), 1);

    % Stage B: 比较 higher / lower 的 QoE
    for i = 1:length(community_users)
        Bu_current = buffer_state(i, t);

        %% [FIX-1] 离散化时将候选级别截断到 download_rate 以内
        %  原代码直接取 chi 中的相邻级别，higher 可能 > download_rate，
        %  导致 r_final > download_rate → 缓冲区持续流失 → 振荡崩溃。
        %  修复：先正常找候选级别，再用 download_rate 截断。
        R_cap = download_rates(i, t);  % 该用户该时隙的实际下载速率上界

        if r_decision(i,t) <= chi(1)
            lower = chi(1);  higher = chi(1);
        elseif r_decision(i,t) >= chi(end)
            lower = chi(end); higher = chi(end);
        else
            upper_idx = find(chi >= r_decision(i,t), 1, 'first');
            if upper_idx == 1
                lower = chi(1); higher = chi(1);
            else
                lower = chi(upper_idx - 1);
                higher = chi(upper_idx);
            end
        end

        % ★ 核心修复：将候选级别截断到 download_rate 以内
        higher = min(higher, R_cap);
        lower  = min(lower,  R_cap);

        % 如果截断后两者相等，直接取该值
        if abs(higher - lower) < 1e-9
            r_final(i) = higher;
        else
            qoe_lower  = calculate_qoe_new(Bu_current, lower,  r_previous(i,t), ...
                         initial_wait_times(i), omega1, omega2, omega3, omega4, Delta_t, xi_buf);
            qoe_higher = calculate_qoe_new(Bu_current, higher, r_previous(i,t), ...
                         initial_wait_times(i), omega1, omega2, omega3, omega4, Delta_t, xi_buf);

            if qoe_higher >= qoe_lower
                r_final(i) = higher;
            else
                r_final(i) = lower;
            end
        end
    end

    % Stage C: 检查计算资源约束并进行降级

    % ---- 检查 SBS 约束 ----
    sbs_users = find(task_assignment(:,t) == 0);
    sbs_users_need_transcode = [];
    for idx = 1:length(sbs_users)
        if r_final(sbs_users(idx)) < chi(end) && ~is_self_cached(sbs_users(idx))
            sbs_users_need_transcode(end+1) = sbs_users(idx);
        end
    end

    if ~isempty(sbs_users_need_transcode)
        sbs_total_load = sum(r_final(sbs_users_need_transcode));

        if sbs_total_load > p_sbs
            qoe_losses = [];
            user_resolution_info = [];

            for idx = 1:length(sbs_users_need_transcode)
                i = sbs_users_need_transcode(idx);
                current_res = r_final(i);
                current_res_idx = find(chi == current_res);
                Bu_current = buffer_state(i, t);

                if current_res_idx > 1
                    lower_res = chi(current_res_idx - 1);
                    qoe_current = calculate_qoe_new(Bu_current, current_res, r_previous(i,t), ...
                                  initial_wait_times(i), omega1, omega2, omega3, omega4, Delta_t, xi_buf);
                    qoe_lower   = calculate_qoe_new(Bu_current, lower_res,  r_previous(i,t), ...
                                  initial_wait_times(i), omega1, omega2, omega3, omega4, Delta_t, xi_buf);
                    qoe_loss = qoe_lower - qoe_current;
                    qoe_losses(end+1) = qoe_loss;
                    user_resolution_info(end+1, :) = [i, current_res, lower_res, qoe_loss];
                end
            end

            if ~isempty(qoe_losses)
                [~, sort_indices] = sort(qoe_losses, 'descend');
                sorted_user_info = user_resolution_info(sort_indices, :);

                for idx = 1:size(sorted_user_info, 1)
                    user_i = sorted_user_info(idx, 1);
                    lower_res = sorted_user_info(idx, 3);
                    r_final(user_i) = lower_res;

                    new_sbs_load = 0;
                    for check_idx = 1:length(sbs_users_need_transcode)
                        check_user = sbs_users_need_transcode(check_idx);
                        if r_final(check_user) < chi(end)
                            new_sbs_load = new_sbs_load + r_final(check_user);
                        end
                    end
                    if new_sbs_load <= p_sbs
                        break;
                    end
                end
            end
        end
    end

    % ---- 检查每个 IU 的约束 ----
    for j = 1:iu_count_per_community
        iu_users = find(task_assignment(:,t) == j);
        iu_users_need_transcode = [];
        for idx = 1:length(iu_users)
            if r_final(iu_users(idx)) < chi(end) && ~is_self_cached(iu_users(idx))
                iu_users_need_transcode(end+1) = iu_users(idx);
            end
        end

        if ~isempty(iu_users_need_transcode)
            iu_total_load = sum(r_final(iu_users_need_transcode));

            if iu_total_load > p_iu
                qoe_losses = [];
                user_resolution_info = [];

                for idx = 1:length(iu_users_need_transcode)
                    i = iu_users_need_transcode(idx);
                    current_res = r_final(i);
                    current_res_idx = find(chi == current_res);
                    Bu_current = buffer_state(i, t);

                    if current_res_idx > 1
                        lower_res = chi(current_res_idx - 1);
                        qoe_current = calculate_qoe_new(Bu_current, current_res, r_previous(i,t), ...
                                      initial_wait_times(i), omega1, omega2, omega3, omega4, Delta_t, xi_buf);
                        qoe_lower   = calculate_qoe_new(Bu_current, lower_res,  r_previous(i,t), ...
                                      initial_wait_times(i), omega1, omega2, omega3, omega4, Delta_t, xi_buf);
                        qoe_loss = qoe_lower - qoe_current;
                        qoe_losses(end+1) = qoe_loss;
                        user_resolution_info(end+1, :) = [i, current_res, lower_res, qoe_loss];
                    end
                end

                if ~isempty(qoe_losses)
                    [~, sort_indices] = sort(qoe_losses, 'descend');
                    sorted_user_info = user_resolution_info(sort_indices, :);

                    %% [FIX-2] 修复 IU 降级的双重惩罚 bug
                    %  原代码：降完一级后如果还超限，直接对同一用户再降一级
                    %  修复：每个用户只降一级，然后检查是否满足，满足就 break
                    for idx = 1:size(sorted_user_info, 1)
                        user_i = sorted_user_info(idx, 1);
                        lower_res = sorted_user_info(idx, 3);
                        r_final(user_i) = lower_res;

                        new_iu_load = 0;
                        for check_idx = 1:length(iu_users_need_transcode)
                            check_user = iu_users_need_transcode(check_idx);
                            if r_final(check_user) < chi(end)
                                new_iu_load = new_iu_load + r_final(check_user);
                            end
                        end

                        if new_iu_load <= p_iu
                            break;  % 满足约束，停止降级
                        end
                        % 不满足则继续降级下一个用户（不再对同一用户双重降级）
                    end
                end
            end
        end
    end

    r_decision(:,t) = r_final;

    %% 计算 t 时刻的最终 QoE
    final_total_qoe = 0;
    for i = 1:length(community_users)
        Bu_current = buffer_state(i, t);
        qoe_i = calculate_qoe_new(Bu_current, r_final(i), r_previous(i,t), ...
                initial_wait_times(i), omega1, omega2, omega3, omega4, Delta_t, xi_buf);
        final_total_qoe = final_total_qoe + qoe_i;
    end

    final_alltime_qoe = final_alltime_qoe + final_total_qoe;
end

end % 主函数结束

%% =====================================================================
%%  辅助函数：新 QoE 计算  —— 公式 (29)
%%  QoE = ω1·ln(z) − ω2·(z − z_prev)² − ω3·WT − ω4·z·Δt/(BF + ξ)
%% =====================================================================
function qoe = calculate_qoe_new(BF_current, resolution, r_prev, wait_time, ...
                                  omega1, omega2, omega3, omega4, Delta_t, xi_buf)
    z = max(resolution, 1e-6);
    term1 =  omega1 * log(z);
    term2 = -omega2 * (z - r_prev)^2;
    term3 = -omega3 * wait_time;
    term4 = -omega4 * z * Delta_t / (BF_current + xi_buf);
    qoe = term1 + term2 + term3 + term4;
end
