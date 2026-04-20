function requested_videos = cal_requested_videos_enhanced(F, user_file_req_prob, FAG_sim, sg_edge_weights, sim_matrix, user_community, community_users, target_community)
%% 增强版视频请求生成
% 融合社交邻居影响 + FAG文件相似性
% q_enhanced = q_zipf * (1 + lambda_social * Social_boost) * (1 + lambda_fag * FAG_boost)

lambda_social_req = 0.8;
lambda_fag_req    = 0.5;
top_k_friends     = 5;

N_users_com = length(community_users);

% 映射 (与cal_user_file_req_prob中一致)
num_users_ml = size(sim_matrix, 1);
user_movielens_mapping = mod(0:max(community_users)-1, num_users_ml) + 1;

% 为每个用户生成朋友集合
user_friends = cell(max(community_users), 1);
for u = community_users
    com_members = find(user_community == target_community);
    num_friends = min(round(length(com_members) * 0.5), length(com_members));
    user_friends{u} = com_members(randperm(length(com_members), num_friends));
end

%% 因素1: 社交邻居影响
Social_boost = zeros(N_users_com, F);

for i = 1:N_users_com
    user_idx = community_users(i);
    friends_global = user_friends{user_idx};
    friends_in_com = friends_global(user_community(friends_global) == target_community);

    if ~isempty(friends_in_com)
        sg_weights = sg_edge_weights(user_idx, friends_in_com);
        mi = user_movielens_mapping(user_idx);
        ps_weights = zeros(size(friends_in_com));
        for jj = 1:length(friends_in_com)
            mj = user_movielens_mapping(friends_in_com(jj));
            ps_weights(jj) = sim_matrix(mi, mj);
        end
        combined_w = 0.5 * sg_weights + 0.5 * ps_weights;

        k = min(top_k_friends, length(friends_in_com));
        [~, top_idx] = sort(combined_w, 'descend');
        top_friends = friends_in_com(top_idx(1:k));
        top_weights = combined_w(top_idx(1:k));

        for jj = 1:k
            Social_boost(i, :) = Social_boost(i, :) + ...
                top_weights(jj) * user_file_req_prob(top_friends(jj), :);
        end
    end
end

for i = 1:N_users_com
    mx = max(Social_boost(i, :));
    if mx > 0
        Social_boost(i, :) = Social_boost(i, :) / mx;
    end
end

%% 因素2: FAG文件相似性
FAG_boost = zeros(N_users_com, F);

for i = 1:N_users_com
    user_idx = community_users(i);
    for f = 1:F
        neighbors_f = find(FAG_sim(f, :) > 0);
        if ~isempty(neighbors_f)
            boost = sum(user_file_req_prob(user_idx, neighbors_f) .* FAG_sim(f, neighbors_f));
            FAG_boost(i, f) = boost / length(neighbors_f);
        end
    end
end

for i = 1:N_users_com
    mx = max(FAG_boost(i, :));
    if mx > 0
        FAG_boost(i, :) = FAG_boost(i, :) / mx;
    end
end

%% 融合: 乘法增强 + 重新归一化
enhanced_req_prob = zeros(N_users_com, F);

for i = 1:N_users_com
    user_idx = community_users(i);
    q_base = user_file_req_prob(user_idx, :);
    social_factor = 1 + lambda_social_req * Social_boost(i, :);
    fag_factor    = 1 + lambda_fag_req    * FAG_boost(i, :);
    enhanced_req_prob(i, :) = q_base .* social_factor .* fag_factor;

    total = sum(enhanced_req_prob(i, :));
    if total > 0
        enhanced_req_prob(i, :) = enhanced_req_prob(i, :) / total;
    else
        enhanced_req_prob(i, :) = q_base;
    end
end

%% 采样请求视频
requested_videos = zeros(N_users_com, 1);
for i = 1:N_users_com
    cumulative_prob = cumsum(enhanced_req_prob(i, :));
    rand_val = rand();
    requested_videos(i) = find(cumulative_prob >= rand_val, 1);
end


end
