close all;
clear all;
clc;

Q_TAPS_SIDE = 7; 
I_TAPS_SIDE = 3;
DATA_LENGTH = 1024;

Q_TAPS = Q_TAPS_SIDE * 2 + 1;
I_TAPS = I_TAPS_SIDE * 2 + 1;

% generate filter coeffs
if 1
    hq = ones(Q_TAPS, 1);
    hq(1:Q_TAPS_SIDE) = rand(Q_TAPS_SIDE, 1)-0.5;
    hq(Q_TAPS_SIDE + 1 + (1:Q_TAPS_SIDE)) = hq(Q_TAPS_SIDE:-1:1);
    hq = hq ./ 2; % scale down in case of saturation while simulation

    hi = ones(I_TAPS, 1);
    hi(1:I_TAPS_SIDE) = rand(I_TAPS_SIDE, 1)-0.5;
    hi(I_TAPS_SIDE + 1 + (1:I_TAPS_SIDE)) = hi(I_TAPS_SIDE:-1:1);
    hi = hi ./ 10; % scale down in case of saturation while simulation
else
    hq = zeros(Q_TAPS, 1);
    hq(Q_TAPS_SIDE+1) = 1;

    hi = zeros(I_TAPS, 1);
    hi(I_TAPS_SIDE+1) = 1;
end

% generate input signal
x = rand(DATA_LENGTH, 1) - 0.5;
%x = ones(DATA_LENGTH, 1)./2;

% filter
x_q = conv(hq, x);
x_q = x_q(Q_TAPS_SIDE+1 : end - Q_TAPS_SIDE);

x_i = conv(hi, x);
x_i = x_i(I_TAPS_SIDE+1 : end - I_TAPS_SIDE);

figure;
subplot(3,1,1);
plot(x, 'b'); title('raw data: x');
subplot(3,1,2);
plot(x_q, 'r'); title('qfilter output');
subplot(3,1,3);
plot(x_i, 'k'); title('ifilter output');

% save data
if ~exist('hi.txt')
    saveHexFile(hq, 'hq.txt', 1);
    saveHexFile(hi, 'hi.txt', 1);
    saveHexFile(x, 'x.txt', 0);
    saveHexFile(x_q, 'x_q.txt', 0);
    saveHexFile(x_i, 'x_i.txt', 0);
end
