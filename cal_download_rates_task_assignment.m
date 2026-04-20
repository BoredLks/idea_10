function [download_rates,task_assignment] = cal_download_rates_task_assignment(h, iu_count_per_community, nf, sbs_coverage, iu_coverage, B, P_sbs, P_iu, N0, K, epsilon, slowfading_dB, target_community, sbs_positions, user_positions, iu_indices, iu_flags, cache_decision, community_users, requested_videos)
% %% 计算每个时隙的用户下载速率和任务分配
% 
% download_rates = zeros(length(community_users), nf); % 初始化
% task_assignment = zeros(length(community_users), nf); % 初始化
% R_max = B * log2(1 + (P_sbs * K * 1 * 1) / N0); % 计算最大理论速率
% 
% 
% slowfading_sd = slowfading_dB / (10 * log10(exp(1)));% 将 dB 转换为对数后的标准差
% slowfading_avg = -slowfading_sd^2 / 2;% 假设均值为 0 dB，则对数后的均值为 mu = -sigma^2 / 2
% 
% % 对每个时隙计算下载速率和任务分配
% for t = 1:nf
% 
%     iu_busy_other = false(1, iu_count_per_community);  % “对外服务”名额占用标记
% 
%     for i = 1:length(community_users)
%         user_idx = community_users(i);
%         requested_video = requested_videos(i);
% 
%         % 判断用户下载速率的情况
%         if iu_flags(user_idx) == 1 && cache_decision(user_idx, requested_video) == 1 % Case 1: IU用户自己请求且缓存了请求的文件
%             download_rates(i, t) = R_max; % 本地读取近似
%             task_assignment(i, t) = find(iu_indices(target_community,:) == user_idx); % 候选
%         else
%             % 寻找最佳的服务节点
%             best_rate = 0;
%             best_assignment = 0; % 默认SBS
% 
%             % 检查社区内其他IU是否缓存了该文件 % Case 2: 附近IU缓存了请求的文件
%             for j = 1:iu_count_per_community
%                 iu_idx = iu_indices(target_community, j);
%                 if cache_decision(iu_idx, requested_video) == 1 && iu_busy_other(j) == false % 确保iu没被占用
%                     % 计算距离
%                     dist = sqrt(sum((user_positions(user_idx, :, t) - user_positions(iu_idx, :, t)).^2));
% 
%                     if dist <= iu_coverage
%                         % 计算信道增益和干扰
%                         % 大尺度
% 
%                         vartheta = lognrnd(slowfading_avg, slowfading_sd);
%                         % 小尺度
%                         re_real = randn();
%                         re_imag = randn();
%                         re = sqrt(re_real + 1i * re_imag);
%                         xi = abs(re) ^ 2;
%                         % 增益
%                         channel_gain = K * vartheta * xi * dist^(-epsilon);
% 
%                         % 计算干扰
%                         interference = 0;
%                         for k = 1:iu_count_per_community
%                             other_iu_idx = iu_indices(target_community, k);
%                             if other_iu_idx ~= iu_idx && other_iu_idx ~= user_idx % 判断其他IU不是本IU且其他IU也不能是本用户。就是说明排除了传输双方把对面认成其他IU
%                                 dist_interferer = sqrt(sum((user_positions(other_iu_idx, :, t) - user_positions(user_idx, :, t)).^2));
% 
%                                 if dist_interferer <= iu_coverage
%                                     % 大尺度
%                                     vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
%                                     % 小尺度
%                                     re_real_int = randn();
%                                     re_imag_int = randn();
%                                     re_int = sqrt(re_real_int + 1i * re_imag_int);
%                                     xi_int = abs(re_int) ^ 2;
%                                     % 总干扰
%                                     interference_gain = K * vartheta_int * xi_int * dist_interferer^(-epsilon);
%                                     interference = interference + P_iu * interference_gain;
%                                 end
%                             end
%                         end
% 
%                         rate = B * log2(1 + (P_iu * channel_gain) / (N0 + interference));
% 
%                         if rate > best_rate
%                             best_rate = rate;
%                             best_assignment = j; % IU编号
%                         end
% 
%                     end
%                 end
%             end
% 
%             if (best_rate <= 0.5) % 除非IU的速率实在是太低，那么只能选择SBS进行传输
%                 best_rate = 0;
%                 best_assignment = 0; % SBS默认编号
%             end
% 
% 
%             % 如果没有找到合适的IU，使用SBS % Case 3: 所处区域的SBS传输，缓存可能在本区域SBS，云，其他SBS上
%             if best_rate == 0
%                 dist_to_sbs = sqrt(sum((user_positions(user_idx, :, t) - sbs_positions(target_community, :)).^2));
% 
%                 if dist_to_sbs <= sbs_coverage
%                     % 计算信道增益和干扰
%                     % 大尺度
%                     vartheta = lognrnd(slowfading_avg, slowfading_sd);
%                     % 小尺度
%                     re_real = randn();
%                     re_imag = randn();
%                     re = sqrt(re_real + 1i * re_imag);
%                     xi = abs(re) ^ 2;
%                     % 增益
%                     channel_gain = K * vartheta * xi * dist_to_sbs^(-epsilon);
% 
%                     % 计算干扰
%                     interference = 0;
%                     for m = 1:h
%                         if m ~= target_community
%                             % 计算其他SBS到用户的距离
%                             dist_interferer_sbs = sqrt(sum((user_positions(user_idx, :, t) - sbs_positions(m, :)).^2));
%                             % 如果其他SBS在用户的接收范围内（可能造成干扰）%if dist_interferer_sbs <= sbs_coverage %end
%                             % 大尺度
%                             vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
%                             % 小尺度
%                             re_real_int = randn();
%                             re_imag_int = randn();
%                             re_int = sqrt(re_real_int + 1i * re_imag_int);
%                             xi_int = abs(re_int) ^ 2;
%                             % 总干扰
%                             interference_gain = K * vartheta_int * xi_int * dist_interferer_sbs^(-epsilon);
%                             interference = interference + P_sbs * interference_gain;
% 
%                         end
%                     end
% 
%                     best_rate = B * log2(1 + (P_sbs * channel_gain) / (N0 + interference));
% 
%                 end
%             end
% 
%             download_rates(i, t) = best_rate;
%             task_assignment(i, t) = best_assignment;
%             if best_assignment ~= 0
%                 iu_busy_other(best_assignment) = true;
%             end
% 
%         end
%     end
% end




