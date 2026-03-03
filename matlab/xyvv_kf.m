% 二维卡尔曼滤波（针对(x,y)坐标点）
clear; clc; close all;

%% 1. 生成模拟数据（带噪声的二维运动点）
% 真实轨迹：匀速直线运动
t = 0:0.0001:10;          % 时间序列
dt = t(2) - t(1);      % 时间步长
x_true = sin(2*pi*6*t);  % x真实位置（小幅波动）
y_true = cos(2*pi*6*t);  % y真实位置（小幅波动）
% 观测值：真实值+高斯噪声
x_meas = x_true + 0.1*randn(size(x_true));
y_meas = y_true + 0.1*randn(size(y_true));

%% 2. 卡尔曼滤波参数初始化
% 状态向量 X = [x, vx, y, vy]' （位置x, x方向速度, 位置y, y方向速度）
X = [x_meas(1); 0; y_meas(1); 0];  % 初始状态（速度初始化为0）

% 状态转移矩阵 F（匀速运动模型）
F = [1, dt, 0,  0;
     0,  1, 0,  0;
     0,  0, 1, dt;
     0,  0, 0,  1];

% 观测矩阵 H（仅观测x、y位置，不观测速度）
H = [1, 0, 0, 0;
     0, 0, 1, 0];

% 过程噪声协方差矩阵 Q（描述模型不确定性）
Q = 1e-4 * eye(4);

% 观测噪声协方差矩阵 R（描述观测噪声大小）
R = 0.01 * eye(2);

% 状态协方差矩阵 P
P = eye(4);

%% 3. 卡尔曼滤波迭代过程
X_filter = zeros(4, length(t));  % 存储滤波后的状态
for k = 1:length(t)
    % 步骤1：预测（Predict）
    X_pred = F * X;              % 预测状态
    P_pred = F * P * F' + Q;     % 预测协方差
    
    % 步骤2：更新（Update）
    K = P_pred * H' / (H * P_pred * H' + R);  % 卡尔曼增益
    Z = [x_meas(k); y_meas(k)];               % 当前观测值
    X = X_pred + K * (Z - H * X_pred);        % 更新状态
    P = (eye(4) - K * H) * P_pred;            % 更新协方差
    
    % 存储结果
    X_filter(:, k) = X;
end

%% 4. 结果可视化
figure('Color','w');
% 绘制x方向轨迹
subplot(2,1,1);
plot(t, x_true, 'b-', 'LineWidth',1.5, 'DisplayName','真实值');
hold on;
plot(t, x_meas, 'r.', 'MarkerSize',8, 'DisplayName','观测值');
plot(t, X_filter(1,:), 'g-', 'LineWidth',1.5, 'DisplayName','滤波值');
xlabel('时间 (s)'); ylabel('x 位置');
legend('Location','best'); grid on; title('x方向轨迹');

% 绘制y方向轨迹
subplot(2,1,2);
plot(t, y_true, 'b-', 'LineWidth',1.5, 'DisplayName','真实值');
hold on;
plot(t, y_meas, 'r.', 'MarkerSize',8, 'DisplayName','观测值');
plot(t, X_filter(3,:), 'g-', 'LineWidth',1.5, 'DisplayName','滤波值');
xlabel('时间 (s)'); ylabel('y 位置');
legend('Location','best'); grid on; title('y方向轨迹');