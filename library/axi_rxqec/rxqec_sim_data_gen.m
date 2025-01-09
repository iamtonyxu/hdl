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
x = (rand(DATA_LENGTH, 1) - 0.5) + 1j*(rand(DATA_LENGTH, 1) - 0.5);

% filter
x_q = conv(hq, imag(x));
x_q = x_q(Q_TAPS_SIDE+1 : end - Q_TAPS_SIDE);

x_i = conv(hi, real(x));
x_i = x_i(I_TAPS_SIDE+1 : end - I_TAPS_SIDE);

figure;
subplot(3,1,1);
plot(imag(x), 'b'); title('image(x)');
subplot(3,1,2);
plot(x_q, 'r'); title('x_q before adding x_i');
subplot(3,1,3);
plot(x_i, 'k'); title('x_i');

y = real(x) + 1j*(x_q + x_i);

% save data
if ~exist('mt_din_i.txt')
    saveHexFile(hq, 'mt_hq.txt', 1);
    saveHexFile(hi, 'mt_hi.txt', 1);

    saveHexFile(real(x), 'mt_din_i.txt', 0);
    saveHexFile(imag(x), 'mt_din_q.txt', 0);

    saveHexFile(real(y), 'mt_dout_i.txt', 0);
    saveHexFile(imag(y), 'mt_dout_q.txt', 0);

    saveHexFile(x_i, 'mt_x_i.txt', 0);
    saveHexFile(x_q, 'mt_x_q.txt', 0);
end
