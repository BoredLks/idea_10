function final_alltime_qoe = cal_final_alltime_qoe_without_adaption(nf, chi, Delta_t, alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, D_bf, community_users, download_rates, initial_wait_times, r_decision, r_previous, buffer_state)
%% 无自适应: 固定分辨率 chi(2), 使用新QoE模型 公式(29)
omega1 = alpha_qoe;
omega2 = beta_qoe;
omega3 = gamma_qoe;
omega4 = delta_qoe;
xi_buf = 1.0;  % [FIX-3] 与 cal_final_alltime_qoe.m 保持一致

final_alltime_qoe = 0;

for t = 1:nf
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

    % 固定分辨率
    r_decision(:, t) = chi(2);

    % 计算t时刻QoE
    final_total_qoe = 0;
    for i = 1:length(community_users)
        Bu_current = buffer_state(i, t);
        z = max(r_decision(i, t), 1e-6);
        qoe_i = omega1 * log(z) ...
               - omega2 * (z - r_previous(i, t))^2 ...
               - omega3 * initial_wait_times(i) ...
               - omega4 * z * Delta_t / (Bu_current + xi_buf);
        final_total_qoe = final_total_qoe + qoe_i;
    end

    final_alltime_qoe = final_alltime_qoe + final_total_qoe;
end

end
