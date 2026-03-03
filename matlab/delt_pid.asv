% 示例：阶跃响应测试
clear; clc;

% PID参数
A = 0.04;
B = 0.01;
C = 0;

% 仿真参数
N = 2000;                  % 总步数
setpoint = 15.5; % 期望值固定为50
measured = 0;   % 初始测量值为0

u = 0;           % 控制量序列
e1= 0;                 % 积分累加和
e2= 0;                % e(n-1)，初始为0
e3=0;

for n = 1:N
    e3=e2;
    e2=e1;
    e1 = setpoint - measured;   % 误差序列 e(n) 
    delt_u=A*e1+B*e2+C*e3;
    u= u+delt_u;
    measured=u^3;
    fprintf('u：%.6f\n', u);
end