% %% 计算每个时隙的用户下载速率和任务分配（修正版：全局贪心 + IU 对外 1 名额，自服务不占名额）
% download_rates  = zeros(length(community_users), nf); % [用户 × 时隙]
% task_assignment = zeros(length(community_users), nf); % 0=SBS，1..iu_count_per_community=对应 IU 序号
% R_max = B * log2(1 + (P_sbs * K) / N0);              % 维持你原来的近似最大速率（本地读取用）
% 
% % 对数正态慢衰落参数（与你原代码一致）
% slowfading_sd  = slowfading_dB / (10 * log10(exp(1)));
% slowfading_avg = -slowfading_sd^2 / 2;
% 
% for t = 1:nf
%     % 每个时隙：IU 对“外部 UE”的服务名额（1 个）
%     iu_busy_other = false(1, iu_count_per_community); 
% 
%     %% Step 1) IU 自己命中：先本地服务（不占对外名额）
%     for i = 1:length(community_users)
%         user_idx = community_users(i);
%         requested_video = requested_videos(i);
% 
%         if iu_flags(user_idx) == 1 && cache_decision(user_idx, requested_video) == 1
%             % 近似为本地读取（你原先用 R_max）
%             download_rates(i, t)  = R_max;
%             % 找到该 IU 在 iu_indices 中的列号作为标识（仅作记录，不占对外名额）
%             task_assignment(i, t) = find(iu_indices(target_community, :) == user_idx, 1, 'first');
%         end
%     end
% 
%     %% Step 2) 构造所有 UE→IU 候选并按速率降序分配（对外仅 1 名额/ IU）
%     % cands: 每行 [rate, i(UE行号), j(IU列号)]
%     cands = [];
% 
%     % 2.1 枚举候选
%     for i = 1:length(community_users)
%         if download_rates(i, t) > 0
%             % 已被“自服务”填充，跳过
%             continue;
%         end
% 
%         user_idx = community_users(i);
%         requested_video = requested_videos(i);
% 
%         for j = 1:iu_count_per_community
%             if iu_busy_other(j), continue; end  % 该 IU 的对外名额已占用
% 
%             iu_idx = iu_indices(target_community, j);
%             if cache_decision(iu_idx, requested_video) ~= 1
%                 continue; % 该 IU 未缓存此文件
%             end
% 
%             % 覆盖判定
%             dist_iu = sqrt(sum((user_positions(user_idx, :, t) - user_positions(iu_idx, :, t)).^2));
%             if dist_iu > iu_coverage, continue; end
% 
%             % —— 计算 IU→UE 速率（沿用你原本的随机快/慢衰落 + 干扰）——
%             % 大尺度 / 小尺度
%             vartheta = lognrnd(slowfading_avg, slowfading_sd);
%             re = (randn() + 1i * randn()) / sqrt(2);
%             xi = abs(re)^2;
% 
%             % 信道增益（与你原来的写法保持一致）
%             channel_gain = K * vartheta * xi * dist_iu^(-epsilon);
% 
%             % 其他 IU 干扰（同一社区内，排除自身 IU 与本用户）
%             interference = 0;
%             for k = 1:iu_count_per_community
%                 other_iu_idx = iu_indices(target_community, k);
%                 if other_iu_idx ~= iu_idx && other_iu_idx ~= user_idx
%                     dist_int = sqrt(sum((user_positions(other_iu_idx, :, t) - user_positions(user_idx, :, t)).^2));
%                     if dist_int <= iu_coverage
%                         vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
%                         re_int = (randn() + 1i * randn()) / sqrt(2);
%                         xi_int = abs(re_int)^2;
%                         interference_gain = K * vartheta_int * xi_int * dist_int^(-epsilon);
%                         interference = interference + P_iu * interference_gain;
%                     end
%                 end
%             end
% 
%             rate_ij = B * log2(1 + (P_iu * channel_gain) / (N0 + interference));
% 
%             % 低于阈值则弃用（与你原阈值 0.5 一致）
%             if rate_ij > 0.5
%                 cands(end+1, :) = [rate_ij, i, j]; % #ok<AGROW>
%             end
%         end
%     end
% 
%     % 2.2 候选按速率降序，贪心分配（每个 IU 仅 1 个“对外”名额）
%     if ~isempty(cands)
%         [~, ord] = sort(cands(:, 1), 'descend');
%         for kk = 1:length(ord)
%             rate_ij = cands(ord(kk), 1);
%             i       = cands(ord(kk), 2);
%             j       = cands(ord(kk), 3);
% 
%             if download_rates(i, t) == 0 && ~iu_busy_other(j)
%                 download_rates(i, t)  = rate_ij;
%                 task_assignment(i, t) = j;       % 标记使用了第 j 个 IU
%                 iu_busy_other(j)      = true;    % 占用 1 个对外名额
%             end
%         end
%     end
% 
%     %% Step 3) 剩余 UE 走 SBS（保持你原有的速率/干扰写法，并写回）
%     for i = 1:length(community_users)
%         if download_rates(i, t) > 0
%             continue; % 已分到 IU 或自服务
%         end
% 
%         user_idx = community_users(i);
%         % 到本社区 SBS 的距离
%         dist_sbs = sqrt(sum((user_positions(user_idx, :, t) - sbs_positions(target_community, :)).^2));
% 
%         if dist_sbs <= sbs_coverage
%             % 大尺度 / 小尺度
%             vartheta = lognrnd(slowfading_avg, slowfading_sd);
%             re = (randn() + 1i * randn()) / sqrt(2);
%             xi = abs(re)^2;
% 
%             channel_gain = K * vartheta * xi * dist_sbs^(-epsilon);
% 
%             % 其他社区 SBS 干扰（与原逻辑一致）
%             interference = 0;
%             for m = 1:h
%                 if m ~= target_community
%                     dist_int_sbs = sqrt(sum((user_positions(user_idx, :, t) - sbs_positions(m, :)).^2));
%                     % 这里不额外判断覆盖，你原代码对干扰是“可能影响就计入”
%                     vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
%                     re_int = (randn() + 1i * randn()) / sqrt(2);
%                     xi_int = abs(re_int)^2;
%                     interference_gain = K * vartheta_int * xi_int * dist_int_sbs^(-epsilon);
%                     interference = interference + P_sbs * interference_gain;
%                 end
%             end
% 
%             rate_sbs = B * log2(1 + (P_sbs * channel_gain) / (N0 + interference));
%             download_rates(i, t)  = rate_sbs;
%             task_assignment(i, t) = 0; % 0 表示走 SBS
%         else
%             % 超出覆盖，无法下载（维持为 0）
%             download_rates(i, t)  = 0;
%             task_assignment(i, t) = 0;
%         end
%     end
% end









