% 读取CX/CY数据并转换为16位有符号数（公式：sign*(X/5)*32768）
% 适配卡尔曼滤波/ASIC测试，包含边界截断、结果保存、可视化验证

%% 1. 配置参数（可根据实际需求调整）
cx_file = 'cx_filter.txt';       % CX数据文件路径
cy_file = 'cy_filter.txt';       % CY数据文件路径
scale_factor = 32768/5;   % 缩放系数 = 32768/5（公式简化）
int16_min = -32768;       % 16位有符号数最小值
int16_max = 32767;        % 16位有符号数最大值

%% 2. 读取CX/CY原始数据（带异常处理）
fprintf('正在读取CX/CY数据文件...\n');
% 读取CX数据
if ~exist(cx_file, 'file')
    error('未找到CX文件：%s，请检查文件路径！', cx_file);
end
cx_raw = importdata(cx_file);
if isempty(cx_raw)
    error('CX文件%s读取为空，请检查文件格式！', cx_file);
end

% 读取CY数据
if ~exist(cy_file, 'file')
    error('未找到CY文件：%s，请检查文件路径！', cy_file);
end
cy_raw = importdata(cy_file);
if isempty(cy_raw)
    error('CY文件%s读取为空，请检查文件格式！', cy_file);
end

% 统一数据长度（取较短的长度，避免维度不匹配）
len = min(length(cx_raw), length(cy_raw));
cx_raw = cx_raw(1:len);
cy_raw = cy_raw(1:len);
fprintf('成功读取CX/CY数据，有效数据长度：%d\n', len);

%% 3. 核心：按公式转换为16位有符号数（含边界截断）
fprintf('正在按公式 sign*(X/5)*32768 转换为16位有符号数...\n');
% 转换CX（公式：cx_int16 = sign(cx_raw) * (cx_raw/5) * 32768 → 简化为 cx_raw * scale_factor）
cx_int16 = cx_raw * scale_factor;
% 截断超出16位有符号数范围的值（关键：避免溢出）
cx_int16(cx_int16 < int16_min) = int16_min;
cx_int16(cx_int16 > int16_max) = int16_max;
% 转换为整数类型（可选，若需要纯整数而非浮点数）
cx_int16 = round(cx_int16);  % 四舍五入
cx_int16 = int16(cx_int16);  % 强制转换为16位有符号整数

% 转换CY（同CX逻辑）
cy_int16 = cy_raw * scale_factor;
cy_int16(cy_int16 < int16_min) = int16_min;
cy_int16(cy_int16 > int16_max) = int16_max;
cy_int16 = round(cy_int16);
cy_int16 = int16(cy_int16);

%% 4. 保存转换后的数据（文本格式，便于ASIC/卡尔曼滤波调用）
% 保存CX转换结果
fid_cx = fopen('cx_filter_int16.txt', 'w');
if fid_cx == -1
    error('无法创建cx_int16.txt，请检查路径权限！');
end
for i = 1:len
    fprintf(fid_cx, '%d\n', cx_int16(i));  % 保存为整数，无科学计数法
end
fclose(fid_cx);

% 保存CY转换结果
fid_cy = fopen('cy_filter_int16.txt', 'w');
if fid_cy == -1
    error('无法创建cy_int16.txt，请检查路径权限！');
end
for i = 1:len
    fprintf(fid_cy, '%d\n', cy_int16(i));
end
fclose(fid_cy);

fprintf('转换后的数据已保存：\n');
fprintf(' - CX 16位有符号数：cx_int16.txt\n');
fprintf(' - CY 16位有符号数：cy_int16.txt\n');

%% 5. 统计信息打印（验证转换结果）
fprintf('\n=== 转换统计信息 ===\n');
fprintf('CX原始数据范围：%.4f ~ %.4f\n', min(cx_raw), max(cx_raw));
fprintf('CX转换后范围：%d ~ %d（16位有符号数）\n', min(cx_int16), max(cx_int16));
fprintf('CY原始数据范围：%.4f ~ %.4f\n', min(cy_raw), max(cy_raw));
fprintf('CY转换后范围：%d ~ %d（16位有符号数）\n', min(cy_int16), max(cy_int16));

% 计算转换误差（验证公式正确性）
cx_convert_back = double(cx_int16) / scale_factor;  % 反向转换验证
cy_convert_back = double(cy_int16) / scale_factor;
cx_mse = mean((cx_raw - cx_convert_back).^2);
cy_mse = mean((cy_raw - cy_convert_back).^2);
fprintf('CX转换反向误差（MSE）：%.6f\n', cx_mse);
fprintf('CY转换反向误差（MSE）：%.6f\n', cy_mse);

%% 6. 可视化对比（原始数据 vs 转换后数据）
figure('Color','white','Position',[100,100,1000,600]);

% 子图1：CX对比
subplot(2,1,1);
plot(1:len, cx_raw, 'b-', 'LineWidth',1.2, 'DisplayName','CX原始数据'); hold on;
plot(1:len, cx_convert_back, 'r--', 'LineWidth',1.2, 'DisplayName','CX转换后（反向还原）');
xlabel('数据点序号', 'FontSize',11);
ylabel('数值', 'FontSize',11);
title('CX原始数据 vs 16位有符号数转换后（反向还原）', 'FontSize',12, 'FontWeight','bold');
legend('Location','best', 'FontSize',10);
grid on; grid minor;

% 子图2：CY对比
subplot(2,1,2);
plot(1:len, cy_raw, 'g-', 'LineWidth',1.2, 'DisplayName','CY原始数据'); hold on;
plot(1:len, cy_convert_back, 'm--', 'LineWidth',1.2, 'DisplayName','CY转换后（反向还原）');
xlabel('数据点序号', 'FontSize',11);
ylabel('数值', 'FontSize',11);
title('CY原始数据 vs 16位有符号数转换后（反向还原）', 'FontSize',12, 'FontWeight','bold');
legend('Location','best', 'FontSize',10);
grid on; grid minor;

% 解决中文乱码
try
    set(gca, 'FontName','SimHei');
    set(findall(gcf, 'Type','Text'), 'FontName','SimHei');
catch
    set(gca, 'FontName','Arial');
    set(findall(gcf, 'Type','Text'), 'FontName','Arial');
    title('CX Raw Data vs 16-bit Signed Int (Converted Back)', 'FontSize',12, 'FontWeight','bold');
end

fprintf('\n所有操作完成！');