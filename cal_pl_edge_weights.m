function pl_edge_weights = cal_pl_edge_weights(h, total_users, iu_count_per_community, sbs_coverage, iu_coverage, T_small, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, sbs_positions, user_positions, iu_indices, iu_flags)
% function pl_edge_weights = cal_pl_edge_weights(h, total_users, sbs_coverage, iu_coverage, T_small, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, sbs_positions, user_positions, iu_flags)
% %% 构建物理连接图
% pl_edge_weights = zeros(total_users + h, total_users + h);
% R_max = B * log2(1 + (P_sbs * K * 1 * 1) / N0); % 计算最大理论速率
% 
% % 计算用户间的物理连接
% for i = 1:total_users
% 
%     % 判断用户i是否为IU
%     if iu_flags(i) == 1
%         % IU的自环边权重为1
%         pl_edge_weights(i, i) = 1;
%     else
%         % 普通用户的自环边权重为0
%         pl_edge_weights(i, i) = 0;
%     end
% 
%     % 计算用户i与其他用户j的D2D边权重
%     for j = i+1:total_users  % 只计算上三角，避免重复计算
%         % 检查是否至少有一个是IU
%         if iu_flags(i) == 1 || iu_flags(j) == 1
%             % 至少有一个是IU，计算D2D连接可能性
% 
%             % 对每个小时隙计算瞬时速率，然后求平均
%             total_rate = 0;
%             valid_slots = 0;
% 
%             for t = 1:T_small
%                 % 计算用户在时隙t的相互距离
%                 dist_t = sqrt(sum((user_positions(i, :, t) - user_positions(j, :, t)).^2));
% 
%                 % 检查是否在D2D覆盖范围内
%                 if dist_t <= iu_coverage
%                     % 慢衰落（阴影衰落）
%                     slowfading_sd = slowfading_dB / (10 * log10(exp(1)));% 将 dB 转换为对数后的标准差
%                     slowfading_avg = -slowfading_sd^2 / 2;% 假设均值为 0 dB，则对数后的均值为 mu = -sigma^2 / 2
%                     vartheta = lognrnd(slowfading_avg, slowfading_sd);% 慢衰落增益
% 
%                     % 小尺度衰落（瑞利衰落）
%                     re_real = randn();
%                     re_imag = randn();
%                     re = sqrt(re_real + 1i * re_imag);
%                     xi = abs(re) ^ 2;
% 
%                     % 总信道增益
%                     channel_gain = K * vartheta * xi * dist_t^(-epsilon);
% 
%                     % 计算干扰：来自其他IU的干扰
%                     interference = 0;
%                     for k = 1:total_users
%                         if k ~= i && k ~= j && iu_flags(k) == 1 % 其他IU
%                             % 计算干扰IU k到接收用户j的距离
%                             dist_interferer = sqrt(sum((user_positions(k, :, t) - user_positions(j, :, t)).^2));
% 
%                             % 如果干扰IU在传输范围内，计算干扰
%                             if dist_interferer <= iu_coverage
%                                 % 慢衰落
%                                 vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
%                                 % 小尺度衰落
%                                 re_real_int = randn();
%                                 re_imag_int = randn();
%                                 re_int = sqrt(re_real_int + 1i * re_imag_int);
%                                 xi_int = abs(re_int) ^ 2;
% 
%                                 % 干扰信道增益
%                                 interference_gain = K * vartheta_int * xi_int * dist_interferer^(-epsilon);
%                                 interference = interference + P_iu * interference_gain;
%                             end
%                         end
%                     end
% 
%                     % 使用Shannon公式计算瞬时D2D速率
%                     R_instantaneous = B * log2(1 + (P_iu * channel_gain) / N0 + interference);
% 
%                     % 累加有效的瞬时速率
%                     total_rate = total_rate + R_instantaneous;
%                     valid_slots = valid_slots + 1;
%                 end
%             end
% 
%             % 计算平均速率并设置边权重
%             if valid_slots > 0
%                 % 计算所有有效时隙的平均速率
%                 avg_rate = total_rate / valid_slots;
% 
%                 % 归一化到[0,1]范围，设置对称边权重
%                 pl_edge_weights(i, j) = avg_rate / R_max;
%                 pl_edge_weights(j, i) = avg_rate / R_max;
%             else
%                 % 如果没有有效时隙
%                 pl_edge_weights(i, j) = 0;
%                 pl_edge_weights(j, i) = 0;
%             end
%         else
%             % 都不是IU，无法进行D2D通信
%             pl_edge_weights(i, j) = 0;
%             pl_edge_weights(j, i) = 0;
%         end
%     end
% 
%     % 计算用户与SBS之间的边权重
%     for m = 1:h
%         sbs_idx = total_users + m;
% 
%         % 对每个小时隙计算瞬时速率，然后求平均
%         total_rate = 0;
%         valid_slots = 0;
% 
%         for t = 1:T_small
%             % 计算用户在时隙t的位置到SBS的距离
%             dist_t = sqrt(sum((user_positions(i, :, t) - sbs_positions(m, :)).^2));
% 
%             % 检查用户是否在SBS覆盖范围内
%             if dist_t <= sbs_coverage
%                 % 慢衰落（阴影衰落）
%                 slowfading_sd = slowfading_dB / (10 * log10(exp(1)));% 将 dB 转换为对数后的标准差
%                 slowfading_avg = -slowfading_sd^2 / 2;% 假设均值为 0 dB，则对数后的均值为 mu = -sigma^2 / 2
%                 vartheta = lognrnd(slowfading_avg, slowfading_sd);% 慢衰落增益
% 
%                 % 小尺度衰落（瑞利衰落）
%                 re_real = randn();
%                 re_imag = randn();
%                 re = sqrt(re_real + 1i * re_imag);
%                 xi = abs(re) ^ 2;
% 
%                 % 总信道增益
%                 channel_gain = K * vartheta * xi * dist_t^(-epsilon);
% 
%                 % 计算干扰：来自其他SBS的干扰
%                 interference = 0;
%                 for n = 1:h
%                     if n ~= m  % 其他SBS
%                         % 计算其他SBS n到用户i的距离
%                         dist_interferer_sbs = sqrt(sum((user_positions(i, :, t) - sbs_positions(n, :)).^2));
% 
%                         % 如果其他SBS在用户的接收范围内（可能造成干扰）%if dist_interferer_sbs <= sbs_coverage %end
% 
%                             % 慢衰落
%                             vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
%                             % 小尺度衰落
%                             re_real_int = randn();
%                             re_imag_int = randn();
%                             re_int = sqrt(re_real_int + 1i * re_imag_int);
%                             xi_int = abs(re_int) ^ 2;
% 
%                             % 干扰信道增益
%                             interference_gain = K * vartheta_int * xi_int * dist_interferer_sbs^(-epsilon);
%                             interference = interference + P_sbs * interference_gain;
% 
%                     end
%                 end
% 
%                 % 使用Shannon公式计算瞬时速率
%                 R_instantaneous = B * log2(1 + (P_sbs * channel_gain) / N0 + interference);
% 
%                 % 累加有效的瞬时速率
%                 total_rate = total_rate + R_instantaneous;
%                 valid_slots = valid_slots + 1;
%             end
%         end
% 
%         % 计算平均速率并设置边权重
%         if valid_slots > 0
%             % 计算所有有效时隙的平均速率
%             avg_rate = total_rate / valid_slots;
% 
%             % 归一化到[0,1]范围，设置双向边权重
%             pl_edge_weights(i, sbs_idx) = avg_rate / R_max;
%             pl_edge_weights(sbs_idx, i) = avg_rate / R_max;
%         else
%             % 如果没有有效时隙
%             pl_edge_weights(i, sbs_idx) = 0;
%             pl_edge_weights(sbs_idx, i) = 0;
%         end
%     end
% end
% 
% % SBS间以及SBS的自环边权重设置
% for m = 1:h
%     sbs_idx = total_users + m;
%     % SBS的自环边权重为1
%     pl_edge_weights(sbs_idx, sbs_idx) = 1;
% 
%     % SBS间不直接连接
%     for n = m+1:h  % 只计算上三角，避免重复
%         other_sbs_idx = total_users + n;
%         pl_edge_weights(sbs_idx, other_sbs_idx) = 0;
%         pl_edge_weights(other_sbs_idx, sbs_idx) = 0;
%     end
% end






