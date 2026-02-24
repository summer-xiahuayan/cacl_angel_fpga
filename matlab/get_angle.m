% 绘制原始轨迹图并计算角度，同时保存角度数据为txt
% 适配所有MATLAB版本，兼容低版本语法

%% 1. 读取原始数据（替换为你的实际文件路径）
cx_raw = importdata('cx_normalized.txt');  % 横坐标数据
cy_raw = importdata('cy_normalized.txt');  % 纵坐标数据

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

%% 3. 核心：根据cx/cy计算角度（弧度+角度制）
% 角度定义：以原点为中心，cx为x轴，cy为y轴，计算与x轴正方向的夹角
% arctan2(cy, cx) 避免atan的象限问题，范围[-π, π]
angle_rad = atan2(cy_raw, cx_raw);  % 弧度制角度（每个点的角度）
angle_deg = rad2deg(angle_rad);     % 转换为角度制（-180°~180°）
% 转换为0°~360°范围（更符合直观认知）
angle_deg_360 = mod(angle_deg, 360);

%% 4. 保存角度数据为txt文件（核心新增）
% 定义保存路径（可自行修改）
save_path = '.';  % 当前目录，如需保存到指定文件夹改为：'D:/trajectory_data'

% 方式1：单独保存0~360°角度文件（每行一个角度值）
angle_filename = fullfile(save_path, 'angle_deg_360.txt');
dlmwrite(angle_filename, angle_deg_360, 'delimiter', '\n', 'precision', 9);

% 方式2：保存弧度制角度文件

%angle_rad_filename = fullfile(save_path, 'angle_rad.txt');
%dlmwrite(angle_rad_filename, angle_rad, 'delimiter', '\n', 'precision', 8);

% 方式3：保存组合文件（cx, cy, 角度(0~360°)），逗号分隔，方便Excel打开
%combo_filename = fullfile(save_path, 'cx_cy_angle.txt');
%combo_data = [cx_raw, cy_raw, angle_deg_360];  % 列1:cx, 列2:cy, 列3:角度
% 写入表头+数据（增强可读性）



%% 5. 绘制轨迹+角度可视化
figure('Color','white','Position',[100,100,1000,600]);  

% 分两个子图：轨迹图 + 角度变化曲线
subplot(1,2,1);  % 1行2列，第1个子图（轨迹）
plot(cx_raw, cy_raw, 'b-o', 'LineWidth',1.2, 'MarkerSize',4, 'MarkerFaceColor','b');
xlabel('cx (横坐标)', 'FontSize',11);
ylabel('cy (纵坐标)', 'FontSize',11);
title('原始轨迹图 (cx-cy)', 'FontSize',12, 'FontWeight','bold');
grid on;          
grid minor;       
axis equal;       % 保证轨迹比例不失真
box on;          
% 标注起点/终点角度
text(cx_raw(1), cy_raw(1), sprintf('起点角度：%.1f°', angle_deg_360(1)), ...
    'FontSize',9, 'Color','red', 'VerticalAlignment','bottom');
text(cx_raw(end), cy_raw(end), sprintf('终点角度：%.1f°', angle_deg_360(end)), ...
    'FontSize',9, 'Color','red', 'VerticalAlignment','top');

subplot(1,2,2);  % 1行2列，第2个子图（角度变化）
plot(1:len_final, angle_deg_360, 'r-', 'LineWidth',1.2);
xlabel('数据点序号', 'FontSize',11);
ylabel('角度 (°)', 'FontSize',11);
title('轨迹角度变化曲线 (0°~360°)', 'FontSize',12, 'FontWeight','bold');
grid on;
grid minor;
ylim([0, 360]);  % 限定角度范围0~360°
box on;
% 标注角度均值/方差
mean_angle = mean(angle_deg_360);
var_angle = var(angle_deg_360);
text(len_final*0.7, 300, sprintf('均值角度：%.1f°\n角度方差：%.2f', mean_angle, var_angle), ...
    'FontSize',9, 'Color','blue', 'Background','white');

% 兼容中文显示（低版本MATLAB适配）
try
    set(gcf, 'DefaultAxesFontName','SimHei');  % 全局设置中文字体
catch
    set(gcf, 'DefaultAxesFontName','Arial');   % 低版本切换英文
    % 子图1英文标注
    subplot(1,2,1);
    xlabel('cx (X Coordinate)', 'FontSize',11);
    ylabel('cy (Y Coordinate)', 'FontSize',11);
    title('Raw Trajectory (cx-cy)', 'FontSize',12, 'FontWeight','bold');
    text(cx_raw(1), cy_raw(1), sprintf('Start Angle: %.1f°', angle_deg_360(1)), ...
        'FontSize',9, 'Color','red', 'VerticalAlignment','bottom');
    text(cx_raw(end), cy_raw(end), sprintf('End Angle: %.1f°', angle_deg_360(end)), ...
        'FontSize',9, 'Color','red', 'VerticalAlignment','top');
    % 子图2英文标注
    subplot(1,2,2);
    xlabel('Data Point Index', 'FontSize',11);
    ylabel('Angle (°)', 'FontSize',11);
    title('Trajectory Angle Curve (0°~360°)', 'FontSize',12, 'FontWeight','bold');
    text(len_final*0.7, 300, sprintf('Mean Angle: %.1f°\nAngle Variance: %.2f', mean_angle, var_angle), ...
        'FontSize',9, 'Color','blue', 'Background','white');
end

%% 6. 输出轨迹+角度基础信息
% 轨迹信息
traj_length = 0;
for i = 2:len_final
    dx = cx_raw(i) - cx_raw(i-1);
    dy = cy_raw(i) - cy_raw(i-1);
    traj_length = traj_length + sqrt(dx^2 + dy^2);
end
var_cx = var(cx_raw);
var_cy = var(cy_raw);

% 角度信息
max_angle = max(angle_deg_360);
min_angle = min(angle_deg_360);
mean_angle = mean(angle_deg_360);
var_angle = var(angle_deg_360);

% 打印结果
fprintf('\n==================== 轨迹信息 ====================\n');
fprintf('原始轨迹总长度：%.4f\n', traj_length);
fprintf('cx方差（抖动）：%.6f，cy方差（抖动）：%.6f\n', var_cx, var_cy);
fprintf('==================== 角度信息 ====================\n');
fprintf('角度范围：%.1f° ~ %.1f°\n', min_angle, max_angle);
fprintf('均值角度：%.1f°，角度方差（抖动）：%.2f\n', mean_angle, var_angle);
fprintf('起点角度（0~360°）：%.1f°，终点角度（0~360°）：%.1f°\n', ...
    angle_deg_360(1), angle_deg_360(end));