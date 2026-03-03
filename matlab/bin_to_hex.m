% 二进制文件转十六进制数的MATLAB脚本
% 配置参数
inputFilePath = 'D:\DLS\LIBEROPRO\cacl_angel\stimulus\kf_2d_xy_bin.txt';  % 输入二进制数据文件路径（需替换为你的文件路径）
outputFilePath = 'hex_result.txt'; % 输出十六进制结果的文件路径
isUppercase = true;                % 是否输出大写十六进制数

% 初始化结果存储
hexResults = {};  % 存储每行的十六进制结果
lineNumbers = []; % 存储有效行号

try
    % 1. 读取文件内容（按行读取）
    fid = fopen(inputFilePath, 'r');
    if fid == -1
        error('无法打开输入文件，请检查文件路径是否正确：%s', inputFilePath);
    end
    
    lineNum = 1;
    while ~feof(fid)
        % 读取一行并清理空白字符（去除换行、首尾空格）
        line = fgetl(fid);
        cleanLine = strtrim(line);
        
        % 跳过空行
        if isempty(cleanLine)
            lineNum = lineNum + 1;
            continue;
        end
        
        % 2. 处理二进制字符串（去除所有空格，拼接成完整16位）
        % 移除所有空格（适配"00000 00000 00 00 0 1"或"0000000000000001"格式）
        binaryStr = strrep(cleanLine, ' ', '');
        
        % 校验二进制字符串合法性（仅包含0和1）
     %   if ~all(ismember(binaryStr, {'0','1'}))
      %      warning('第%d行包含非二进制字符，已跳过：%s', lineNum, cleanLine);
       %     lineNum = lineNum + 1;
        %    continue;
        %end
        
        % 标准化为16位（不足补前导0，超过截取最后16位）
        binaryStr16 = char(zeros(1,16)); % 初始化16位字符数组
        len = length(binaryStr);
        if len <= 16
            % 不足16位：前导补0
            binaryStr16(16-len+1:16) = binaryStr;
            binaryStr16(1:16-len) = '0';
        else
            % 超过16位：截取最后16位
            binaryStr16 = binaryStr(end-15:end);
        end
        
        % 3. 二进制转十六进制
        % 先将二进制字符串转十进制数，再转十六进制字符串
        decVal = bin2dec(binaryStr16);
        hexStr = dec2hex(decVal, 4); % 4位十六进制（16位二进制对应4位十六进制）
        
        % 控制大小写
        if ~isUppercase
            hexStr = lower(hexStr);
        end
        
        % 4. 存储结果
        hexResults{end+1} = hexStr;
        lineNumbers(end+1) = lineNum;
        
        lineNum = lineNum + 1;
    end
    
    % 关闭输入文件
    fclose(fid);
    
    % 5. 输出结果（控制台+文件）
    % 控制台打印
    fprintf('转换完成！共处理%d行有效数据\n', length(hexResults));
    fprintf('前10行结果示例：\n');
    for i = 1:min(10, length(hexResults))
        fprintf('%s\n', lineNumbers(i), hexResults{i});
    end
    
    % 写入输出文件
    fidOut = fopen(outputFilePath, 'w');
    if fidOut == -1
        error('无法创建输出文件，请检查路径权限：%s', outputFilePath);
    end
    for i = 1:length(hexResults)
        fprintf(fidOut, '%s\n', hexResults{i});
    end
    fclose(fidOut);
    fprintf('结果已保存至：%s\n', outputFilePath);

catch ME
    % 异常处理
    fprintf('执行出错：%s\n', ME.message);
    if exist('fid', 'var') && fid ~= -1
        fclose(fid);
    end
    if exist('fidOut', 'var') && fidOut ~= -1
        fclose(fidOut);
    end
end