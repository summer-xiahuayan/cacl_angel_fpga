% 优化版：CX/CY正弦函数拟合（强制低频约束+精准初始值+参数校验）
% 解决：拟合参数与绘图不一致、局部最优、低频拟合不准问题

%% 1. 基础配置（关键：贴近真实值的初始参数）
cx_file = 'cx_int16.txt';       
cy_file = 'cy_int16.txt';       
Fs = 100;                       % 必须填实际采样频率！
start_idx = 3800;               
% 先验参数（基于你之前的FFT结果，大幅提升拟合精度）
f_prior = 0.0643;               % 已知的峰值频率（替代瞎猜的0.1）
DC_prior_cx = 17549.23;         % CX先验直流
A_prior_cx = 4724.14;           % CX先验幅值
DC_prior_cy = 16804.31;         % CY先验直流
A_prior_cy = 4563.85;           % CY先验幅值
% 读取并统一数据长度
cx_data = read_data(cx_file, start_idx);
cy_data = read_data(cy_file, start_idx);
len = min(length(cx_data), length(cy_data));
cx_data = cx_data(1:len);
cy_data = cy_data(1:len);
t = (0:len-1)'/Fs; % 时间轴强制列向量，长度=len

%% 4. 执行拟合（传入先验值，大幅提升精度）
fprintf('正在拟合CX数据...\n');
[cx_DC, cx_A, cx_f, cx_phi, cx_fit, cx_mse] = fit_sin_raw(t, cx_data, DC_prior_cx, A_prior_cx, f_prior);

fprintf('正在拟合CY数据...\n');
[cy_DC, cy_A, cy_f, cy_phi, cy_fit, cy_mse] = fit_sin_raw(t, cy_data, DC_prior_cy, A_prior_cy, f_prior);

%% 5. 输出结果（对比先验值，验证一致性）
fprintf('\n==================== 正弦拟合结果 ====================\n');
fprintf('【CX 正弦函数】\n');
fprintf('拟合公式：y = %.2f + %.2f·sin(2π×%.6f t + %.4f)\n', cx_DC, cx_A, cx_f, cx_phi);
fprintf(' - 直流分量DC（先验值%.2f）：%.2f\n', DC_prior_cx, cx_DC);
fprintf(' - 幅值A（先验值%.2f）：%.2f\n', A_prior_cx, cx_A);
fprintf(' - 频率f（先验值%.6f）：%.6f Hz\n', f_prior, cx_f);
fprintf(' - 相位φ：%.4f 弧度\n', cx_phi);
fprintf(' - 拟合均方误差MSE：%.4f（<1为优）\n', cx_mse);

fprintf('\n【CY 正弦函数】\n');
fprintf('拟合公式：y = %.2f + %.2f·sin(2π×%.6f t + %.4f)\n', cy_DC, cy_A, cy_f, cy_phi);
fprintf(' - 直流分量DC（先验值%.2f）：%.2f\n', DC_prior_cy, cy_DC);
fprintf(' - 幅值A（先验值%.2f）：%.2f\n', A_prior_cy, cy_A);
fprintf(' - 频率f（先验值%.6f）：%.6f Hz\n', f_prior, cy_f);
fprintf(' - 相位φ：%.4f 弧度\n', cy_phi);
fprintf(' - 拟合均方误差MSE：%.4f\n', cy_mse);

%% 6. 保存结果
fid = fopen('sin_fit_results.txt', 'w');
fprintf(fid, 'CX拟合参数：DC=%.2f, A=%.2f, f=%.6f, phi=%.4f, MSE=%.4f\n',...
    cx_DC, cx_A, cx_f, cx_phi, cx_mse);
fprintf(fid, 'CY拟合参数：DC=%.2f, A=%.2f, f=%.6f, phi=%.4f, MSE=%.4f\n',...
    cy_DC, cy_A, cy_f, cy_phi, cy_mse);
fclose(fid);
fprintf('\n拟合结果已保存为：sin_fit_results.txt\n');

