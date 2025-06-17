classdef TestKellerProtocol < matlab.unittest.TestCase
    properties
        bus
        address = uint8(1)  % Device address
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            % Setup - Run once before all tests
            fprintf("Initializing Keller Protocol...\n");
            testCase.bus = KellerBus;
            testCase.bus.open_comm_port("COM4", 9600);
            testCase.bus.f48(testCase.address); % Initialize device
        end
    end

    methods (TestClassTeardown)
        function teardownOnce(testCase)
            % Teardown - Run once after all tests
            fprintf("Closing communication port...\n");
            testCase.bus.close_comm_port(); % Close the serial port
        end
    end

    methods (Test)
        function testF48(testCase)
            % Test F48: Read Firmware Version
            firmware = testCase.bus.f48(testCase.address);
            fprintf("Firmware Version: %s\n", firmware);
            testCase.assertNotEmpty(firmware, "Firmware should not be empty");
        end

        function testF30F31SetGainFactor(testCase)
            % Test F30 & F31: Read & Set Gain Factor
            pressure_gain = testCase.bus.f30(testCase.address, 65);
            fprintf("F30: Read Gain Factor: %.3f\n", pressure_gain);

            new_gain_factor = single(2.1);
            fprintf("F31: Set Gain Factor to %.1f\n", new_gain_factor);
            testCase.bus.f31(testCase.address, 65, new_gain_factor);
            
            gain_factor = testCase.bus.f30(testCase.address, 65);
            testCase.verifyEqual(round(gain_factor,1), new_gain_factor, ...
                "Gain factor mismatch!");

            % Reset gain factor
            fprintf("Reset Gain Factor to %.3f\n", pressure_gain);
            testCase.bus.f31(testCase.address, 65, pressure_gain);
        end

        function testF32ReadTempInt(testCase)
            % Test F32: Read Minimal interframe timeout
            minimal_interframe_timeout_default = uint16(35);
            minimal_interframe_timeout = testCase.bus.f32(testCase.address, 25);
            fprintf("F32: Minimal interframe timeout: %d ms\n", minimal_interframe_timeout);
            testCase.assertEqual(minimal_interframe_timeout, minimal_interframe_timeout_default, "Default Minimal interframe timeout: 35 ms");
        end

        function testF66SetReadAddress(testCase)
            % Test F66: Change Device Address
            new_address = uint8(101);
            fprintf("F66: Setting new address to %d\n", new_address);
            received_address = testCase.bus.f66(testCase.address, new_address);

            testCase.assertEqual(received_address, new_address, "Address mismatch!");

            % Reset to original address
            fprintf("F66: Reset address to %d\n", testCase.address);
            testCase.bus.f66(new_address, testCase.address);
        end

        function testF69ReadSerial(testCase)
            % Test F69: Read Serial Number
            fprintf("F69: Reading Serial Number...\n");
            serial_number = testCase.bus.f69(testCase.address);
            fprintf("Serial Number: %d\n", serial_number);
            testCase.assertNotEmpty(serial_number, "Serial Number should not be empty");
        end

        function testF73ReadTOB1(testCase)
            % Test F73: Read temperature from channel 4 (TOB1)
            temperature = testCase.bus.f73(testCase.address, 4);
            fprintf("F73: TOB1 Temperature: %.3f\n", temperature);

            low_temp = 15;
            high_temp = 30;
            testCase.assertGreaterThan(temperature, low_temp, ...
                sprintf("Temperature below %.1f°C: %.3f", low_temp, temperature));
            testCase.assertLessThan(temperature, high_temp, ...
                sprintf("Temperature above %.1f°C: %.3f", high_temp, temperature));
        end

        function testF74ReadTOB1(testCase)
            % Test F74: Read temperature (integer format) from channel 4
            temperature = testCase.bus.f74(testCase.address, 4);
            fprintf("F74: TOB1 Integer Temperature: %d\n", temperature);

            low_temp = 1500;
            high_temp = 3000;
            testCase.assertGreaterThan(temperature, low_temp, ...
                sprintf("Temperature too low: %d", temperature));
            testCase.assertLessThan(temperature, high_temp, ...
                sprintf("Temperature too high: %d", temperature));
        end

        function testF95SetZeroP1(testCase)
            % Test F95: Set zero point for P1
            fprintf("F95: Setting Zero Point for P1\n");
            testCase.bus.f95(testCase.address, 0);
            p1 = testCase.bus.f73(testCase.address, 1);
            fprintf("F95: P1 Value: %.3f\n", p1);

            p_min = -0.001;
            p_max = 0.001;
            testCase.assertGreaterThan(p1, p_min, ...
                sprintf("P1 below min threshold: %.3f", p1));
            testCase.assertLessThan(p1, p_max, ...
                sprintf("P1 above max threshold: %.3f", p1));

            % Reset to standard value
            fprintf("F95: Resetting Zero Point for P1\n");
            testCase.bus.f95(testCase.address, 1);
        end

        function testF95SetToValueP1(testCase)
            % Test F95: Set P1 to a specific value
            target_pressure = 2.5;
            fprintf("F95: Setting P1 Zero Point to %.1f bar\n", target_pressure);
            testCase.bus.f95(testCase.address, 0, single(target_pressure));
            
            p1 = testCase.bus.f73(testCase.address, 1);
            fprintf("F95: Read P1 Value: %.3f\n", p1);

            threshold = 0.001;
            testCase.assertGreaterThan(p1, target_pressure - threshold, ...
                sprintf("P1 below target: %.3f", p1));
            testCase.assertLessThan(p1, target_pressure + threshold, ...
                sprintf("P1 above target: %.3f", p1));

            % Reset to standard value
            fprintf("F95: Resetting Zero Point for P1\n");
            testCase.bus.f95(testCase.address, 1);
        end

        function testF100ReadBaud(testCase)
            % Test F100: Read Baud Configuration
            data = testCase.bus.f100(testCase.address, 0);
            fprintf("F100: Baud Configuration: %s\n", mat2str(data));
            testCase.assertEqual(data(2), 0, ...
                "Expected UART setting: 1 (9600 Baud, no parity, 1 stop bit)");
        end
    end
end
