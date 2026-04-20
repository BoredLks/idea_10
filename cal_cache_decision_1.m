function cache_decision = cal_cache_decision_1(h, total_users, F, iu_count_per_community, sbs_coverage, iu_coverage, nf, v_chi_star, D_eg, D_iu, sbs_positions, user_positions, iu_indices, iu_flags, user_file_req_prob)

% %% 算法一：本地最受欢迎内容缓存 (Local Most Popular Content)
% cache_decision = zeros(total_users + h, F);% 初始化缓存决策
% user_avg_positions = mean(user_positions, 3);% 计算每个用户在大时间尺度内的平均位置
% cache_popular = zeros(total_users + h, F);% 内容欢迎度
% sbs_cache_space = zeros(h, 1); % 跟踪每个SBS已使用的缓存空间
% iu_cache_space = zeros(total_users, 1); % 跟踪每个IU已使用的缓存空间
% % 计算每个节点对每个文件的内容欢迎度
% for i = 1:(total_users + h)
%     % 找出所有能接收i提供服务的节点（出度邻居）out_neighbors = find(joint_edge_weights(i, :) > 0);
%     if i <= total_users % 节点i是用户
%         if iu_flags(i) == 1 % 节点i是IU，找出在D2D覆盖范围内的所有用户
%             out_neighbors = [];
%             for j = 1:total_users
%                 dist = sqrt(sum((user_avg_positions(i, :) - user_avg_positions(j, :)).^2));
%                 if dist <= iu_coverage
%                     out_neighbors = [out_neighbors, j];
%                 end
%             end
%         else
%             % 节点i是普通用户，不提供缓存服务
%             out_neighbors = [];
%         end
%     else
%         % 节点i是SBS
%         m = i - total_users; % SBS编号
%         out_neighbors = [];
%         for j = 1:total_users
%             dist = sqrt(sum((user_avg_positions(j, :) - sbs_positions(m, :)).^2));
%             if dist <= sbs_coverage
%                 out_neighbors = [out_neighbors, j];
%             end
%         end
%     end
% 
% 
%     if ~isempty(out_neighbors)
%         for k = 1:F
%             popular_sum = 0;
% 
%             for j = out_neighbors
%                 if j <= total_users % 只考虑用户节点的请求概率
%                     popular_sum = popular_sum + user_file_req_prob(j, k);
%                 end
%             end
% 
%             cache_popular(i, k) = popular_sum / length(out_neighbors);
%         end
%     end
% end
% 
% % 缓存分配
% for m = 1:h
%     sbs_idx = total_users + m;
% 
%     % 获取此SBS的缓存偏好
%     sbs_popular = cache_popular(sbs_idx, :);
% 
% 
%     % 根据偏好排序文件
%     [sorted_pop, file_indices] = sort(sbs_popular, 'descend');
% 
%     % 按偏好顺序尝试缓存文件
%     for idx = 1:length(file_indices)
%         f = file_indices(idx);
% 
%         if sorted_pop(idx) > 0 % 只考虑有正偏好的文件
%             % 检查缓存空间是否足够
%             if sbs_cache_space(m) + nf * v_chi_star <= D_eg
%                 cache_decision(sbs_idx, f) = 1;
%                 sbs_cache_space(m) = sbs_cache_space(m) + nf * v_chi_star;
%             else
%                 break; % 空间不足，停止缓存
%             end
%         else
%             break; % 无正偏好，停止缓存
%         end
%     end
% end
% 
% 
% for m = 1:h
%     for i = 1:iu_count_per_community
%         iu_idx = iu_indices(m, i);
% 
%         % 获取此IU的缓存偏好
%         iu_popular = cache_popular(iu_idx, :);
% 
%         % 根据偏好排序文件
%         [sorted_pop, file_indices] = sort(iu_popular, 'descend');
% 
%         % 按偏好顺序尝试缓存文件
%         for idx = 1:length(file_indices)
%             f = file_indices(idx);
% 
%             if sorted_pop(idx) > 0 % 只考虑有正偏好的文件
%                 % 检查缓存空间是否足够
%                 if iu_cache_space(iu_idx) + nf * v_chi_star <= D_iu
%                     cache_decision(iu_idx, f) = 1;
%                     iu_cache_space(iu_idx) = iu_cache_space(iu_idx) + nf * v_chi_star;
%                 else
%                     break; % 空间不足，停止缓存
%                 end
%             else
%                 break; % 无正偏好，停止缓存
%             end
%         end
%     end
% end




