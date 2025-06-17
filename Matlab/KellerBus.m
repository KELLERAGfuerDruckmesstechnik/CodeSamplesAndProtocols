classdef KellerBus < handle
    properties
        serial_obj
        echo = false

    end
    
    methods
        %% PORT-FUNCTIONS        
        function open_comm_port(self, port, baud, echo)
            arguments(Input)
                self
                port string
                baud double
                echo = false
            end
            
            self.serial_obj= serialport(port, baud, Parity = "none", DataBits = 8, StopBits = 1, FlowControl = "none", ByteOrder = "big-endian", Timeout = 0.5);
            self.echo = echo;
        end

        function close_comm_port(self)
            arguments(Input)
                self
            end        
            if isa(self.serial_obj, 'internal.Serialport')
                delete(self.serial_obj)
                self.serial_obj = [];
            end
        end

        %% Function 30: Read Coefficients in IEEE754 format
        function value = f30(self, address, coeff_no)
            % """Function F30: Read Coefficients in IEEE754 format
            % 
            % :param address: Device address
            % :param coeff_no: Coefficient number to read
            % :return: value: floating point
            % """
            arguments(Input)
                self
                address (1,1) uint8
                coeff_no (1,1) uint8
            end
            arguments(Output)
                value single
            end

            command = uint8([address, 30, coeff_no]);
            answer = self.send_receive(command, 8);
            value = typecast(uint8(answer(3:6)), 'single'); % Convert to single-precision float
            value = swapbytes(value); % Ensure big-endian format
        end
        %% Function 31: Write Coefficients
        function f31(self, address, coeff_no, value)
            % Function 31: Write Coefficients
            %
            % :param address: Device address (uint8)
            % :param coeff_no: Coefficient number (uint8)
            % :param value: Floating-point value to write
            arguments
                self
                address (1,1) uint8
                coeff_no (1,1) uint8
                value (1,1) single % Ensure value is a single-precision float
            end
        
            command = uint8([address, 31, coeff_no]);
            % Convert float to 4-byte IEEE-754 big-endian representation
            value_bytes = typecast(swapbytes(value), 'uint8');
            command = [command, value_bytes];
            self.send_receive(command, 5);
        end
        %% Function 32: Read Out Configuration
        function value = f32(self, address, coeff_no)
            % Function 32: Read Out Configuration
            %
            % :param address: Device address 
            % :param coeff_no: Index to read 
            % :return value: 16-bit integer
            arguments
                self
                address (1,1) uint8
                coeff_no (1,1) uint8
            end
        
            command = uint8([address, 32, coeff_no]);
            answer = self.send_receive(command, 5);
            value = uint16(answer(3));
        end
        %% Function 33: Write Configuration
        function f33(self, address, coeff_no, value)
            % Function 33: Write Configuration
            %
            % :param address: Device address 
            % :param coeff_no: Index to write 
            % :param value: Value to write (uint8, max 255)
            arguments
                self
                address (1,1) uint8
                coeff_no (1,1) uint8
                value (1,1) uint8 {mustBeLessThan(value, 256)} % Ensures value < 256
            end
        
            command = uint8([address, 33, coeff_no, value]);
            self.send_receive(command, 5);
        end
        %% Function 48: Initialise and Release
        function firmwareStr = f48(self, address)
            % Function 48: Initialise and Release
            %
            % :param address: Device address (uint8)
            % :return firmwareStr: Firmware version as a string
            arguments
                self
                address (1,1) uint8
            end
        
            command = uint8([address, 48]);
            answer = self.send_receive(command, 10);
        
            % Extract firmware information
            firmware_class = answer(3);
            firmware_group = answer(4);
            firmware_year  = answer(5);
            firmware_week  = answer(6);
        
            % Format as string: "class.group-year.week"
            firmwareStr = sprintf("%d.%d-%d.%d", firmware_class, firmware_group, firmware_year, firmware_week);
        end
        %% Function 66: Write and Read New Device Address
        function new_address_from_device = f66(self, address, new_address)
            % Function 66: Write and Read New Device Address
            %
            % :param address: Old device address (uint8)
            % :param new_address: New device address (uint8)
            % :return: Confirmed new device address (uint8)
            
            arguments(Input)
                self
                address (1,1) uint8
                new_address (1,1) uint8 {mustBeGreaterThan(new_address, 0), mustBeLessThan(new_address, 256)}
            end
            arguments(Output)
                new_address_from_device (1,1) uint8
            end
            if new_address == 0 && address ~= 250
                error("Incorrect new address for Device. Must be greater than 0.");
            end
        
            command = uint8([address, 66, new_address]);
            answer = self.send_receive(command, 5);
            new_address_from_device = answer(3);
        
            % Check if new address was correctly updated
            if new_address_from_device ~= new_address && address ~= 250
                error("Device address %d is already in use.", new_address);
            end
        end
        %% Function 69: Read serial number
        function serial_nr = f69(self, address)
            % Function 69: Read Serial Number
            %
            % :param address: Device address (uint8)
            % :return serial_nr: Serial number of the device (uint32)
            arguments(Input)
                self
                address (1,1) uint8 % Ensure address is a single uint8 value
            end
            arguments(Output)
                serial_nr uint32
            end
        
            % Construct the command
            command = uint8([address, 69]);
        
            % Send command and receive response (expecting 8 bytes)
            answer = self.send_receive(command, 8);
        
            % Convert bytes 3 to 6 into a uint32 number (big-endian)
            serial_nr = typecast(uint8(answer(3:6)), 'uint32');
            serial_nr = swapbytes(serial_nr); % Ensure big-endian order
        end
        %% Function 73: Read Value of a Channel (Floating Point)
        function value = f73(self, address, channel)
            % Function 73: Read Value of a Channel (Floating Point)
            %
            % :param address: Device address (uint8)
            % :param channel: Channel ID (uint8) - 0:CH0, 1:P1, 2:P2, 3:T, 4:TOB1, 5:TOB2, 10:ConTc, 11:ConRaw
            % :return: value (float)
            arguments(Input)
                self
                address (1,1) uint8
                channel (1,1) uint8 {mustBeLessThan(channel, 256)}
            end
            arguments(Output)
                value single
            end
        
            command = uint8([address, 73, channel]);
            answer = self.send_receive(command, 9);
            value = typecast(uint8(answer(3:6)), 'single');
            value = swapbytes(value); % big-endian order
        end
        %% Function 74: Read Value of a Channel (32-bit Integer)
        function value = f74(self, address, channel)
            % Function 74: Read Value of a Channel (32-bit Integer)
            %
            % :param address: Device address (uint8)
            % :param channel: Channel ID (uint8)
            % :return: value (int32)
            arguments
                self
                address (1,1) uint8
                channel (1,1) uint8 {mustBeLessThan(channel, 256)}
            end
        
            command = uint8([address, 74, channel]);
            answer = self.send_receive(command, 9);       
            value = typecast(uint8(answer(3:6)), 'int32');
            value = swapbytes(value); % big-endian order
        end
        
        %% Function 95: Commands for Setting the Zero Point
        function f95(self, address, cmd, value)
            % Function 95: Commands for Setting the Zero Point
            %
            % :param address: Device address (uint8)
            % :param cmd: Command type (uint8)
            % :param value: (Optional) Floating point value
            arguments
                self
                address (1,1) uint8
                cmd (1,1) uint8 {mustBeLessThan(cmd, 256)}
                value (1,1) single = NaN
            end
        
            command = uint8([address, 95, cmd]);
            if ~isnan(value)
                value_bytes = typecast(single(value), 'uint32'); %    
                value_bytes = swapbytes(value_bytes); % convert to big-endian
                value_bytes = typecast(value_bytes, 'uint8'); % Convert to 4-byte array
                command = [command, value_bytes];
            end
            self.send_receive(command, 5);
        end
        
        %% Function 100: Read Configuration
        function answer = f100(self, address, index)
            % Function 100: Read Configuration
            %
            % :param address: Device address (uint8)
            % :param index: Parameter index (uint8)
            % :return: 5-byte response
            arguments
                self
                address (1,1) uint8
                index (1,1) uint8 {mustBeLessThan(index, 256)}
            end
        
            command = uint8([address, 100, index]);
            answer = self.send_receive(command, 9);
            answer = answer(3:7);
        end
        
        %% Function 101: Write Configuration
        function f101(self, address, index, b0, b1, b2, b3, b4)
            % Function 101: Write Configuration
            %
            % :param address: Device address (uint8)
            % :param index: Parameter index (uint8)
            % :param b0-b4: Configuration values (uint8)
            arguments
                self
                address (1,1) uint8
                index (1,1) uint8 {mustBeLessThan(index, 256)}
                b0 (1,1) uint8 {mustBeLessThan(b0, 256)}
                b1 (1,1) uint8 {mustBeLessThan(b1, 256)}
                b2 (1,1) uint8 {mustBeLessThan(b2, 256)}
                b3 (1,1) uint8 {mustBeLessThan(b3, 256)}
                b4 (1,1) uint8 {mustBeLessThan(b4, 256)}
            end
        
            command = uint8([address, 101, index, b0, b1, b2, b3, b4]);
            self.send_receive(command, 5);
        end

        %% CRC16-CALCULATION
        function crc = crc16(self, data, byte_count, offset)
            arguments(Input)
                self
                data (1,:) uint8 % Ensure 'data' is a row vector of uint8 values
                byte_count {mustBeInteger, mustBeNonnegative} % Number of bytes to process
                offset {mustBeInteger, mustBeNonnegative} = 0 % Optional offset (default 0)
            end
            arguments(Output)
                crc (1,2) uint8
            end
        
            % 8-bit MODBUS crc Calculation
            crc = uint16(hex2dec('FFFF')); % Initial value 0xFFFF
            CRC_poly = uint16(hex2dec('A001')); % Polynomial 0xA001
        
            % Ensure offset + byte_count does not exceed data length
            if offset + byte_count > length(data)
                error('Offset and byte count exceed data length.');
            end
        
            % crc calculation loop
            for i = 1 : byte_count
                crc = bitxor(crc, uint16(data(i + offset))); % XOR with input byte
                for k = 1:8
                    if bitand(crc, hex2dec('0001')) % Check LSB
                        crc = bitsrl(crc, 1);
                        crc = bitxor(crc, CRC_poly);
                    else
                        crc = bitsrl(crc, 1);
                    end
                end
            end
        
            % Convert to byte array [high byte, low byte]
            crc = [bitshift(crc, -8), bitand(crc, 255)]; 
        end

        %% SEND AND RECEIVE
        function answer = send_receive(self, command, read_byte_count)
            % """send a command and receive a message
            % 
            % :param command: sending command
            % :param read_byte_count: amount of bytes to send
            % :return: answer from the device
            % """
            arguments
                self
                command (1,:) uint8
                read_byte_count {mustBeInteger, mustBeNonnegative}
            end

            crc = self.crc16(command, length(command));
            command = [command, crc];

            % Flush input buffer
            if ~isa(self.serial_obj, 'internal.Serialport')
                error("Serial port is not initialized.");
            else
                flush(self.serial_obj, "input")
            end
            
            try
                % Write command to serial port
                write(self.serial_obj, command, "uint8");
        
                % If echo is enabled, read echo response
                if self.echo
                    echo_answer = read(self.serial_obj, length(command), "uint8");
                    if ~isequal(command, echo_answer)
                        error("Echo not present");
                    end
                end
        
                % Read response from device
                % TODO: answer datatype
                answer = read(self.serial_obj, read_byte_count, "uint8");
        
                % Check if answer is empty (no response)
                if isempty(answer)
                    error("Device with address %d did not respond", command(1));
                end
        
                % Verify CRC16 of the response
                self.RaiseOnCRC16Mismatch(answer);
        
                % Check for device error (if second byte > 127)
                if answer(2) > 127
                    error("Device Error number: %d", answer(2));
                end
        
            catch ME
                error("Error in sending/reading Keller Protocol: %s", ME.message);
            end
        end

        %% Check CRC16 Mismatch
        function RaiseOnCRC16Mismatch(self, buffer)
            % """Check if the Correct CRC16 was sent/received
            % 
            % :param buffer: Message to check the CRC16
            % """
    
            arguments(Input)
                self
                buffer (1,:) uint8
            end
    
            % Extract the last two bytes as the received CRC16
            buffer_crc16 = buffer(end-1:end); 
        
            % Extract the message without the CRC16 bytes
            buffer_without_crc16 = buffer(1:end-2);
        
            % Compute the expected CRC16
            crc_calc = self.crc16(buffer_without_crc16, length(buffer_without_crc16));
        
            % Compare received CRC16 with calculated CRC16
            if ~isequal(buffer_crc16, crc_calc)
                error("CRC16 Error: Expected [%02X %02X] but got [%02X %02X]", ...
                    buffer_crc16(1), buffer_crc16(2), crc_calc(1), crc_calc(2));
            end
        end

    end

end