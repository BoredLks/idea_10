clc; close all; clear; tic;

%% 参数设置
h = 3;
F = 200;
Per_m = 0.3;
nf = 100;
chi = [1.5 , 2 , 5 , 10 , 12];
chi_star = chi(end);
Delta_t = 1;
v_chi_star = chi_star * Delta_t / 8;

region_size = 1500;
sbs_coverage = 150;
iu_coverage = 50;
community_radius = 150;
max_movement_dist = 2;
T_small = 100;
gamma_m = 0.9;

% 社交感知图参数
alpha = 0.2;               % 亲密度权重
beta = 0.7;                % 偏好相似度权重
gamma = 0.1;               % 预测重要程度权重

% 通信参数
B = 2;                    % 带宽，单位:MHz
P_sbs = 1;               % SBS发射功率，单位:W 30dbm
P_iu = 0.3;               % IU发射功率，单位:W 23dbm
N0 = 1e-7;                 % 噪声功率，单位:W
K = 1;                     % 系统参数
epsilon = 3;               % 路径损失指数
slowfading_dB = 3;% 慢衰落（阴影衰落）的标准差 (dB)

%% QoE模型参数设置
alpha_qoe = 0.65;    % 视频分辨率权重
beta_qoe = 0.05;     % 质量变化率权重
gamma_qoe = 0.2;    % 初始等待时间权重
delta_qoe = 0.1;    % 视频预期完整性权重

D_eg = 30 * nf * v_chi_star;
D_iu = 10 * nf * v_chi_star;
p_sbs = 100; p_iu = 10; D_bf = 10; t_cloud = 2; t_propagation = 0.5;
target_community = 1;
eta = 0.01; epsilon_conv = 0.1; max_iterations = 100; run_num = 2000;

filePath = 'ml-100k/u.data';
data = readmatrix(filePath, 'FileType', 'text');
item_file_path = 'ml-100k/u.item';
theta_sigmoid = 10.0; beta_fuse = 0.6;

%% 加载完整的150用户固定位置数据
pos_data = load('matlab.mat', 'sbs_positions', 'per_user_positions', 'now_user_positions', 'user_community');
sbs_positions_full      = pos_data.sbs_positions;       % 3×2
per_user_positions_full = pos_data.per_user_positions;   % 150×2×100
now_user_positions_full = pos_data.now_user_positions;   % 150×2×100
user_community_full     = pos_data.user_community;       % 150×1
user_per_community_full = 50;  % mat中每社区固定50人

%% 主计算循环
qoe_algorithm_number = zeros(7, 10);
hit_rate_algorithm_number = zeros(7, 10);
wait_time_algorithm_number = zeros(7, 10);

