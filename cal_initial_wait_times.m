function initial_wait_times = cal_initial_wait_times(h, total_users, iu_count_per_community, v_chi_star, iu_coverage, p_sbs, p_iu, D_bf, t_cloud, t_propagation, target_community, user_positions, iu_indices, iu_flags, cache_decision, community_users, requested_videos, download_rates)

%% 计算初始等待时间 T_w
initial_wait_times = zeros(length(community_users), 1);

for i = 1:length(community_users)
    user_idx = community_users(i);
    requested_video = requested_videos(i);

    if iu_flags(user_idx) == 1 && cache_decision(user_idx, requested_video) == 1
        % Case 1: IU用户请求自己缓存的文件
        initial_wait_times(i) = 0;
    elseif cache_decision(total_users + target_community, requested_video) == 1
        % Case 2: 文件缓存在本地SBS
        transcode_time = v_chi_star / p_sbs;
        buffer_fill_time = D_bf / download_rates(i,1);
        initial_wait_times(i) = transcode_time + buffer_fill_time;
    else
        % 检查是否有IU缓存了该文件
        found_in_iu = false;
        for j = 1:iu_count_per_community
            iu_idx = iu_indices(target_community, j);
            dist = sqrt(sum((user_positions(user_idx, :, 1) - user_positions(iu_idx, :, 1)).^2)); % 时间为t=1时的位置信息
            if cache_decision(iu_idx, requested_video) == 1 && dist <= iu_coverage
                % Case 3: 文件缓存在社区IU上
                transcode_time = v_chi_star / p_iu;
                buffer_fill_time = D_bf / download_rates(i,1);% 时间为t=1时的下载速率信息
                initial_wait_times(i) = transcode_time + buffer_fill_time;
                found_in_iu = true;
                break;
            end
        end

        if ~found_in_iu
            % 检查其他SBS是否缓存了该文件
            found_in_other_sbs = false;
            for m = 1:h
                if m ~= target_community
                    sbs_idx = total_users + m;
                    if cache_decision(sbs_idx, requested_video) == 1
                        % Case 4: 文件缓存在其他SBS
                        transcode_time = v_chi_star / p_sbs;
                        buffer_fill_time = D_bf / download_rates(i,1);% 时间为t=1时的下载速率信息
                        initial_wait_times(i) = t_propagation + transcode_time + buffer_fill_time;
                        found_in_other_sbs = true;
                        break;
                    end
                end
            end

            if ~found_in_other_sbs
                % Case 5: 需要从云端获取
                transcode_time = v_chi_star / p_sbs;
                buffer_fill_time = D_bf / download_rates(i,1);% 时间为t=1时的下载速率信息
                initial_wait_times(i) = t_cloud + transcode_time + buffer_fill_time;
            end
        end
    end
end

end