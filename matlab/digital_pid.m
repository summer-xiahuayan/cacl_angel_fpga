% 示例：阶跃响应测试
clear; clc;

% PID参数
Kp = 0.04;
Ki = 0.01;
Kd = 0;

% 仿真参数
N = 200;                  % 总步数
setpoint = 15.5; % 期望值固定为50
measured = 0;   % 初始测量值为0

u = 0;           % 控制量序列
sum_e = 0;                 % 积分累加和
e_prev = 0;                % e(n-1)，初始为0
e=0;

for n = 1:N
    e = setpoint - measured;   % 误差序列 e(n)
    sum_e = sum_e + e;
    
    % 按公式计算 u(n)
    term1 = (Kp + Kd) * e;
    term2 = Ki * sum_e;
    term3 = Kd * e_prev;
    u= term1 + term2 - term3;
    
    % 更新上一周期误差
    e_prev = e;
    measured=4*u;
    fprintf('u：%.4f\n', u);
end