%% 7. 绘图验证（确保维度匹配+视觉一致）
figure('Color','white','Position',[100,100,1200,800]);
% CX拟合对比（放大局部，更易看匹配度）
subplot(2,1,1);
plot(t, cx_data, 'b-', 'LineWidth',0.8, 'DisplayName','原始数据'); hold on;
plot(t, cx_fit, 'r--', 'LineWidth',1.2, 'DisplayName','拟合正弦曲线');
% 局部放大（前1000个点）
xlim([0, max(t)]); % 放大前10秒
xlabel('时间 (s)'); ylabel('CX值');
title(sprintf('CX数据拟合（MSE=%.4f）', cx_mse));
legend('Location','best'); grid on;

% CY拟合对比
subplot(2,1,2);
plot(t, cy_data, 'g-', 'LineWidth',0.8, 'DisplayName','原始数据'); hold on;
plot(t, cy_fit, 'm--', 'LineWidth',1.2, 'DisplayName','拟合正弦曲线');
xlim([0, max(t)]);
xlabel('时间 (s)'); ylabel('CY值');
title(sprintf('CY数据拟合（MSE=%.4f）', cy_mse));
legend('Location','best'); grid on;

% 强制中文显示
try
    set(findall(gcf, 'Type','Text'), 'FontName','SimHei');
catch
    set(findall(gcf, 'Type','Text'), 'FontName','Arial');
end



%% 2. 读取数据（确保维度统一）
function data = read_data(file_path, start_idx)
    fid = fopen(file_path, 'r');
    if fid == -1, error('文件不存在：%s', file_path); end
    data = [];
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line) && ~isempty(line)
            val = str2double(strtrim(line));
            if ~isnan(val), data = [data; val]; end % 强制列向量
        end
    end
    fclose(fid);
    % 安全截取数据
    if length(data) >= start_idx
        data = data(start_idx:length(data));
    else
        warning('数据长度不足(%d)，使用全部数据', length(data));
    end
    data = data(:); % 强制列向量
end



%% 3. 优化的正弦拟合函数（带约束+精准初始值）
function [DC, A, f, phi, fit_y, mse] = fit_sin_raw(t, y, DC_prior, A_prior, f_prior)
    t = t(:); y = y(:);
    len = length(t);
    if length(y) ~= len
        error('时间轴和数据长度不匹配！');
    end

    % 定义正弦模型（确保输出列向量）
    sin_model = @(params, t) params(1) + params(2)*sin(2*pi*params(3)*t + params(4));

    % 关键优化：用先验值做初始猜测（而非瞎猜）
    initial_guess = [DC_prior, A_prior, f_prior, 0];
    
    % 关键：添加参数约束（避免无意义值）
    lb = [min(y), 0, 0.05, -pi];   % 下界：DC≥最小值，幅值≥0，频率≥0.05Hz，相位∈[-π,π]
    ub = [max(y), max(y)-min(y), 0.08, pi]; % 上界：频率≤0.08Hz（贴近0.0643）

    % 拟合（带约束，避免局部最优）
    options = optimoptions('lsqcurvefit', ...
        'Display', 'off', ...       % 关闭迭代输出
        'MaxFunctionEvaluations', 1e5, ... % 增加迭代次数
        'MaxIterations', 1e4);
    [params, resnorm] = lsqcurvefit(sin_model, initial_guess, t, y, lb, ub, options);

    % 提取参数并校验
    DC = params(1);
    A = abs(params(2)); % 强制幅值为正
    f = params(3);
    phi = params(4);
    % 相位归一化到[-π, π]
    phi = mod(phi + pi, 2*pi) - pi;

    % 计算拟合曲线（确保维度匹配）
    fit_y = sin_model(params, t);
    fit_y = fit_y(:);
    mse = resnorm / len;

    % 格式化参数
    DC = round(DC, 2);
    A = round(A, 2);
    f = round(f, 6);
    phi = round(phi, 4);
end
