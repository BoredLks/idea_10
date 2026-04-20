function [final_alltime_qoe, cache_hit_rate, mean_wait_time] = algorithm_NAV(h, user_per_community, total_users, F, iu_count_per_community, nf, chi, Delta_t, v_chi_star, region_size, sbs_coverage, iu_coverage, community_radius, max_movement_dist, D_eg, D_iu, T_small, gamma_m, alpha, beta, gamma, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, t_cloud, t_propagation, target_community, eta, epsilon_conv, max_iterations, data, item_file_path, theta_sigmoid, beta_fuse, sbs_positions, per_user_positions, now_user_positions, user_community)
%% NAV: 无自适应视频 — 使用Proposed缓存但固定分辨率, 不做ABR优化

sim_matrix = cal_Movielens(data);
num_movies = max(data(:, 2));
[genre_matrix_ml, release_years_ml, num_genres] = cal_load_item_data(item_file_path, num_movies);
sg_edge_weights = cal_sg_edge_weights(h, total_users, sbs_coverage, alpha, beta, gamma, sbs_positions, per_user_positions, user_community, sim_matrix);
user_file_req_prob = cal_user_file_req_prob(total_users, F, gamma_m, data, sg_edge_weights);
[iu_indices, iu_flags] = cal_Select_iu_MOIS(h, user_per_community, total_users, iu_count_per_community, iu_coverage, T_small, B, P_iu, N0, K, epsilon, slowfading_dB, per_user_positions, sg_edge_weights);
pl_edge_weights = cal_pl_edge_weights(h, total_users, iu_count_per_community, sbs_coverage, iu_coverage, T_small, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, sbs_positions, per_user_positions, iu_indices, iu_flags);
joint_edge_weights = pl_edge_weights .* sg_edge_weights;
cache_preference = cal_cache_preference(h, total_users, F, user_file_req_prob, joint_edge_weights);
file_movielens_mapping = mod(0:F-1, num_movies) + 1;
FAG_sim = cal_FAG_sim(F, num_movies, num_genres, genre_matrix_ml, release_years_ml, file_movielens_mapping);
p_FAG = cal_pF(h, total_users, user_per_community, F, user_file_req_prob, FAG_sim);
fused_preference = cal_fused_preference(h, total_users, F, cache_preference, p_FAG, theta_sigmoid, beta_fuse);

% 使用Proposed的缓存决策
cache_decision = cal_cache_decision_MOIS(h, total_users, F, iu_count_per_community, nf, v_chi_star, D_eg, D_iu, iu_indices, fused_preference, user_file_req_prob, per_user_positions, iu_coverage);

community_users = cal_target_community_users(user_per_community, target_community);
requested_videos = cal_requested_videos_enhanced(F, user_file_req_prob, FAG_sim, sg_edge_weights, sim_matrix, user_community, community_users, target_community);
[download_rates, task_assignment] = cal_download_rates_task_assignment(h, iu_count_per_community, nf, sbs_coverage, iu_coverage, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, target_community, sbs_positions, now_user_positions, iu_indices, iu_flags, cache_decision, community_users, requested_videos);
initial_wait_times = cal_initial_wait_times(h, total_users, iu_count_per_community, v_chi_star, iu_coverage, p_sbs, p_iu, D_bf, t_cloud, t_propagation, target_community, now_user_positions, iu_indices, iu_flags, cache_decision, community_users, requested_videos, download_rates);
mean_wait_time = mean(initial_wait_times);
[r_decision, r_previous, ~, ~, ~, buffer_state] = cal_Initialize_optimization_variables(chi, iu_count_per_community, nf, D_bf, iu_flags, cache_decision, community_users, requested_videos);

% ★ 无自适应: 固定分辨率, 使用新QoE模型计算
final_alltime_qoe = cal_final_alltime_qoe_without_adaption(nf, chi, Delta_t, alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, D_bf, community_users, download_rates, initial_wait_times, r_decision, r_previous, buffer_state);

[cache_hit_rate, ~, ~] = cal_hit_rate(total_users, nf, target_community, cache_decision, community_users, requested_videos, task_assignment, now_user_positions, iu_indices, iu_coverage, iu_flags);
end
