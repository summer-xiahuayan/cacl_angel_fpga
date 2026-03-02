% 绘制原始轨迹图（cx为横坐标，cy为纵坐标）
% 适配所有MATLAB版本，兼容低版本语法

%% 1. 读取原始数据（替换为你的实际文件路径）
cx_raw = importdata('cx_filter.txt');  % 横坐标数据
cy_raw = importdata('cy_filter.txt');  % 纵坐标数据

%% 2. 数据合法性检查（避免绘图报错）
len_cx = length(cx_raw);
len_cy = length(cy_raw);

if len_cx ~= len_cy
    warning('cx长度(%d)与cy长度(%d)不一致！已自动截断至较短长度', len_cx, len_cy);
    len_final = min(len_cx, len_cy);
    cx_raw = cx_raw(1:len_final);
    cy_raw = cy_raw(1:len_final);
else
    len_final = len_cx;
end

%% 3. 绘制原始轨迹（核心代码）
figure('Color','white','Position',[100,100,800,600]);  % 白色背景，指定窗口大小
% 绘制轨迹：蓝色实线+圆形标记，线条/标记大小适中
plot(cx_raw, cy_raw, 'b-o', 'LineWidth',1.2, 'MarkerSize',4, 'MarkerFaceColor','b');

%% 4. 可视化优化（提升可读性）
xlabel('cx (横坐标)', 'FontSize',11);
ylabel('cy (纵坐标)', 'FontSize',11);
title('滤波后轨迹图 (cx-cy)', 'FontSize',12, 'FontWeight','bold');

grid on;          % 显示网格
grid minor;       % 显示细网格
axis equal;       % 关键：保证横纵坐标比例一致，轨迹不失真
box on;           % 显示坐标轴边框

% 兼容中文显示（低版本MATLAB适配）
try
    set(gca, 'FontName','SimHei');  % 适配中文
catch
    set(gca, 'FontName','Arial');   % 低版本无中文字体则用英文
    xlabel('cx (X Coordinate)', 'FontSize',11);
    ylabel('cy (Y Coordinate)', 'FontSize',11);
    title('Raw Trajectory (cx-cy)', 'FontSize',12, 'FontWeight','bold');
end

%% 5. 可选：输出轨迹基础信息
% 计算轨迹总长度（欧式距离累加）
traj_length = 0;
for i = 2:len_final
    dx = cx_raw(i) - cx_raw(i-1);
    dy = cy_raw(i) - cy_raw(i-1);
    traj_length = traj_length + sqrt(dx^2 + dy^2);
end
% 计算坐标方差（反映抖动程度）
var_cx = var(cx_raw);
var_cy = var(cy_raw);

fprintf('原始轨迹总长度：%.4f\n', traj_length);
fprintf('cx方差（抖动）：%.6f，cy方差（抖动）：%.6f\n', var_cx, var_cy);