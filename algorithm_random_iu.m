function [final_alltime_qoe, cache_hit_rate, mean_wait_time] = algorithm_random_iu(h, user_per_community, total_users, F, iu_count_per_community, nf, chi, Delta_t, v_chi_star, region_size, sbs_coverage, iu_coverage, community_radius, max_movement_dist, D_eg, D_iu, T_small, gamma_m, alpha, beta, gamma, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, t_cloud, t_propagation, target_community, eta, epsilon_conv, max_iterations, data, item_file_path, theta_sigmoid, beta_fuse, sbs_positions, per_user_positions, now_user_positions, user_community)
%% 对比算法: 随机选择IU + 同样的FAG融合缓存 + 增强请求 + ABR优化
%  与 algorithm_MOIS 唯一区别: IU选择用 randsample 而非 MOIS+空间分散

% ===== 第1步: 使用外部传入的固定位置 =====

% ===== 第2步: MovieLens偏好相似度 =====
sim_matrix = cal_Movielens(data);

% ===== 第3步: 加载电影属性数据 =====
num_movies = max(data(:, 2));
[genre_matrix_ml, release_years_ml, num_genres] = cal_load_item_data(item_file_path, num_movies);

% ===== 第4步: 构建社交感知图 =====
sg_edge_weights = cal_sg_edge_weights(h, total_users, sbs_coverage, alpha, beta, gamma, sbs_positions, per_user_positions, user_community, sim_matrix);

% ===== 第5步: 生成用户文件请求概率 =====
user_file_req_prob = cal_user_file_req_prob(total_users, F, gamma_m, data, sg_edge_weights);

% ===== 第6步: ★ 随机选择IU (与MOIS的唯一区别) =====
[iu_indices, iu_flags] = cal_Select_iu_random(h, user_per_community, total_users, iu_count_per_community);

% ===== 第7步: 构建物理连接图 =====
pl_edge_weights = cal_pl_edge_weights(h, total_users, iu_count_per_community, sbs_coverage, iu_coverage, T_small, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, sbs_positions, per_user_positions, iu_indices, iu_flags);

% ===== 第8步: 构建联合图 =====
% weight_pl = 0.5;
% weight_sg = 0.5;
% joint_edge_weights = zeros(size(pl_edge_weights));
% valid_links = (pl_edge_weights > 0);
% joint_edge_weights(valid_links) = weight_pl * pl_edge_weights(valid_links) + weight_sg * sg_edge_weights(valid_links);
% for i = 1:(total_users + h)
%     if pl_edge_weights(i,i) > 0, joint_edge_weights(i,i) = 1; end
% end

% 公式(39): E = E^pg · E^sg (逐元素乘法)
joint_edge_weights = pl_edge_weights .* sg_edge_weights;

% ===== 第9步: pSPAG缓存偏好 =====
cache_preference = cal_cache_preference(h, total_users, F, user_file_req_prob, joint_edge_weights);

% ===== 第10步: FAG文件属性图 =====
file_movielens_mapping = mod(0:F-1, num_movies) + 1;
FAG_sim = cal_FAG_sim(F, num_movies, num_genres, genre_matrix_ml, release_years_ml, file_movielens_mapping);

% ===== 第11步: pF文件偏好 =====
p_FAG = cal_pF(h, total_users, user_per_community, F, user_file_req_prob, FAG_sim);

% ===== 第12步: Sigmoid融合 =====
fused_preference = cal_fused_preference(h, total_users, F, cache_preference, p_FAG, theta_sigmoid, beta_fuse);

% ===== 第13步: 缓存决策 (同样使用位置感知缓存, 只是IU位置是随机的) =====
cache_decision = cal_cache_decision_MOIS(h, total_users, F, iu_count_per_community, nf, v_chi_star, D_eg, D_iu, iu_indices, fused_preference);

% ===== 第14步: 目标社区用户 =====
community_users = cal_target_community_users(user_per_community, target_community);

% ===== 第15步: 增强版请求生成 =====
requested_videos = cal_requested_videos_enhanced(F, user_file_req_prob, FAG_sim, sg_edge_weights, sim_matrix, user_community, community_users, target_community);

% ===== 第16步: 下载速率和任务分配 =====
[download_rates, task_assignment] = cal_download_rates_task_assignment(h, iu_count_per_community, nf, sbs_coverage, iu_coverage, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, target_community, sbs_positions, now_user_positions, iu_indices, iu_flags, cache_decision, community_users, requested_videos);

% ===== 第17步: 初始等待时间 =====
initial_wait_times = cal_initial_wait_times(h, total_users, iu_count_per_community, v_chi_star, iu_coverage, p_sbs, p_iu, D_bf, t_cloud, t_propagation, target_community, now_user_positions, iu_indices, iu_flags, cache_decision, community_users, requested_videos, download_rates);
mean_wait_time = mean(initial_wait_times);

% ===== 第18步: 初始化优化变量 =====
[r_decision, r_previous, lambda, mu_sbs, mu_iu, buffer_state] = cal_Initialize_optimization_variables(chi, iu_count_per_community, nf, D_bf, iu_flags, cache_decision, community_users, requested_videos);

% ===== 第19步: QoE优化 =====
final_alltime_qoe = cal_final_alltime_qoe(iu_count_per_community, nf, chi, Delta_t, alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, eta, epsilon_conv, max_iterations, iu_flags, user_file_req_prob, cache_decision, community_users, requested_videos, download_rates, task_assignment, initial_wait_times, r_decision, r_previous, lambda, mu_sbs, mu_iu, buffer_state);

% ===== 第20步: 缓存命中率 =====
[cache_hit_rate, iu_hit_rate, sbs_hit_rate] = cal_hit_rate(total_users, nf, target_community, cache_decision, community_users, requested_videos, task_assignment, now_user_positions, iu_indices, iu_coverage, iu_flags);

end
