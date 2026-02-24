% 基于FFT结果对cx_int16/cy_int16进行归一化：减直流分量 + 乘归一化系数
% 归一化逻辑：normalized_data = (raw_data - dc) * (1/peak_amp)
% 注：若需缩放到其他范围（如16位有符号数范围），可修改归一化系数

%% 1. 配置参数（直接填入FFT计算得到的结果）
cx_file = 'cx_int16.txt';   % CX原始数据文件
cy_file = 'cy_int16.txt';   % CY原始数据文件
% FFT计算得到的直流分量和最高频率峰值（替换为你的实际结果）
cx_dc = 17685;           % CX直流分量
cx_peak_amp = 5255;      % CX最高频率峰值幅值
cy_dc = 16800;           % CY直流分量        
cy_peak_amp = 4990;      % CY最高频率峰值幅值

% 归一化系数（可自定义，默认1/峰值幅值，缩放到[-1,1]）
cx_norm_coeff = cy_peak_amp;  
cy_norm_coeff = cx_peak_amp;
% 若需缩放到16位有符号数范围（-32768~32767），改用：
% cx_norm_coeff = 32767 / cx_peak_amp;
% cy_norm_coeff = 32767 / cy_peak_amp;



%% 3. 读取原始数据（可选：截取3800点后的数据）
fprintf('正在读取16位有符号数原始数据...\n');
cx_data = read_int16_file(cx_file);
cy_data = read_int16_file(cy_file);



%% 4. 核心：执行归一化计算
fprintf('正在执行数据归一化...\n');
% CX归一化：先减直流分量，再乘归一化系数
cx_normalized = ((cx_data - cx_dc) .* cx_norm_coeff)/2^10;
% CY归一化
cy_normalized = ((cy_data - cy_dc) .* cy_norm_coeff)/2^10;

% 可选：若需转换为16位有符号整数（四舍五入+边界截断）
% cx_normalized = round(cx_normalized);
% cx_normalized(cx_normalized < -32768) = -32768;
% cx_normalized(cx_normalized > 32767) = 32767;
% cx_normalized = int16(cx_normalized);
% 
% cy_normalized = round(cy_normalized);
% cy_normalized(cy_normalized < -32768) = -32768;
% cy_normalized(cy_normalized > 32767) = 32767;
% cy_normalized = int16(cy_normalized);

%% 5. 保存归一化后的数据（无科学计数法）
% 保存CX归一化结果
fid_cx = fopen('cx_normalized.txt', 'w');
if fid_cx == -1
    error('无法创建cx_normalized.txt，请检查权限！');
end
for i = 1:length(cx_normalized)
    fprintf(fid_cx, '%.10f\n', cx_normalized(i)); % 保留10位小数，无科学计数法
end
fclose(fid_cx);

% 保存CY归一化结果
fid_cy = fopen('cy_normalized.txt', 'w');
if fid_cy == -1
    error('无法创建cy_normalized.txt，请检查权限！');
end
for i = 1:length(cy_normalized)
    fprintf(fid_cy, '%.10f\n', cy_normalized(i));
end
fclose(fid_cy);

%% 6. 打印归一化统计信息（验证结果）
fprintf('\n==================== 归一化结果统计 ====================\n');
fprintf('【CX 归一化后】\n');
fprintf(' - 均值（理论应为0）：%.6f\n', mean(cx_normalized));
fprintf(' - 最大值：%.6f\n', max(cx_normalized));
fprintf(' - 最小值：%.6f\n', min(cx_normalized));
fprintf(' - 峰峰值：%.6f\n', max(cx_normalized) - min(cx_normalized));

fprintf('\n【CY 归一化后】\n');
fprintf(' - 均值（理论应为0）：%.6f\n', mean(cy_normalized));
fprintf(' - 最大值：%.6f\n', max(cy_normalized));
fprintf(' - 最小值：%.6f\n', min(cy_normalized));
fprintf(' - 峰峰值：%.6f\n', max(cy_normalized) - min(cy_normalized));

fprintf('\n归一化后数据已保存：\n');
fprintf(' - CX归一化结果：cx_normalized.txt\n');
fprintf(' - CY归一化结果：cy_normalized.txt\n');
fprintf('所有归一化操作完成！');


%% 2. 通用整数文件读取函数（复用，确保数据读取正确）
function data = read_int16_file(file_path)
    data = [];
    fid = fopen(file_path, 'r');
    if fid == -1
        error('无法打开文件：%s，请检查权限！', file_path);
    end
    
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line) && ~isempty(line)
            line_stripped = strtrim(line);
            if ~isempty(line_stripped)
                val = str2double(line_stripped);
                if ~isnan(val)
                    data = [data; round(val)]; % 确保为整数
                end
            end
        end
    end
    fclose(fid);
    data=data;
    if isempty(data)
        error('文件%s无有效整数数据！', file_path);
    end
end