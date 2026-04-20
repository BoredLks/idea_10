function user_file_req_prob = cal_user_file_req_prob(total_users, F, gamma_m, data, sg_edge_weights)
%% 加载Movielens计算用户偏好相似度
% 提取字段
user_ids = data(:, 1);
movie_ids = data(:, 2);
ratings   = data(:, 3);

% 获取用户数和电影数
num_users = max(user_ids);
num_movies = max(movie_ids);

% 构建评分矩阵 R(user, movie)
R = zeros(num_users, num_movies);
for i = 1:length(ratings)
    R(user_ids(i), movie_ids(i)) = ratings(i);
end

%% 生成用户的文件请求概率（基于Movielens数据的个性化兴趣）
user_file_req_prob_zipf = zeros(total_users, F);

% 为每个系统用户分配一个Movielens用户ID
% 如果系统用户数多于Movielens用户数，会有重复映射
user_movielens_mapping = mod(0:total_users-1, num_users) + 1;

% 为每个系统文件分配一个Movielens电影ID  
% 如果系统文件数多于Movielens电影数，会有重复映射
file_movielens_mapping = mod(0:F-1, num_movies) + 1;

for u = 1:total_users
    % 获取对应的Movielens用户ID
    movielens_user_id = user_movielens_mapping(u);

    % 获取该用户的所有评分数据
    user_ratings = R(movielens_user_id, :);

    % 创建文件排序数组
    file_scores = zeros(F, 1);

    for k = 1:F
        % 获取对应的Movielens电影ID
        movielens_movie_id = file_movielens_mapping(k);

        % 获取用户对该电影的评分
        rating = user_ratings(movielens_movie_id);

        if rating > 0
            % 如果用户评过分，使用评分作为兴趣分数
            file_scores(k) = rating;
        else
            % 如果用户没评过分，使用该电影的平均评分作为估计
            movie_ratings = R(:, movielens_movie_id);
            movie_ratings = movie_ratings(movie_ratings > 0); % 只考虑非零评分

            if ~isempty(movie_ratings)
                file_scores(k) = mean(movie_ratings);
            else
                % 如果该电影完全没有评分，使用全局平均评分
                all_ratings = R(R > 0);
                if ~isempty(all_ratings)
                    file_scores(k) = mean(all_ratings);
                else
                    file_scores(k) = 2.5; % 默认中等评分
                end
            end

            % 为未评分的电影添加一些随机性，避免所有未评分电影排序完全相同
            file_scores(k) = file_scores(k) + 0.1 * randn(); % 添加小的随机噪声
        end
    end

    % 根据分数对文件进行排序（分数越高，排名越靠前）
    [~, sorted_indices] = sort(file_scores, 'descend');

    % 创建排名映射：phi_k_ui(k) 表示文件k的排名
    phi_k_ui = zeros(F, 1);
    for rank = 1:F
        file_id = sorted_indices(rank);
        phi_k_ui(rank) = file_id;
    end

    % 计算Zipf分布的分母
    zipf_denominator = sum((1:F).^(-gamma_m));

    % 对每个文件计算请求概率
    for k = 1:F
        rank_of_file = find(phi_k_ui == k);
        user_file_req_prob_zipf(u, k) = (rank_of_file^(-gamma_m)) / zipf_denominator;
    end
end

%% 用社交图平滑用户请求概率（Zipf + SG）
social_iter_max = 100;
social_blend = 0.35;
social_iter_tol = 1e-8;
% 目标：sg_edge_weights越高，用户请求分布越相似
W_social = sg_edge_weights(1:total_users, 1:total_users);
W_social(W_social < 0) = 0;

% 行归一化，得到社交影响矩阵
row_sum = sum(W_social, 2);
row_sum(row_sum == 0) = 1;
W_social_norm = W_social ./ row_sum;

% 固定点迭代：P^{t+1} = (1-social_blend)P_zipf + social_blend*W*P^t
P_zipf = user_file_req_prob_zipf;
P_social = P_zipf;

for iter = 1:social_iter_max
    P_next = (1 - social_blend) * P_zipf + social_blend * (W_social_norm * P_social);

    % 概率合法化：非负 + 每行和为1
    P_next(P_next < 0) = 0;
    p_row_sum = sum(P_next, 2);
    p_row_sum(p_row_sum == 0) = 1;
    P_next = P_next ./ p_row_sum;

    if norm(P_next - P_social, 'fro') < social_iter_tol
        P_social = P_next;
        break;
    end
    P_social = P_next;
end

% 最终请求概率：融合后的社交感知请求概率
user_file_req_prob = P_social;



end

