function sim_matrix = cal_Movielens(data)
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

% 归一化评分向量
R_norm = R ./ sqrt(sum(R.^2, 2));  % 每行（用户）单位向量

% 计算余弦相似度（用户 × 用户）
sim_matrix = R_norm * R_norm';  % 用户间兴趣相似度矩阵



end