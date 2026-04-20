function [cache_hit_rate, iu_hit_rate, sbs_hit_rate] = cal_hit_rate(total_users, nf, target_community, cache_decision, community_users, requested_videos, task_assignment, user_positions, iu_indices, iu_coverage, iu_flags)
%% 计算缓存命中率 — 请求级别
%  每个用户请求一个视频, 判断能否被IU或SBS命中
%  IU距离判断使用 t=1 时刻的位置

t_ref = 1;  % 固定使用第1个时隙的位置判断IU距离

iu_hit_total  = 0;
sbs_hit_total = 0;
total_requests = length(requested_videos);

for i = 1:total_requests
    user_idx = community_users(i);
    requested_video = requested_videos(i);

    % === 1. 优先检查IU缓存 ===
    iu_hit = false;

    % Case A: 用户自己是IU且缓存了请求文件
    if iu_flags(user_idx) == 1 && cache_decision(user_idx, requested_video) == 1
        iu_hit = true;
    else
        % Case B: 遍历附近IU
        for j = 1:size(iu_indices, 2)
            iu_idx = iu_indices(target_community, j);
            if cache_decision(iu_idx, requested_video) == 1
                dist = sqrt(sum((user_positions(user_idx, :, t_ref) - user_positions(iu_idx, :, t_ref)).^2));
                if dist <= iu_coverage
                    iu_hit = true;
                    break;
                end
            end
        end
    end

    % === 2. IU未命中时检查SBS缓存 ===
    sbs_hit = false;
    if ~iu_hit && cache_decision(total_users + target_community, requested_video) == 1
        sbs_hit = true;
    end

    if iu_hit
        iu_hit_total = iu_hit_total + 1;
    elseif sbs_hit
        sbs_hit_total = sbs_hit_total + 1;
    end
end

% 计算各项命中率
cache_hit_rate = (iu_hit_total + sbs_hit_total) / total_requests;
iu_hit_rate    = iu_hit_total / total_requests;
sbs_hit_rate   = sbs_hit_total / total_requests;

end