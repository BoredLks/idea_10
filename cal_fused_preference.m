function fused_preference = cal_fused_preference(h, total_users, F, cache_preference, p_FAG, theta_sigmoid, beta_fuse)
%% Sigmoid融合 (公式42): pSPAG + pF → 最终偏好
% p_vi,f = 1 / (1 + exp(-theta * [beta * pSPAG + (1-beta) * pF]))

fused_preference = zeros(total_users + h, F);

for i = 1:(total_users + h)
    for f = 1:F
        combined = beta_fuse * cache_preference(i, f) + ...
                   (1 - beta_fuse) * p_FAG(i, f);
        fused_preference(i, f) = 1.0 / (1.0 + exp(-theta_sigmoid * combined));
    end
end

end
