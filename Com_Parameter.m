clc;
close all;
clear;

tic;

%% 参数设置
h = 3;                     % 社区数量
user_per_community = 50;   % 每个社区的用户数量
total_users = h * user_per_community;
F = 200;                    % 视频资源数量
Per_m = 0.3;               % 每个社区选作缓存节点的用户比例
iu_count_per_community = round(user_per_community * Per_m);
nf = 100;                    % 每个视频的片段数
chi = [1.5 , 2 , 5 , 10 , 12]; % 分辨率级别，单位:Mbps（bit）
chi_star = chi(end);       % 最高分辨率编码比特率
Delta_t = 1;               % 视频片段时长，单位:秒
v_chi_star = chi_star * Delta_t / 8; % 最高分辨率视频片段大小，单位:MB（Byte)

% 区域和距离参数
region_size = 1500;        % 正方形区域边长，单位:米
sbs_coverage = 150;        % SBS覆盖半径，单位:米
iu_coverage = 50;          % IU D2D覆盖半径，单位:米
community_radius = 150;    % 社区半径，单位:米
max_movement_dist = 2;    % 相邻时间点之间的最大移动距离

% 时间参数
T_small = 100;              % 小时间尺度数量
T_large = 1;               % 大时间尺度数量

% Zipf参数
gamma_m = 0.9;             % Zipf分布参数：越接近1，最热门的视频被请求概率越大

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

% 验证权重和为1
if abs(alpha_qoe + beta_qoe + gamma_qoe + delta_qoe - 1) > 1e-6
    error('QoE权重参数之和必须为1');
end

%% 缓存容量
D_eg = 30 * nf * v_chi_star; % SBS缓存容量
D_iu = 10 * nf * v_chi_star; % IU缓存容量

%% 转码和缓冲参数
p_sbs = 100;     % SBS计算资源，单位: Mbit/s
p_iu = 10;      % IU计算资源，单位: Mbit/s
D_bf = 10;     % 播放缓冲区最大容量，单位: Mbit
t_cloud = 2;      % 云到SBS回程时间，单位: s
t_propagation = 0.5; % SBS间传播时间，单位: s

%% 选择要优化的社区和时隙
target_community = 1;        % 选择第1个社区进行优化

fprintf('优化目标: 社区%d\n', target_community);

%% 算法参数
eta = 0.01;         % 步长
epsilon_conv = 0.1; % 收敛阈值
max_iterations = 100; %最大次数
run_num = 2000;  % 求QoE平均值循环次数

%% 加载Movielens计算用户偏好相似度
% 设置文件路径
filePath = 'ml-100k/u.data';
% 读取评分数据
data = readmatrix(filePath, 'FileType', 'text');

item_file_path = 'ml-100k/u.item';    % MovieLens u.item 文件路径
theta_sigmoid  = 10.0;                 % Sigmoid陡峭度参数 (公式42)
beta_fuse      = 0.6;                  % pSPAG与pF的融合权重 (公式42)

%% 加载固定位置数据
pos_data = load('matlab.mat', 'sbs_positions', 'per_user_positions', 'now_user_positions', 'user_community');
sbs_positions      = pos_data.sbs_positions;
per_user_positions  = pos_data.per_user_positions;
now_user_positions  = pos_data.now_user_positions;
user_community      = pos_data.user_community;

%% 主计算循环
qoe_algorithm_number = zeros(7, 10);
hit_rate_algorithm_number = zeros(7, 10);
wait_time_algorithm_number = zeros(7, 10);
for number = 1:10
    fprintf('处理参数 %d/10...\n', number);
    K = 0.2+0.1*number;

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

x_data = (1:10)*0.1;

figure('Position', [100, 100, 800, 600]);
plot(x_data, qoe_algorithm_number(1,:), '-o', 'LineWidth', 3); hold on;
plot(x_data, qoe_algorithm_number(2,:), '-*', 'LineWidth', 3);
plot(x_data, qoe_algorithm_number(3,:), '-x', 'LineWidth', 3);
plot(x_data, qoe_algorithm_number(4,:), '-square', 'LineWidth', 3);
plot(x_data, qoe_algorithm_number(5,:), '-diamond', 'LineWidth', 3);
plot(x_data, qoe_algorithm_number(6,:), '-v', 'LineWidth', 3);
plot(x_data, qoe_algorithm_number(7,:), '-^', 'LineWidth', 3);
xlim([x_data(1), x_data(end)]); xticks(x_data);
xlabel('Communication Parameter K','FontSize', 18);
ylabel('QoE','FontSize', 18);
lgd = legend('Proposed', 'Random-IU', 'LMPC', 'RAC', 'HC', 'GMPC', 'NCC', 'Location', 'best');
lgd.FontSize = 12; grid on;
saveas(gcf,'Figure/Com_Parameter.fig');
toc;