for number = 1:10
    fprintf('处理参数 %d/10...\n', number);

    user_per_community = 5 * number;  % 5,10,15,...,50
    total_users = h * user_per_community;
    iu_count_per_community = round(user_per_community * Per_m);

    % ===== 从完整数据中提取前N个用户并重新打包 =====
    % 原始索引: 社区m的用户为 (m-1)*50+1 : (m-1)*50+N
    % 新索引:   社区m的用户为 (m-1)*N+1  : m*N
    extract_idx = [];
    for m = 1:h
        orig_start = (m-1) * user_per_community_full + 1;
        orig_end   = orig_start + user_per_community - 1;
        extract_idx = [extract_idx, orig_start:orig_end];
    end

    per_user_positions  = per_user_positions_full(extract_idx, :, :);
    now_user_positions  = now_user_positions_full(extract_idx, :, :);
    sbs_positions       = sbs_positions_full;

    user_community = zeros(total_users, 1);
    for m = 1:h
        user_community((m-1)*user_per_community+1 : m*user_per_community) = m;
    end

    for algorithm_num = 1:7
        fprintf('  算法 %d/7...\n', algorithm_num);
        qoe_results = zeros(run_num, 1);
        hit_results = zeros(run_num, 1);
        wait_results = zeros(run_num, 1);

        parfor run_now = 1:run_num
            try
                switch algorithm_num
                    case 1
                        [final_alltime_qoe,cache_hit_rate,initial_wait_time] = algorithm_MOIS( ...
            h, user_per_community, total_users, F, iu_count_per_community, ...
            nf, chi, Delta_t, v_chi_star, region_size, sbs_coverage, iu_coverage, ...
            community_radius, max_movement_dist, D_eg, D_iu, T_small, gamma_m, ...
            alpha, beta, gamma, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, ...
            alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, ...
            t_cloud, t_propagation, target_community, eta, epsilon_conv, ...
            max_iterations, data, item_file_path, theta_sigmoid, beta_fuse, ...
            sbs_positions, per_user_positions, now_user_positions, user_community);
                    case 2
                        [final_alltime_qoe,cache_hit_rate,initial_wait_time] = algorithm_random_iu( ...
            h, user_per_community, total_users, F, iu_count_per_community, ...
            nf, chi, Delta_t, v_chi_star, region_size, sbs_coverage, iu_coverage, ...
            community_radius, max_movement_dist, D_eg, D_iu, T_small, gamma_m, ...
            alpha, beta, gamma, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, ...
            alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, ...
            t_cloud, t_propagation, target_community, eta, epsilon_conv, ...
            max_iterations, data, item_file_path, theta_sigmoid, beta_fuse, ...
            sbs_positions, per_user_positions, now_user_positions, user_community);
                    case 3
                        [final_alltime_qoe,cache_hit_rate,initial_wait_time] = algorithm_LMPC( ...
            h, user_per_community, total_users, F, iu_count_per_community, ...
            nf, chi, Delta_t, v_chi_star, region_size, sbs_coverage, iu_coverage, ...
            community_radius, max_movement_dist, D_eg, D_iu, T_small, gamma_m, ...
            alpha, beta, gamma, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, ...
            alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, ...
            t_cloud, t_propagation, target_community, eta, epsilon_conv, ...
            max_iterations, data, item_file_path, theta_sigmoid, beta_fuse, ...
            sbs_positions, per_user_positions, now_user_positions, user_community);
                    case 4
                        [final_alltime_qoe,cache_hit_rate,initial_wait_time] = algorithm_RAC( ...
            h, user_per_community, total_users, F, iu_count_per_community, ...
            nf, chi, Delta_t, v_chi_star, region_size, sbs_coverage, iu_coverage, ...
            community_radius, max_movement_dist, D_eg, D_iu, T_small, gamma_m, ...
            alpha, beta, gamma, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, ...
            alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, ...
            t_cloud, t_propagation, target_community, eta, epsilon_conv, ...
            max_iterations, data, item_file_path, theta_sigmoid, beta_fuse, ...
            sbs_positions, per_user_positions, now_user_positions, user_community);
                    case 5
                        [final_alltime_qoe,cache_hit_rate,initial_wait_time] = algorithm_HC( ...
            h, user_per_community, total_users, F, iu_count_per_community, ...
            nf, chi, Delta_t, v_chi_star, region_size, sbs_coverage, iu_coverage, ...
            community_radius, max_movement_dist, D_eg, D_iu, T_small, gamma_m, ...
            alpha, beta, gamma, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, ...
            alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, ...
            t_cloud, t_propagation, target_community, eta, epsilon_conv, ...
            max_iterations, data, item_file_path, theta_sigmoid, beta_fuse, ...
            sbs_positions, per_user_positions, now_user_positions, user_community);
                    case 6
                        [final_alltime_qoe,cache_hit_rate,initial_wait_time] = algorithm_GMPC( ...
            h, user_per_community, total_users, F, iu_count_per_community, ...
            nf, chi, Delta_t, v_chi_star, region_size, sbs_coverage, iu_coverage, ...
            community_radius, max_movement_dist, D_eg, D_iu, T_small, gamma_m, ...
            alpha, beta, gamma, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, ...
            alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, ...
            t_cloud, t_propagation, target_community, eta, epsilon_conv, ...
            max_iterations, data, item_file_path, theta_sigmoid, beta_fuse, ...
            sbs_positions, per_user_positions, now_user_positions, user_community);
                    case 7
                        [final_alltime_qoe,cache_hit_rate,initial_wait_time] = algorithm_NCC( ...
            h, user_per_community, total_users, F, iu_count_per_community, ...
            nf, chi, Delta_t, v_chi_star, region_size, sbs_coverage, iu_coverage, ...
            community_radius, max_movement_dist, D_eg, D_iu, T_small, gamma_m, ...
            alpha, beta, gamma, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, ...
            alpha_qoe, beta_qoe, gamma_qoe, delta_qoe, p_sbs, p_iu, D_bf, ...
            t_cloud, t_propagation, target_community, eta, epsilon_conv, ...
            max_iterations, data, item_file_path, theta_sigmoid, beta_fuse, ...
            sbs_positions, per_user_positions, now_user_positions, user_community);
                end
                qoe_results(run_now) = final_alltime_qoe;
                hit_results(run_now) = cache_hit_rate;
                wait_results(run_now) = initial_wait_time;
            catch ME
                warning('运行 %d 出错: %s', run_now, ME.message);
                qoe_results(run_now) = 0; hit_results(run_now) = 0; wait_results(run_now) = 0;
            end
        end

        qoe_algorithm_number(algorithm_num, number) = mean(qoe_results);
        hit_rate_algorithm_number(algorithm_num, number) = mean(hit_results);
        wait_time_algorithm_number(algorithm_num, number) = mean(wait_results);
        fprintf('    算法 %d 完成, 平均QoE: %.4f\n', algorithm_num, qoe_algorithm_number(algorithm_num, number));
    end
end

%% 绘制结果
x_data = (1:10)*5;
figure('Position', [100, 100, 800, 600]);
plot(x_data, qoe_algorithm_number(1,:), '-o', 'LineWidth', 3); hold on;
plot(x_data, qoe_algorithm_number(2,:), '-*', 'LineWidth', 3);
plot(x_data, qoe_algorithm_number(3,:), '-x', 'LineWidth', 3);
plot(x_data, qoe_algorithm_number(4,:), '-square', 'LineWidth', 3);
plot(x_data, qoe_algorithm_number(5,:), '-diamond', 'LineWidth', 3);
plot(x_data, qoe_algorithm_number(6,:), '-v', 'LineWidth', 3);
plot(x_data, qoe_algorithm_number(7,:), '-^', 'LineWidth', 3);
xlim([x_data(1), x_data(end)]); xticks(x_data);
xlabel('Number of users per community','FontSize', 18);
ylabel('QoE','FontSize', 18);
lgd = legend('Proposed', 'Random-IU', 'LMPC', 'RAC', 'HC', 'GMPC', 'NCC', 'Location', 'best');
lgd.FontSize = 12; grid on;
saveas(gcf,'Figure/Users_Percom.fig');
toc;