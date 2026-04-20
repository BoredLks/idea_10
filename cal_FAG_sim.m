function FAG_sim = cal_FAG_sim(F, num_movies, num_genres, genre_matrix_ml, release_years_ml, file_movielens_mapping)
%% 构建FAG文件属性图 (公式15-17)

% 将系统文件映射到MovieLens电影的属性
file_genre_matrix = zeros(F, num_genres);
file_release_decade = zeros(F, 1);

for k = 1:F
    ml_id = file_movielens_mapping(k);
    if ml_id <= size(genre_matrix_ml, 1)
        file_genre_matrix(k, :) = genre_matrix_ml(ml_id, :);
    end
    if ml_id <= length(release_years_ml) && release_years_ml(ml_id) > 0
        file_release_decade(k) = floor(release_years_ml(ml_id) / 10) * 10;
    end
end

% 公式(17): 属性权重 omega_k = Count(k) / sum(Count(r))
A_total = num_genres + 1;
Count_attr = zeros(A_total, 1);

for g = 1:num_genres
    Count_attr(g) = sum(file_genre_matrix(:, g));
end
valid_decades = file_release_decade(file_release_decade > 0);
if ~isempty(valid_decades)
    [~, ~, ic] = unique(valid_decades);
    Count_attr(A_total) = max(accumarray(ic, 1));
else
    Count_attr(A_total) = 1;
end

sum_Count = sum(Count_attr);
if sum_Count > 0
    omega_attr = Count_attr / sum_Count;
else
    omega_attr = ones(A_total, 1) / A_total;
end

% 公式(15)(16): FAG边权重 e^fg_{fi,fj}
FAG_sim = zeros(F, F);
for fi = 1:F
    for fj = fi+1:F
        weight = 0;

        % Genre属性匹配
        for g = 1:num_genres
            if file_genre_matrix(fi, g) == 1 && file_genre_matrix(fj, g) == 1
                weight = weight + omega_attr(g);
            end
        end

        % 年代属性匹配
        if file_release_decade(fi) > 0 && file_release_decade(fj) > 0 && ...
           file_release_decade(fi) == file_release_decade(fj)
            weight = weight + omega_attr(A_total);
        end

        FAG_sim(fi, fj) = weight;
        FAG_sim(fj, fi) = weight;
    end
end

end