%% 算法一：本地最受欢迎内容缓存 (Local Most Popular Content)
cache_decision = zeros(total_users + h, F);% 初始化缓存决策
user_avg_positions = user_positions(:,:,1); % 使用第一小时隙作为位置图
cache_popular = zeros(total_users + h, F);% 内容欢迎度
sbs_cache_space = zeros(h, 1); % 跟踪每个SBS已使用的缓存空间
iu_cache_space = zeros(total_users, 1); % 跟踪每个IU已使用的缓存空间
% 计算每个节点对每个文件的内容欢迎度
for i = 1:(total_users + h)
    % 找出所有能接收i提供服务的节点（出度邻居）out_neighbors = find(joint_edge_weights(i, :) > 0);
    if i <= total_users % 节点i是用户
        if iu_flags(i) == 1 % 节点i是IU，找出在D2D覆盖范围内的所有用户
            out_neighbors = [];
            for j = 1:total_users
                dist = sqrt(sum((user_avg_positions(i, :) - user_avg_positions(j, :)).^2));
                if dist <= iu_coverage
                    out_neighbors = [out_neighbors, j];
                end
            end
        else
            % 节点i是普通用户，不提供缓存服务
            out_neighbors = [];
        end
    else
        % 节点i是SBS
        m = i - total_users; % SBS编号
        out_neighbors = [];
        for j = 1:total_users
            dist = sqrt(sum((user_avg_positions(j, :) - sbs_positions(m, :)).^2));
            if dist <= sbs_coverage
                out_neighbors = [out_neighbors, j];
            end
        end
    end


    if ~isempty(out_neighbors)
        for k = 1:F
            popular_sum = 0;
            
            for j = out_neighbors
                if j <= total_users % 只考虑用户节点的请求概率
                    popular_sum = popular_sum + user_file_req_prob(j, k);
                end
            end
            
            cache_popular(i, k) = popular_sum / length(out_neighbors);
        end
    end
end

% 缓存分配
for m = 1:h
    sbs_idx = total_users + m;

    % 获取此SBS的缓存偏好
    sbs_popular = cache_popular(sbs_idx, :);


    % 根据偏好排序文件
    [sorted_pop, file_indices] = sort(sbs_popular, 'descend');

    % 按偏好顺序尝试缓存文件
    for idx = 1:length(file_indices)
        f = file_indices(idx);

        if sorted_pop(idx) > 0 % 只考虑有正偏好的文件
            % 检查缓存空间是否足够
            if sbs_cache_space(m) + nf * v_chi_star <= D_eg
                cache_decision(sbs_idx, f) = 1;
                sbs_cache_space(m) = sbs_cache_space(m) + nf * v_chi_star;
            else
                break; % 空间不足，停止缓存
            end
        else
            break; % 无正偏好，停止缓存
        end
    end
end


for m = 1:h
    for i = 1:iu_count_per_community
        iu_idx = iu_indices(m, i);

        % 获取此IU的缓存偏好
        iu_popular = cache_popular(iu_idx, :);

        % 根据偏好排序文件
        [sorted_pop, file_indices] = sort(iu_popular, 'descend');

        % 按偏好顺序尝试缓存文件
        for idx = 1:length(file_indices)
            f = file_indices(idx);

            if sorted_pop(idx) > 0 % 只考虑有正偏好的文件
                % 检查缓存空间是否足够
                if iu_cache_space(iu_idx) + nf * v_chi_star <= D_iu
                    cache_decision(iu_idx, f) = 1;
                    iu_cache_space(iu_idx) = iu_cache_space(iu_idx) + nf * v_chi_star;
                else
                    break; % 空间不足，停止缓存
                end
            else
                break; % 无正偏好，停止缓存
            end
        end
    end
end





end