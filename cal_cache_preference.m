function cache_preference = cal_cache_preference(h, total_users, F, user_file_req_prob, joint_edge_weights)
%% 计算pSPAG缓存偏好 (公式40)
% pSPAG_vi,f = (1/|N+(vi)|) * sum_{vj in N+(vi)} q_vj,f * e_{vi,vj}

cache_preference = zeros(total_users + h, F);

for i = 1:(total_users + h)
    out_neighbors = find(joint_edge_weights(i, :) > 0);
    % out_neighbors = out_neighbors(~ismember(out_neighbors, i)); %排除IU节点自己的偏好。

    if ~isempty(out_neighbors)
        for k = 1:F
            preference_sum = 0;
            for j = out_neighbors
                if j <= total_users
                    preference_sum = preference_sum + ...
                        user_file_req_prob(j, k) * joint_edge_weights(i, j);
                end
            end
            cache_preference(i, k) = preference_sum / length(out_neighbors);
        end
    end
end

end
