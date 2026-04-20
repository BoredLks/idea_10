function [iu_indices, iu_flags] = cal_Select_iu_random(h, user_per_community, total_users, iu_count_per_community)
%% 随机选择IU — 对比基线
%  每个社区内随机选取 iu_count_per_community 个用户作为IU
%  不考虑社交关系、物理位置、覆盖范围, 纯随机

iu_indices = zeros(h, iu_count_per_community);
iu_flags = zeros(total_users, 1);

for m = 1:h
    community_user_indices = (m-1) * user_per_community + (1:user_per_community);
    selected_iu = randsample(community_user_indices, iu_count_per_community);
    iu_indices(m, :) = selected_iu;
    iu_flags(selected_iu) = 1;
end

end
