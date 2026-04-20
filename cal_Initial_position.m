function [sbs_positions,per_user_positions,now_user_positions,user_community] = cal_Initial_position(h, user_per_community, total_users, region_size, community_radius, max_movement_dist, T_small)
%% 初始化社区位置
% 社区中心位置，确保不重叠且整个社区在区域内
sbs_positions = zeros(h, 2);
min_distance = 2 * community_radius; % 最小社区间距离
max_attempts = 1000; % 最大尝试次数

% 初始化第一个SBS的位置
valid_position = false;
attempts = 0;
while ~valid_position && attempts < max_attempts
    attempts = attempts + 1;
    candidate_pos = [rand() * (region_size - 2*community_radius) + community_radius, rand() * (region_size - 2*community_radius) + community_radius];
    % 检查是否在区域内（考虑社区半径）
    if (candidate_pos(1) >= community_radius && candidate_pos(1) <= region_size - community_radius) && (candidate_pos(2) >= community_radius && candidate_pos(2) <= region_size - community_radius)
        sbs_positions(1, :) = candidate_pos;
        valid_position = true;
    end
end

if ~valid_position
    error('无法为SBS 1找到有效位置');
end

% 为其他SBS找位置，确保不重叠且在区域内
for i = 2:h
    valid_position = false;
    attempts = 0;
    
    while ~valid_position && attempts < max_attempts
        attempts = attempts + 1;
        % 随机生成候选位置（考虑社区半径）
        candidate_pos = [rand() * (region_size - 2*community_radius) + community_radius,rand() * (region_size - 2*community_radius) + community_radius];

        % 检查是否在区域内
        if (candidate_pos(1) >= community_radius && candidate_pos(1) <= region_size - community_radius) && (candidate_pos(2) >= community_radius && candidate_pos(2) <= region_size - community_radius)
            
            % 检查与已有SBS的距离
            distances = sqrt(sum((sbs_positions(1:i-1, :) - candidate_pos).^2, 2));
            
            % 如果所有距离都大于最小要求，接受此位置
            if all(distances > min_distance)
                sbs_positions(i, :) = candidate_pos;
                valid_position = true;
            end
        end
    end
    
    if ~valid_position
        error(['无法为SBS ' num2str(i) '找到有效位置']);
    end
end

%% 初始化用户数据结构
user_positions = zeros(total_users, 2, T_small); % 用户位置随时间变化
user_community = zeros(total_users, 1); % 用户所属社区

% 给每个社区分配用户，并初始化所有时间的位置
for m = 1:h
    start_idx = (m-1) * user_per_community + 1;
    end_idx = m * user_per_community;
    
    % 标记用户所属社区
    user_community(start_idx:end_idx) = m;
    
    % 为每个小时间尺度生成泊松分布的用户位置
    for u = start_idx:end_idx
        for t = 1:T_small*2
            if t == 1 % 第一个时间点：在社区覆盖范围内随机生成
                valid_position = false;
                while ~valid_position
                    % 在社区内随机生成位置（极坐标方式）
                    r = sqrt(rand()) * community_radius; % 平方根确保均匀分布
                    theta = 2 * pi * rand();
                    x = sbs_positions(m, 1) + r * cos(theta);
                    y = sbs_positions(m, 2) + r * sin(theta);
                    
                    % 确保位置在系统范围内
                    if x >= 0 && x <= region_size && y >= 0 && y <= region_size
                        user_positions(u, :, t) = [x, y];
                        valid_position = true;
                    end
                end
            else  % 后续时间点：基于前一时间点位置，限制移动距离
                valid_position = false;
                attempts = 0;
                max_attempts = 100;
                
                while ~valid_position && attempts < max_attempts
                    attempts = attempts + 1;
                    
                    % 获取前一时间点的位置
                    prev_position = user_positions(u, :, t-1);
                    
                    % 在最大移动距离内随机生成新位置
                    move_distance = rand() * max_movement_dist;
                    move_angle = 2 * pi * rand();
                    
                    % 计算新位置
                    new_x = prev_position(1) + move_distance * cos(move_angle);
                    new_y = prev_position(2) + move_distance * sin(move_angle);
                    
                    % 检查新位置是否仍在社区范围内
                    dist_to_sbs = sqrt((new_x - sbs_positions(m, 1))^2 +(new_y - sbs_positions(m, 2))^2);
                    
                    % 确保位置在系统范围内且在社区覆盖范围内
                    if new_x >= 0 && new_x <= region_size &&  new_y >= 0 && new_y <= region_size && dist_to_sbs <= community_radius
                        user_positions(u, :, t) = [new_x, new_y];
                        valid_position = true;
                    end
                end
                
                % 如果超过最大尝试次数，使用更保守的方法
                if ~valid_position
                    % 在当前位置附近小范围内移动
                    prev_position = user_positions(u, :, t-1);
                    small_move = 10; % 小幅移动
                    
                    % 向社区中心方向略微移动
                    to_center = sbs_positions(m, :) - prev_position;
                    to_center_normalized = to_center / norm(to_center);
                    
                    new_position = prev_position + small_move * to_center_normalized;
                    
                    % 添加一些随机扰动
                    new_position = new_position + randn(1, 2) * 5;
                    
                    % 确保不超出边界
                    new_position(1) = max(0, min(region_size, new_position(1)));
                    new_position(2) = max(0, min(region_size, new_position(2)));
                    
                    user_positions(u, :, t) = new_position;
                    
                    % 验证移动距离
                    actual_move_dist = norm(new_position - prev_position);
                    if actual_move_dist > max_movement_dist
                        % 如果移动距离过大，按比例缩小
                        direction = (new_position - prev_position) / actual_move_dist;
                        user_positions(u, :, t) = prev_position + direction * max_movement_dist;
                    end
                end
            end
        end
    end
end

per_user_positions = user_positions(:, :, 1:T_small);
now_user_positions = user_positions(:, :, T_small+1:end);

end