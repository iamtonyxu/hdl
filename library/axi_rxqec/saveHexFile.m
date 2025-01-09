function [] = saveHexFile(x, xFile, type)
if type == 0
    DATA_WIDTH = 32;
    % save data
    x_hex = zeros(length(x)/2, 1);
    for index=0:length(x)/2-1
        x0 = real(x(index*2 + 1));
        x1 = real(x(index*2 + 2));
        
        if x0 < 0
            x0 = 2^(DATA_WIDTH/2) + floor(x0*2^(DATA_WIDTH/2-1));
        elseif x0 >= 1
            x0 = 2^(DATA_WIDTH/2-1) - 1;
        else
            x0 = floor(x0*2^(DATA_WIDTH/2-1));
        end
        
        if x1 < 0
            x1 = 2^(DATA_WIDTH/2) + floor(x1*2^(DATA_WIDTH/2-1));
        elseif x1 >= 1
            x1 = 2^(DATA_WIDTH/2-1) - 1;
        else
            x1 = floor(x1*2^(DATA_WIDTH/2-1));
        end
        
        x_hex(index+1) = bitshift(x1, DATA_WIDTH/2) + x0;
    end
else
    DATA_WIDTH = 16;
    % save data
    x_hex = zeros(length(x), 1);
    for index=1:length(x)
        x0 = real(x(index));
        
        if x0 < 0
            x0 = 2^(DATA_WIDTH) + floor(x0*2^(DATA_WIDTH-1));
        elseif x0 >= 1
            x0 = 2^(DATA_WIDTH-1) - 1;
        else
            x0 = floor(x0*2^(DATA_WIDTH-1));
        end
        
        x_hex(index) = x0;
    end
end

fileID = fopen(xFile, 'w');
fprintf(fileID,'%x\n', x_hex);
fclose(fileID);

end

