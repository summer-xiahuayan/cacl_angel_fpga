% 二维卡尔曼滤波（状态向量仅[x,y]，无速度项）
clear; clc; close all;

%% 1. 生成模拟数据（带噪声的二维点）
t = 0:1:19981;          % 时间序列
dt = t(2) - t(1);      % 时间步长
% 真实轨迹：近似静止（小幅波动）
x_true = sin(2*pi*6*t);  % x真实位置（小幅波动）
y_true = cos(2*pi*6*t);  % y真实位置（小幅波动）
% 观测值：真实值+高斯噪声（噪声可根据实际情况调整）
%x_meas = x_true + 0.2*randn(size(x_true));
%y_meas = y_true + 0.2*randn(size(y_true));

x_meas = importdata('cx.txt');
y_meas = importdata('cy.txt');

%% 2. 卡尔曼滤波参数初始化（核心简化）
% 状态向量 X = [x, y]' （仅位置，无速度）
X = [x_meas(1); y_meas(1)];  % 初始状态（用第一个观测值初始化）

% 状态转移矩阵 F（简化：下一时刻位置=当前位置）
F = [1, 0;  
     0, 1];  

% 观测矩阵 H（直接观测x、y，与状态向量完全匹配）
H = [1, 0;  
     0, 1];  

% 过程噪声协方差矩阵 Q（描述“位置不变”模型的不确定性）
% 若点几乎静止，Q调小；若有小幅运动，Q适当调大
Q = 0.01 * eye(2);  

% 观测噪声协方差矩阵 R（匹配观测噪声大小，噪声大则调大）
R = 0.04 * eye(2);  

% 状态协方差矩阵 P（初始值可设为单位矩阵）
P = eye(2);

%% 3. 卡尔曼滤波迭代过程
X_filter = zeros(2, length(t));  % 存储滤波后的[x,y]
for k = 1:length(t)
    % 步骤1：预测（Predict）
    X_pred = F * X;              % 预测状态（X_pred ≈ X）
    P_pred = F * P * F' + Q;     % 预测协方差
    
    % 步骤2：更新（Update）
    % 卡尔曼增益（核心公式，适配2维状态）
    K = P_pred * H' / (H * P_pred * H' + R);  
    Z = [x_meas(k); y_meas(k)];               % 当前观测值
    X = X_pred + K * (Z - H * X_pred);        % 更新状态
    P = (eye(2) - K * H) * P_pred;            % 更新协方差
    
    % 存储滤波结果
    X_filter(:, k) = X;
end

%% 4. 结果可视化
figure('Color','w');
% 绘制x方向对比
subplot(2,1,1);
plot(t, x_true, 'b-', 'LineWidth',1.5, 'DisplayName','真实值');
hold on;
plot(t, x_meas, 'r-', 'MarkerSize',8, 'DisplayName','观测值（带噪声）');
plot(t, X_filter(1,:), 'g-', 'LineWidth',1.5, 'DisplayName','滤波值');
xlabel('时间 (s)'); ylabel('x 位置');
legend('Location','best'); grid on; title('x方向滤波效果');

% 绘制y方向对比
subplot(2,1,2);
plot(t, y_true, 'b-', 'LineWidth',1.5, 'DisplayName','真实值');
hold on;
plot(t, y_meas, 'r-', 'MarkerSize',8, 'DisplayName','观测值（带噪声）');
plot(t, X_filter(2,:), 'g-', 'LineWidth',1.5, 'DisplayName','滤波值');
xlabel('时间 (s)'); ylabel('y 位置');
legend('Location','best'); grid on; title('y方向滤波效果');

% 绘制二维轨迹对比
figure('Color','w');
plot(x_true, y_true, 'b-', 'LineWidth',1.5, 'DisplayName','真实轨迹');
hold on;
plot(x_meas, y_meas, 'r-', 'MarkerSize',6, 'DisplayName','观测点');
plot(X_filter(1,:), X_filter(2,:), 'g-', 'LineWidth',1.5, 'DisplayName','滤波轨迹');
xlabel('x 位置'); ylabel('y 位置');
legend('Location','best'); grid on; title('二维轨迹整体对比');

%% 5. 保存滤波后的数据为TXT文件（每行一个点，保留6位小数）
% 定义保存路径和文件名（可自行修改）
x_filter_file = 'x_filterxy_result.txt';  % x方向滤波值保存文件
y_filter_file = 'y_filterxy_result.txt';  % y方向滤波值保存文件

% 提取数据（转置为列向量，确保每行一个点）
x_data = X_filter(1,:)';  % 转置后为N×1的列向量
y_data = X_filter(2,:)';  % 转置后为N×1的列向量

% 保存x方向数据（保留6位小数，每行一个值）
fid_x = fopen(x_filter_file, 'w');
if fid_x == -1
    error('无法创建x方向滤波数据文件，请检查路径权限！');
end
for i = 1:length(x_data)
    fprintf(fid_x, '%.6f\n', x_data(i));  % %.6f 表示保留6位小数
end
fclose(fid_x);

% 保存y方向数据（保留6位小数，每行一个值）
fid_y = fopen(y_filter_file, 'w');
if fid_y == -1
    error('无法创建y方向滤波数据文件，请检查路径权限！');
end
for i = 1:length(y_data)
    fprintf(fid_y, '%.6f\n', y_data(i));
end
fclose(fid_y);

% 提示保存完成
fprintf('x方向滤波数据已保存至：%s\n', x_filter_file);
fprintf('y方向滤波数据已保存至：%s\n', y_filter_file);