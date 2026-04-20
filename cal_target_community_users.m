function community_users = cal_target_community_users(user_per_community, target_community)
%% 获取目标社区参数
start_idx = (target_community-1) * user_per_community + 1;
end_idx = target_community * user_per_community;
community_users = start_idx:end_idx;

end