% pl_edge_weights = zeros(total_users + h, total_users + h);
% R_max = B * log2(1 + (P_sbs * K * 1 * 1) / N0); % 计算最大理论速率
% 
% for m = 1:h
%     sbs_idx = total_users + m;
% 
%     % 计算用户i与其他用户间的物理连接
%     for i = (m - 1) * (total_users/h) + 1 :m * (total_users/h)
%         % 判断用户i是否为IU
%         if iu_flags(i) == 1
%             % IU的自环边权重为1
%             pl_edge_weights(i, i) = 1;  % 权重归一化为1 (R_max/R_max)
%         else
%             % 普通用户的自环边权重为0
%             pl_edge_weights(i, i) = 0;  % 普通用户不能给自己提供服务
%         end
% 
%         for j = i + 1 :m * (total_users/h)  % 只计算上三角，避免重复计算
%             % 检查是否至少有一个是IU
%             if iu_flags(i) == 1 || iu_flags(j) == 1
% 
%                 % 对每个小时隙计算瞬时速率，然后求平均
%                 total_rate = 0;
%                 valid_slots = 0;
% 
%                 for t = 1:T_small
%                     % 计算用户在时隙t的相互距离
%                     dist_t = sqrt(sum((user_positions(i, :, t) - user_positions(j, :, t)).^2));
% 
%                     % 检查是否在D2D覆盖范围内
%                     if dist_t <= iu_coverage
%                         % 慢衰落（阴影衰落）
%                         slowfading_sd = slowfading_dB / (10 * log10(exp(1)));% 将 dB 转换为对数后的标准差
%                         slowfading_avg = -slowfading_sd^2 / 2;% 假设均值为 0 dB，则对数后的均值为 mu = -sigma^2 / 2
%                         vartheta = lognrnd(slowfading_avg, slowfading_sd);% 慢衰落增益
% 
%                         % 小尺度衰落（瑞利衰落）- 生成复高斯随机变量
%                         re_real = randn(); % 实部
%                         re_imag = randn(); % 虚部
%                         re = sqrt(re_real + 1i * re_imag); % 复高斯随机变量
%                         xi = abs(re) ^ 2; % 瑞利衰落的幅度
% 
%                         % 信道增益（不包括干扰）
%                         channel_gain = K * vartheta * xi * dist_t^(-epsilon);
% 
%                         % 计算干扰：来自其他IU的干扰
%                         interference = 0;
%                         for k = 1:iu_count_per_community
%                             other_iu_idx = iu_indices(m, k);
% 
%                             if other_iu_idx ~= i && other_iu_idx ~= j % 其他IU
%                                 % 计算干扰IU k到接收用户j的距离
%                                 dist_interferer = sqrt(sum((user_positions(other_iu_idx, :, t) - user_positions(j, :, t)).^2));
% 
%                                 % 如果干扰IU在传输范围内，计算干扰
%                                 if dist_interferer <= iu_coverage
%                                     % 慢衰落
%                                     vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
%                                     % 小尺度衰落
%                                     re_real_int = randn();
%                                     re_imag_int = randn();
%                                     re_int = sqrt(re_real_int + 1i * re_imag_int);
%                                     xi_int = abs(re_int) ^ 2;
% 
%                                     % 干扰信道增益
%                                     interference_gain = K * vartheta_int * xi_int * dist_interferer^(-epsilon);
%                                     interference = interference + P_iu * interference_gain;
%                                 end
%                             end
%                         end
% 
%                         % 使用Shannon公式计算瞬时D2D速率（包含干扰）
%                         R_instantaneous = B * log2(1 + (P_iu * channel_gain) / (N0 + interference));
% 
%                         % 累加有效的瞬时速率
%                         total_rate = total_rate + R_instantaneous;
%                         valid_slots = valid_slots + 1;
%                     end
%                 end
%                 % 计算平均速率并设置边权重
%                 if valid_slots > 0
%                     % 计算所有有效时隙的平均速率
%                     avg_rate = total_rate / valid_slots;
%                     % 归一化到[0,1]范围，设置对称边权重
%                     pl_edge_weights(i, j) = avg_rate / R_max;
%                     pl_edge_weights(j, i) = avg_rate / R_max;  % 确保对称性
%                 else
%                     % 如果没有有效时隙（用户间始终不在D2D覆盖范围内）
%                     pl_edge_weights(i, j) = 0;
%                     pl_edge_weights(j, i) = 0;
%                 end
%             else
%                 % 都不是IU，无法进行D2D通信
%                 pl_edge_weights(i, j) = 0;
%                 pl_edge_weights(j, i) = 0;
%             end
%         end
% 
% 
%         % 计算用户i与SBS的物理连接
%         total_rate = 0;
%         valid_slots = 0;
% 
%         for t = 1:T_small
%             % 计算用户在时隙t的位置到SBS的距离
%             dist_t = sqrt(sum((user_positions(i, :, t) - sbs_positions(m, :)).^2));
% 
%             % 检查用户是否在SBS覆盖范围内
%             if dist_t <= sbs_coverage
%                 % 慢衰落（阴影衰落）
%                 slowfading_sd = slowfading_dB / (10 * log10(exp(1)));% 将 dB 转换为对数后的标准差
%                 slowfading_avg = -slowfading_sd^2 / 2;% 假设均值为 0 dB，则对数后的均值为 mu = -sigma^2 / 2
%                 vartheta = lognrnd(slowfading_avg, slowfading_sd);% 慢衰落增益
% 
%                 % 小尺度衰落（瑞利衰落）
%                 re_real = randn();
%                 re_imag = randn();
%                 re = sqrt(re_real + 1i * re_imag);
%                 xi = abs(re) ^ 2;
% 
%                 % 信道增益（不包括干扰）
%                 channel_gain = K * vartheta * xi * dist_t^(-epsilon);
% 
%                 % 计算干扰：来自其他SBS的干扰
%                 interference = 0;
%                 for n = 1:h
%                     if n ~= m  % 其他SBS
%                         % 计算其他SBS n到用户i的距离
%                         dist_interferer_sbs = sqrt(sum((user_positions(i, :, t) - sbs_positions(n, :)).^2));
% 
%                         % 如果其他SBS在用户的接收范围内（可能造成干扰）%if dist_interferer_sbs <= sbs_coverage %end
% 
%                         % 慢衰落
%                         vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
%                         % 小尺度衰落
%                         re_real_int = randn();
%                         re_imag_int = randn();
%                         re_int = sqrt(re_real_int + 1i * re_imag_int);
%                         xi_int = abs(re_int) ^ 2;
% 
%                         % 干扰信道增益
%                         interference_gain = K * vartheta_int * xi_int * dist_interferer_sbs^(-epsilon);
%                         interference = interference + P_sbs * interference_gain;
% 
%                     end
%                 end
% 
%                 % 使用Shannon公式计算瞬时速率（包含干扰）
%                 R_instantaneous = B * log2(1 + (P_sbs * channel_gain) / (N0 + interference));
% 
%                 % 累加有效的瞬时速率
%                 total_rate = total_rate + R_instantaneous;
%                 valid_slots = valid_slots + 1;
%             end
%         end
%         % 计算平均速率并设置边权重
%         if valid_slots > 0
%             % 计算所有有效时隙的平均速率
%             avg_rate = total_rate / valid_slots;
%             % 归一化到[0,1]范围，设置双向边权重
%             pl_edge_weights(i, sbs_idx) = avg_rate / R_max;
%             pl_edge_weights(sbs_idx, i) = avg_rate / R_max;
%         else
%             % 如果没有有效时隙（用户始终不在覆盖范围内）
%             pl_edge_weights(i, sbs_idx) = 0;
%             pl_edge_weights(sbs_idx, i) = 0;
%         end
%     end
% 
%     % 计算SBS的自环边权重为1
%     pl_edge_weights(sbs_idx, sbs_idx) = 1;
%     % SBS间不直接连接
%     for n = m+1:h  % 只计算上三角，避免重复
%         other_sbs_idx = total_users + n;
%         pl_edge_weights(sbs_idx, other_sbs_idx) = 0;
%         pl_edge_weights(other_sbs_idx, sbs_idx) = 0;
%     end
% end



