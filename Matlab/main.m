clear all; clc;
%% Test Keller Protocol
results = runtests('TestKellerProtocol');

%% Example usage:
keller = KellerBus;
device_address = uint8(1); % default

keller.open_comm_port("COM4",9600);

serial_number = keller.f69(device_address);
fprintf("Serial number: %d\n", serial_number);
fprintf("Press CTRL + C to quit\n");

while true
    p1 = keller.f73(device_address, 1);
    tob1 = keller.f73(device_address, 4);
    fprintf("Pressure P1: %.3f mBar, Temperature TOB1: %.3f\n", p1, tob1);
    pause(0.001)
end