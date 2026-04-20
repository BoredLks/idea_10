function [r_decision,r_previous,lambda,mu_sbs,mu_iu,buffer_state] = cal_Initialize_optimization_variables(chi, iu_count_per_community, nf, D_bf, iu_flags, cache_decision, community_users, requested_videos)
%% 初始化优化变量
% 分辨率决策变量：[用户数 × 时隙数]
r_decision = zeros(length(community_users), nf);
r_previous = zeros(length(community_users), nf);

% 初始化分辨率：第一个时隙随机初始化，其他时隙初始化为最低分辨率
for i = 1:length(community_users)
    for t = 1:nf
        r_decision(i, t) = chi(1); % 初始化为最低分辨率
    end
end




% 如果IU用户请求的文件已缓存，则将其所有时隙的分辨率设为最高
for i = 1:length(community_users)
    user_idx = community_users(i);
    if iu_flags(user_idx) == 1 && cache_decision(user_idx, requested_videos(i)) == 1
        for t = 1:nf
            r_decision(i, t) = chi(end);
        end
    end
end



% 缓冲区状态：[用户数 × 时隙数]
buffer_state = zeros(length(community_users), nf); %初始状态
for i = 1:length(community_users)
    buffer_state(i, 1) = D_bf; % 初始缓冲区为满
end

% 对偶变量：为每个用户的每个时隙分配对偶变量
lambda = 1e0 * rand(length(community_users), nf);
mu_sbs = 1e0 * rand(1, nf);
mu_iu = 1e0 * rand(iu_count_per_community, nf);

end