%% 辅助函数：计算QoE
function qoe = calculate_qoe(Bu_current, resolution, r_prev, wait_time, download_rate, alpha, beta, gamma, delta, nf, Delta_t, timeslot)
    % 计算各项QoE指标
    VQ = resolution;
    SW = (resolution - r_prev)^2;
    T_w = wait_time;
    
    % 计算EI
    T_remaining = nf * Delta_t - (timeslot - 1) * Delta_t;
    Bh = download_rate;
    
    if Bh > resolution
        EI = 1;
    else
        if T_remaining > 0
            numerator = Bu_current + T_remaining * Bh;
            denominator = resolution * T_remaining;
            if denominator > 0
                EI = min(1, numerator / denominator);
            else
                EI = 1;
            end
        else
            EI = 1;
        end
    end
    
    % 计算QoE
    qoe = alpha * VQ - beta * SW - gamma * T_w + delta * EI;
end