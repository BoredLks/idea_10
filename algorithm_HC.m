function [final_alltime_qoe, cache_hit_rate, mean_wait_time] = algorithm_HC(h, user_per_community, total_users, F, iu_count_per_community, nf, chi, Delta_t, v_chi_star, region_size, sbs_coverage, iu_coverage, community_radius, max_movement_dist, D_eg, D_iu, T_small, gamma_m, alpha, beta, gamma, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, t_cloud, t_propagation, target_community, eta, epsilon_conv, max_iterations, data, item_file_path, theta_sigmoid, beta_fuse, sbs_positions, per_user_positions, now_user_positions, user_community)
%% HC: 混合缓存 + MOIS-IU + 增强请求 + 新QoE

sim_matrix = cal_Movielens(data);
num_movies = max(data(:, 2));
[genre_matrix_ml, release_years_ml, num_genres] = cal_load_item_data(item_file_path, num_movies);
sg_edge_weights = cal_sg_edge_weights(h, total_users, sbs_coverage, alpha, beta, gamma, sbs_positions, per_user_positions, user_community, sim_matrix);
user_file_req_prob = cal_user_file_req_prob(total_users, F, gamma_m, data, sg_edge_weights);
[iu_indices, iu_flags] = cal_Select_iu_MOIS(h, user_per_community, total_users, iu_count_per_community, iu_coverage, T_small, B, P_iu, N0, K, epsilon, slowfading_dB, per_user_positions, sg_edge_weights);

% ★ HC缓存决策
cache_decision = cal_cache_decision_3(h, user_per_community, total_users, F, iu_count_per_community, nf, v_chi_star, D_eg, D_iu, iu_indices, user_file_req_prob);

community_users = cal_target_community_users(user_per_community, target_community);
file_movielens_mapping = mod(0:F-1, num_movies) + 1;
FAG_sim = cal_FAG_sim(F, num_movies, num_genres, genre_matrix_ml, release_years_ml, file_movielens_mapping);
requested_videos = cal_requested_videos_enhanced(F, user_file_req_prob, FAG_sim, sg_edge_weights, sim_matrix, user_community, community_users, target_community);
[download_rates, task_assignment] = cal_download_rates_task_assignment(h, iu_count_per_community, nf, sbs_coverage, iu_coverage, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, target_community, sbs_positions, now_user_positions, iu_indices, iu_flags, cache_decision, community_users, requested_videos);
initial_wait_times = cal_initial_wait_times(h, total_users, iu_count_per_community, v_chi_star, iu_coverage, p_sbs, p_iu, D_bf, t_cloud, t_propagation, target_community, now_user_positions, iu_indices, iu_flags, cache_decision, community_users, requested_videos, download_rates);
mean_wait_time = mean(initial_wait_times);
[r_decision, r_previous, lambda, mu_sbs, mu_iu, buffer_state] = cal_Initialize_optimization_variables(chi, iu_count_per_community, nf, D_bf, iu_flags, cache_decision, community_users, requested_videos);
final_alltime_qoe = cal_final_alltime_qoe(iu_count_per_community, nf, chi, Delta_t, alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, eta, epsilon_conv, max_iterations, iu_flags, user_file_req_prob, cache_decision, community_users, requested_videos, download_rates, task_assignment, initial_wait_times, r_decision, r_previous, lambda, mu_sbs, mu_iu, buffer_state);
[cache_hit_rate, ~, ~] = cal_hit_rate(total_users, nf, target_community, cache_decision, community_users, requested_videos, task_assignment, now_user_positions, iu_indices, iu_coverage, iu_flags);
end