% %% 计算每个时隙的用户下载速率和任务分配
% 
% download_rates = zeros(length(community_users), nf); % 初始化
% task_assignment = zeros(length(community_users), nf); % 初始化
% R_max = B * log2(1 + (P_sbs * K * 1 * 1) / N0); % 计算最大理论速率
% 
% 
% slowfading_sd = slowfading_dB / (10 * log10(exp(1)));% 将 dB 转换为对数后的标准差
% slowfading_avg = -slowfading_sd^2 / 2;% 假设均值为 0 dB，则对数后的均值为 mu = -sigma^2 / 2
% 
% % 对每个时隙计算下载速率和任务分配
% for t = 1:nf
%     iu_busy_other = false(1, iu_count_per_community);  % “对外服务”名额占用标记
%     for i = 1:length(community_users)
%         user_idx = community_users(i);
%         requested_video = requested_videos(i);
% 
%         % 判断用户下载速率的情况
%         if iu_flags(user_idx) == 1 && cache_decision(user_idx, requested_video) == 1 % Case 1: IU用户自己请求且缓存了请求的文件
%             download_rates(i, t) = R_max; % 本地读取近似
%             task_assignment(i, t) = find(iu_indices(target_community,:) == user_idx); % 候选
%         else
%             % 寻找最佳的服务节点
%             best_rate = 0;
%             best_assignment = 0; % 默认SBS
% 
%             % 检查社区内其他IU是否缓存了该文件 % Case 2: 附近IU缓存了请求的文件
%             for j = 1:iu_count_per_community
%                 iu_idx = iu_indices(target_community, j);
%                 if cache_decision(iu_idx, requested_video) == 1 && iu_busy_other(j) == false % 确保iu没被占用
%                     % 计算距离
%                     dist = sqrt(sum((user_positions(user_idx, :, t) - user_positions(iu_idx, :, t)).^2));
% 
%                     if dist <= iu_coverage
%                         % 计算信道增益和干扰
%                         % 大尺度
% 
%                         vartheta = lognrnd(slowfading_avg, slowfading_sd);
%                         % 小尺度
%                         re_real = randn();
%                         re_imag = randn();
%                         re = sqrt(re_real + 1i * re_imag);
%                         xi = abs(re) ^ 2;
%                         % 增益
%                         channel_gain = K * vartheta * xi * dist^(-epsilon);
% 
%                         % 计算干扰
%                         interference = 0;
%                         for k = 1:iu_count_per_community
%                             other_iu_idx = iu_indices(target_community, k);
%                             if other_iu_idx ~= iu_idx && other_iu_idx ~= user_idx % 判断其他IU不是本IU且其他IU也不能是本用户。就是说明排除了传输双方把对面认成其他IU
%                                 dist_interferer = sqrt(sum((user_positions(other_iu_idx, :, t) - user_positions(user_idx, :, t)).^2));
% 
%                                 if dist_interferer <= iu_coverage
%                                     % 大尺度
%                                     vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
%                                     % 小尺度
%                                     re_real_int = randn();
%                                     re_imag_int = randn();
%                                     re_int = sqrt(re_real_int + 1i * re_imag_int);
%                                     xi_int = abs(re_int) ^ 2;
%                                     % 总干扰
%                                     interference_gain = K * vartheta_int * xi_int * dist_interferer^(-epsilon);
%                                     interference = interference + P_iu * interference_gain;
%                                 end
%                             end
%                         end
% 
%                         rate = B * log2(1 + (P_iu * channel_gain) / (N0 + interference));
% 
%                         if rate > best_rate
%                             best_rate = rate;
%                             best_assignment = j; % IU编号
%                         end
% 
%                     end
%                 end
%             end
% 
%             if (best_rate <= 0.5) % 除非IU的速率实在是太低，那么只能选择SBS进行传输
%                 best_rate = 0;
%                 best_assignment = 0; % SBS默认编号
%             end
% 
% 
%             % 如果没有找到合适的IU，使用SBS % Case 3: 所处区域的SBS传输，缓存可能在本区域SBS，云，其他SBS上
%             if best_rate == 0
%                 dist_to_sbs = sqrt(sum((user_positions(user_idx, :, t) - sbs_positions(target_community, :)).^2));
% 
%                 if dist_to_sbs <= sbs_coverage
%                     % 计算信道增益和干扰
%                     % 大尺度
%                     vartheta = lognrnd(slowfading_avg, slowfading_sd);
%                     % 小尺度
%                     re_real = randn();
%                     re_imag = randn();
%                     re = sqrt(re_real + 1i * re_imag);
%                     xi = abs(re) ^ 2;
%                     % 增益
%                     channel_gain = K * vartheta * xi * dist_to_sbs^(-epsilon);
% 
%                     % 计算干扰
%                     interference = 0;
%                     for m = 1:h
%                         if m ~= target_community
%                             % 计算其他SBS到用户的距离
%                             dist_interferer_sbs = sqrt(sum((user_positions(user_idx, :, t) - sbs_positions(m, :)).^2));
%                             % 如果其他SBS在用户的接收范围内（可能造成干扰）%if dist_interferer_sbs <= sbs_coverage %end
%                             % 大尺度
%                             vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
%                             % 小尺度
%                             re_real_int = randn();
%                             re_imag_int = randn();
%                             re_int = sqrt(re_real_int + 1i * re_imag_int);
%                             xi_int = abs(re_int) ^ 2;
%                             % 总干扰
%                             interference_gain = K * vartheta_int * xi_int * dist_interferer_sbs^(-epsilon);
%                             interference = interference + P_sbs * interference_gain;
% 
%                         end
%                     end
% 
%                     best_rate = B * log2(1 + (P_sbs * channel_gain) / (N0 + interference));
% 
%                 end
%             end
% 
%             download_rates(i, t) = best_rate;
%             task_assignment(i, t) = best_assignment;
%             if best_assignment ~= 0
%                 iu_busy_other(best_assignment) = true;
%             end
% 
%         end
%     end
% end













