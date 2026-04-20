function p_FAG = cal_pF(h, total_users, user_per_community, F, user_file_req_prob, FAG_sim)
%% 计算文件偏好因子pF (公式41)
% pF_vi,f = q_vi,f * avg_sim_f
% avg_sim_f = mean(e^fg_{f,fl}) for all neighbors fl

% 预计算每个文件f的平均FAG相似度
avg_sim_per_file = zeros(F, 1);
for f = 1:F
    neighbors_f = find(FAG_sim(f, :) > 0);
    if ~isempty(neighbors_f)
        avg_sim_per_file(f) = sum(FAG_sim(f, neighbors_f)) / length(neighbors_f);
    else
        avg_sim_per_file(f) = 0;
    end
end

% 计算pF矩阵 (所有节点 x 所有文件)
p_FAG = zeros(total_users + h, F);

for i = 1:(total_users + h)
    for f = 1:F
        if i <= total_users
            p_FAG(i, f) = user_file_req_prob(i, f) * avg_sim_per_file(f);
        else
            % SBS节点: 使用覆盖用户的平均请求概率
            m_sbs = i - total_users;
            com_start = (m_sbs-1) * user_per_community + 1;
            com_end   = m_sbs * user_per_community;
            avg_req = mean(user_file_req_prob(com_start:com_end, f));
            p_FAG(i, f) = avg_req * avg_sim_per_file(f);
        end
    end
end

end
