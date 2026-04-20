function sg_edge_weights = cal_sg_edge_weights(h, total_users, sbs_coverage, alpha, beta, gamma, sbs_positions, user_positions, user_community, sim_matrix)
%% 构建社交感知图
sg_edge_weights = zeros(total_users + h, total_users + h);
user_avg_positions = mean(user_positions, 3);

% 首先为每个用户生成固定的朋友集合
user_friends = cell(total_users, 1);
for u = 1:total_users
    community_u = user_community(u);
    community_users = find(user_community == community_u);
    % 在社区内随机选择约50%的用户作为朋友（包括自己）
    num_friends = min(round(length(community_users) * 0.5), length(community_users));
    user_friends{u} = community_users(randperm(length(community_users), num_friends));
end

% 计算用户间的社交关系
for i = 1:total_users
    % 自环边权重为1
    sg_edge_weights(i, i) = 1;
    
    % 确定用户i所属的社区
    community_i = user_community(i);
    
    % 计算与其他用户的边权重
    for j = i+1:total_users  % 只计算上三角矩阵，确保对称性
        % 确定用户j所属的社区
        community_j = user_community(j);
        
        if community_i == community_j
            % 1. 计算亲密度
            J_vi = user_friends{i};
            J_vj = user_friends{j};
            
            intersection_size = length(intersect(J_vi, J_vj));
            union_size = length(union(J_vi, J_vj));
            
            if union_size > 0
                IN_vi_vj = intersection_size / union_size;
            else
                IN_vi_vj = 0;
            end
            
            % 2. 计算偏好相似度
            PS_vi_vj = sim_matrix(i,j);
            
            % 3. 计算历史交互预测重要程度
            IM_vi_vj = rand();
            
            % 计算总的边权重
            edge_weight = alpha * IN_vi_vj + beta * PS_vi_vj + gamma * IM_vi_vj;
            
            % 确保对称性
            sg_edge_weights(i, j) = edge_weight;
            sg_edge_weights(j, i) = edge_weight;
        else
            % 不同社区的用户之间边权重为0
            sg_edge_weights(i, j) = 0;
            sg_edge_weights(j, i) = 0;
        end
    end
    
    % 计算用户与SBS之间的边权重
    for m = 1:h
        sbs_idx = total_users + m;
        
        % 计算用户到SBS的平均距离
        avg_dist = sqrt(sum((user_avg_positions(i, :) - sbs_positions(m, :)).^2));
        
        % 如果用户在SBS覆盖范围内
        if avg_dist <= sbs_coverage
            sg_edge_weights(sbs_idx, i) = 1;
            sg_edge_weights(i, sbs_idx) = 1;
        else
            sg_edge_weights(sbs_idx, i) = 0;
            sg_edge_weights(i, sbs_idx) = 0;
        end
    end
end

end