%% 计算每个时隙的用户下载速率和任务分配

download_rates = zeros(length(community_users), nf); % 初始化
task_assignment = zeros(length(community_users), nf); % 初始化
R_max = B * log2(1 + (P_sbs * K * 1 * 1) / N0); % 计算最大理论速率


slowfading_sd = slowfading_dB / (10 * log10(exp(1)));% 将 dB 转换为对数后的标准差
slowfading_avg = -slowfading_sd^2 / 2;% 假设均值为 0 dB，则对数后的均值为 mu = -sigma^2 / 2

% 对每个时隙计算下载速率和任务分配
for t = 1:nf
    iu_busy_other = false(1, iu_count_per_community);  % “对外服务”名额占用标记
    for i = 1:length(community_users)
        user_idx = community_users(i);
        requested_video = requested_videos(i);

        % 判断用户下载速率的情况
        if iu_flags(user_idx) == 1 && cache_decision(user_idx, requested_video) == 1 % Case 1: IU用户自己请求且缓存了请求的文件
            download_rates(i, t) = R_max; % 本地读取近似
            task_assignment(i, t) = find(iu_indices(target_community,:) == user_idx); % 候选
        else
            % 寻找最佳的服务节点
            best_rate = 0;
            best_assignment = 0; % 默认SBS

            % 检查社区内其他IU是否缓存了该文件 % Case 2: 附近IU缓存了请求的文件
            for j = 1:iu_count_per_community
                iu_idx = iu_indices(target_community, j);
                if cache_decision(iu_idx, requested_video) == 1 && iu_busy_other(j) == false % 确保iu没被占用
                    % 计算距离
                    dist = sqrt(sum((user_positions(user_idx, :, t) - user_positions(iu_idx, :, t)).^2));

                    if dist <= iu_coverage
                        % 计算信道增益和干扰
                        % 大尺度

                        vartheta = lognrnd(slowfading_avg, slowfading_sd);
                        % 小尺度
                        re = (randn() + 1i * randn()) / sqrt(2);
                        xi = abs(re)^2;
                        % 增益
                        channel_gain = K * vartheta * xi * dist^(-epsilon);

                        % 计算干扰
                        interference = 0;
                        for k = 1:iu_count_per_community
                            other_iu_idx = iu_indices(target_community, k);
                            if other_iu_idx ~= iu_idx && other_iu_idx ~= user_idx % 判断其他IU不是本IU且其他IU也不能是本用户。就是说明排除了传输双方把对面认成其他IU
                                dist_interferer = sqrt(sum((user_positions(other_iu_idx, :, t) - user_positions(user_idx, :, t)).^2));

                                if dist_interferer <= iu_coverage
                                    % 大尺度
                                    vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
                                    % 小尺度
                                    re_int = (randn() + 1i * randn()) / sqrt(2);
                                    xi_int = abs(re_int) ^ 2;
                                    % 总干扰
                                    interference_gain = K * vartheta_int * xi_int * dist_interferer^(-epsilon);
                                    interference = interference + P_iu * interference_gain;
                                end
                            end
                        end

                        rate = B * log2(1 + (P_iu * channel_gain) / (N0 + interference));

                        if rate > best_rate
                            best_rate = rate;
                            best_assignment = j; % IU编号
                        end

                    end
                end
            end

            if (best_rate <= 0.5) % 除非IU的速率实在是太低，那么为了避免IU与UE的传输速率过低导致两个用户接触时间无法完整传输一个块，那么只能选择SBS进行传输
                best_rate = 0;
                best_assignment = 0; % SBS默认编号
            end


            % 如果没有找到合适的IU，使用SBS % Case 3: 所处区域的SBS传输，缓存可能在本区域SBS，云，其他SBS上
            if best_rate == 0
                dist_to_sbs = sqrt(sum((user_positions(user_idx, :, t) - sbs_positions(target_community, :)).^2));

                if dist_to_sbs <= sbs_coverage
                    % 计算信道增益和干扰
                    % 大尺度
                    vartheta = lognrnd(slowfading_avg, slowfading_sd);
                    % 小尺度
                    re = (randn() + 1i * randn()) / sqrt(2);
                    xi = abs(re)^2;
                    % 增益
                    channel_gain = K * vartheta * xi * dist_to_sbs^(-epsilon);

                    % 计算干扰
                    interference = 0;
                    for m = 1:h
                        if m ~= target_community
                            % 计算其他SBS到用户的距离
                            dist_interferer_sbs = sqrt(sum((user_positions(user_idx, :, t) - sbs_positions(m, :)).^2));
                            % 如果其他SBS在用户的接收范围内（可能造成干扰）%if dist_interferer_sbs <= sbs_coverage %end
                            % 大尺度
                            vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
                            % 小尺度
                            re_int = (randn() + 1i * randn()) / sqrt(2);
                            xi_int = abs(re_int) ^ 2;
                            % 总干扰
                            interference_gain = K * vartheta_int * xi_int * dist_interferer_sbs^(-epsilon);
                            interference = interference + P_sbs * interference_gain;

                        end
                    end

                    best_rate = B * log2(1 + (P_sbs * channel_gain) / (N0 + interference));


                    if (best_rate < 0.5) % 如果SBS的速率还是太低，那只能设置一个最低速率   这个可要可不要，做蒙特卡洛的时候都一样
                        best_rate = 0.5;
                    end

                end
            end

            download_rates(i, t) = best_rate;
            task_assignment(i, t) = best_assignment;
            if best_assignment ~= 0
                iu_busy_other(best_assignment) = true;
            end

        end
    end