%% 构建物理连接图
pl_edge_weights = zeros(total_users + h, total_users + h);
% 定义两个最大速率：分别用于 SBS 和 D2D 归一化
R_max_sbs = 0;
R_max_iu  = 0;

for m = 1:h
    sbs_idx = total_users + m;

    % 计算用户i与其他用户间的物理连接
    for i = (m - 1) * (total_users / h) + 1 :m * (total_users / h)
        % 判断用户i是否为IU
        if iu_flags(i) == 1
            % IU的自环边权重为1
            pl_edge_weights(i, i) = 1;  % 权重归一化为1 (R_max_iu/R_max_iu)
        else
            % 普通用户的自环边权重为0
            pl_edge_weights(i, i) = 0;  % 普通用户不能给自己提供服务
        end

        for j = i + 1 :m * (total_users / h)  % 只计算上三角，避免重复计算
            % 检查是否至少有一个是IU
            if iu_flags(i) == 1 || iu_flags(j) == 1

                % 对每个小时隙计算瞬时速率，然后求平均
                total_rate = 0;
                valid_slots = 0;

                for t = 1:T_small
                    % 计算用户在时隙t的相互距离
                    dist_t = sqrt(sum((user_positions(i, :, t) - user_positions(j, :, t)).^2));

                    % 检查是否在D2D覆盖范围内
                    if dist_t <= iu_coverage
                        % 慢衰落（阴影衰落）
                        slowfading_sd = slowfading_dB / (10 * log10(exp(1)));% 将 dB 转换为对数后的标准差
                        slowfading_avg = -slowfading_sd^2 / 2;% 假设均值为 0 dB，则对数后的均值为 mu = -sigma^2 / 2
                        vartheta = lognrnd(slowfading_avg, slowfading_sd);% 慢衰落增益

                        % 小尺度衰落（瑞利衰落）- 生成复高斯随机变量
                        re = (randn() + 1i * randn()) / sqrt(2);  % 归一化
                        xi = abs(re) ^ 2; % 瑞利衰落的幅度

                        % 信道增益（不包括干扰）
                        channel_gain = K * vartheta * xi * dist_t^(-epsilon);

                        % 计算干扰：来自其他IU的干扰
                        interference = 0;
                        for k = 1:iu_count_per_community
                            other_iu_idx = iu_indices(m, k);

                            if other_iu_idx ~= i && other_iu_idx ~= j % 其他IU
                                % 计算干扰IU k到接收用户j的距离
                                dist_interferer = sqrt(sum((user_positions(other_iu_idx, :, t) - user_positions(j, :, t)).^2));

                                % 如果干扰IU在传输范围内，计算干扰
                                if dist_interferer <= iu_coverage
                                    % 慢衰落
                                    vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
                                    % 小尺度衰落
                                    re_int = (randn() + 1i * randn()) / sqrt(2);  % 归一化
                                    xi_int = abs(re_int) ^ 2;

                                    % 干扰信道增益
                                    interference_gain = K * vartheta_int * xi_int * dist_interferer^(-epsilon);
                                    interference = interference + P_iu * interference_gain;
                                end
                            end
                        end

                        % 使用Shannon公式计算瞬时D2D速率（包含干扰）
                        R_instantaneous = B * log2(1 + (P_iu * channel_gain) / (N0 + interference));
                        if R_max_iu <= R_instantaneous
                            R_max_iu = R_instantaneous;
                        end

                        % 累加有效的瞬时速率
                        total_rate = total_rate + R_instantaneous;
                        valid_slots = valid_slots + 1;
                    end
                end
                % 计算平均速率并设置边权重
                if valid_slots > 0
                    % 计算所有有效时隙的平均速率
                    avg_rate = total_rate / valid_slots;
                    % 归一化到[0,1]范围，设置对称边权重
                    % pl_edge_weights(i, j) = avg_rate / R_max; % 确保对称性
                    pl_edge_weights(i, j) = min(1, avg_rate / R_max_iu); % 确保对称性
                    % pl_edge_weights(j, i) = avg_rate / R_max;  % 确保对称性
                    pl_edge_weights(j, i) = min(1, avg_rate / R_max_iu); % 确保对称性
                else
                    % 如果没有有效时隙（用户间始终不在D2D覆盖范围内）
                    pl_edge_weights(i, j) = 0;
                    pl_edge_weights(j, i) = 0;
                end
            else
                % 都不是IU，无法进行D2D通信
                pl_edge_weights(i, j) = 0;
                pl_edge_weights(j, i) = 0;
            end
        end


        % 计算用户i与SBS的物理连接
        total_rate = 0;
        valid_slots = 0;

        for t = 1:T_small
            % 计算用户在时隙t的位置到SBS的距离
            dist_t = sqrt(sum((user_positions(i, :, t) - sbs_positions(m, :)).^2));

            % 检查用户是否在SBS覆盖范围内
            if dist_t <= sbs_coverage
                % 慢衰落（阴影衰落）
                slowfading_sd = slowfading_dB / (10 * log10(exp(1)));% 将 dB 转换为对数后的标准差
                slowfading_avg = -slowfading_sd^2 / 2;% 假设均值为 0 dB，则对数后的均值为 mu = -sigma^2 / 2
                vartheta = lognrnd(slowfading_avg, slowfading_sd);% 慢衰落增益

                % 小尺度衰落（瑞利衰落）
                re = (randn() + 1i * randn()) / sqrt(2);  % 归一化
                xi = abs(re) ^ 2;

                % 信道增益（不包括干扰）
                channel_gain = K * vartheta * xi * dist_t^(-epsilon);

                % 计算干扰：来自其他SBS的干扰
                interference = 0;
                for n = 1:h
                    if n ~= m  % 其他SBS
                        % 计算其他SBS n到用户i的距离
                        dist_interferer_sbs = sqrt(sum((user_positions(i, :, t) - sbs_positions(n, :)).^2));

                        % 如果其他SBS在用户的接收范围内（可能造成干扰）%if dist_interferer_sbs <= sbs_coverage %end

                        % 慢衰落
                        vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
                        % 小尺度衰落
                        re_int = (randn() + 1i * randn()) / sqrt(2);  % 归一化
                        xi_int = abs(re_int) ^ 2;

                        % 干扰信道增益
                        interference_gain = K * vartheta_int * xi_int * dist_interferer_sbs^(-epsilon);
                        interference = interference + P_sbs * interference_gain;

                    end
                end              

                % 使用Shannon公式计算瞬时速率（包含干扰）
                R_instantaneous = B * log2(1 + (P_sbs * channel_gain) / (N0 + interference));
                if R_max_sbs <= R_instantaneous
                    R_max_sbs = R_instantaneous;
                end

                % 累加有效的瞬时速率
                total_rate = total_rate + R_instantaneous;
                valid_slots = valid_slots + 1;
            end
        end
        % 计算平均速率并设置边权重
        if valid_slots > 0
            % 计算所有有效时隙的平均速率
            avg_rate = total_rate / valid_slots;
            % 归一化到[0,1]范围，设置双向边权重
            % pl_edge_weights(i, sbs_idx) = avg_rate / R_max; % 确保对称性
            pl_edge_weights(i, sbs_idx)   = min(1, avg_rate / R_max_sbs); % 确保对称性
            % pl_edge_weights(sbs_idx, i) = avg_rate / R_max; % 确保对称性
            pl_edge_weights(sbs_idx, i)   = min(1, avg_rate / R_max_sbs); % 确保对称性
        else
            % 如果没有有效时隙（用户始终不在覆盖范围内）
            pl_edge_weights(i, sbs_idx) = 0;
            pl_edge_weights(sbs_idx, i) = 0;
        end
    end

    % 计算SBS的自环边权重为1
    pl_edge_weights(sbs_idx, sbs_idx) = 1;
    % SBS间不直接连接
    for n = m+1:h  % 只计算上三角，避免重复
        other_sbs_idx = total_users + n;
        pl_edge_weights(sbs_idx, other_sbs_idx) = 0;
        pl_edge_weights(other_sbs_idx, sbs_idx) = 0;
    end
end


end