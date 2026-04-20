function [genre_matrix_ml, release_years_ml, num_genres] = cal_load_item_data(item_file_path, num_movies)
%% 加载u.item电影属性数据 (用于FAG)

num_genres = 19;

fid_item = fopen(item_file_path, 'r', 'n', 'ISO-8859-1');
if fid_item == -1
    warning('无法打开u.item, 使用随机属性替代.');
    genre_matrix_ml = randi([0,1], num_movies, num_genres);
    release_years_ml = randi([1920,1998], num_movies, 1);
else
    item_raw = textscan(fid_item, ...
        '%d%s%s%s%s%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d', ...
        'Delimiter', '|', 'EndOfLine', '\n');
    fclose(fid_item);

    genre_matrix_ml = zeros(num_movies, num_genres);
    num_items_loaded = length(item_raw{1});
    for g = 1:num_genres
        genre_col = double(item_raw{5 + g});
        genre_matrix_ml(1:min(num_items_loaded, num_movies), g) = ...
            genre_col(1:min(num_items_loaded, num_movies));
    end

    release_years_ml = zeros(num_movies, 1);
    date_strs = item_raw{3};
    for i = 1:min(num_items_loaded, num_movies)
        ds = date_strs{i};
        if ~isempty(ds)
            parts = strsplit(ds, '-');
            if length(parts) >= 3
                yr = str2double(parts{3});
                if ~isnan(yr)
                    release_years_ml(i) = yr;
                end
            end
        end
    end
end

end