end



for t = 1:nf
    iu_busy_other = false(1, iu_count_per_community);

    %% Step 1: IU自身命中 — 本地服务（不占对外名额）
    for i = 1:length(community_users)
        user_idx = community_users(i);
        requested_video = requested_videos(i);
        if iu_flags(user_idx) == 1 && cache_decision(user_idx, requested_video) == 1
            download_rates(i, t) = R_max;
            task_assignment(i, t) = find(iu_indices(target_community,:) == user_idx, 1, 'first');
        end
    end

    %% Step 2: 收集所有UE→IU候选对 [速率, 用户序号, IU序号]
    cands = [];
    for i = 1:length(community_users)
        if download_rates(i, t) > 0, continue; end  % 已被自服务填充
        user_idx = community_users(i);
        requested_video = requested_videos(i);

        for j = 1:iu_count_per_community
            iu_idx = iu_indices(target_community, j);
            if cache_decision(iu_idx, requested_video) ~= 1, continue; end

            dist = sqrt(sum((user_positions(user_idx, :, t) - user_positions(iu_idx, :, t)).^2));
            if dist > iu_coverage, continue; end

            % 计算D2D速率（用修正后的瑞利衰落）
            vartheta = lognrnd(slowfading_avg, slowfading_sd);
            re = (randn() + 1i * randn()) / sqrt(2);
            xi = abs(re)^2;
            channel_gain = K * vartheta * xi * dist^(-epsilon);

            interference = 0;
            for k = 1:iu_count_per_community
                other_iu_idx = iu_indices(target_community, k);
                if other_iu_idx ~= iu_idx && other_iu_idx ~= user_idx
                    dist_int = sqrt(sum((user_positions(other_iu_idx, :, t) - user_positions(user_idx, :, t)).^2));
                    if dist_int <= iu_coverage
                        vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
                        re_int = (randn() + 1i * randn()) / sqrt(2);
                        xi_int = abs(re_int)^2;
                        ig = K * vartheta_int * xi_int * dist_int^(-epsilon);
                        interference = interference + P_iu * ig;
                    end
                end
            end

            rate = B * log2(1 + (P_iu * channel_gain) / (N0 + interference));
            if rate > 0.5  % 最低速率阈值
                cands = [cands; rate, i, j];
            end
        end
    end

    %% Step 3: 按速率降序贪心分配
    if ~isempty(cands)
        [~, order] = sort(cands(:,1), 'descend');
        cands = cands(order, :);
        assigned_users = false(length(community_users), 1);

        for idx = 1:size(cands, 1)
            r_cand = cands(idx, 1);
            i_cand = cands(idx, 2);
            j_cand = cands(idx, 3);

            if ~assigned_users(i_cand) && ~iu_busy_other(j_cand)
                download_rates(i_cand, t) = r_cand;
                task_assignment(i_cand, t) = j_cand;
                assigned_users(i_cand) = true;
                iu_busy_other(j_cand) = true;
            end
        end
    end

    %% Step 4: 未分配到IU的用户 → 退回SBS
    for i = 1:length(community_users)
        if download_rates(i, t) > 0, continue; end
        user_idx = community_users(i);

        dist_to_sbs = sqrt(sum((user_positions(user_idx, :, t) - sbs_positions(target_community, :)).^2));
        if dist_to_sbs <= sbs_coverage
            vartheta = lognrnd(slowfading_avg, slowfading_sd);
            re = (randn() + 1i * randn()) / sqrt(2);
            xi = abs(re)^2;
            channel_gain = K * vartheta * xi * dist_to_sbs^(-epsilon);

            interference = 0;
            for m = 1:h
                if m ~= target_community
                    dist_int_sbs = sqrt(sum((user_positions(user_idx, :, t) - sbs_positions(m, :)).^2));
                    vartheta_int = lognrnd(slowfading_avg, slowfading_sd);
                    re_int = (randn() + 1i * randn()) / sqrt(2);
                    xi_int = abs(re_int)^2;
                    ig = K * vartheta_int * xi_int * dist_int_sbs^(-epsilon);
                    interference = interference + P_sbs * ig;
                end
            end

            best_rate = B * log2(1 + (P_sbs * channel_gain) / (N0 + interference));
            if best_rate < 0.5, best_rate = 0.5; end
            download_rates(i, t) = best_rate;
        end
        task_assignment(i, t) = 0;
    end
end



end
