library ieee;
library utils;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;
use utils.char.all;

entity notice_board is
generic(line_size : integer := 16);
port(
    clk, btn0, btn1, btn2, reset, line1_en, line2_en, override: in std_logic;
    line1_led, line2_led, override_led: out std_logic;
    lcd_rs, lcd_r_w, lcd_en, lcd_on, lcd_blon: out std_logic;
    lcd_db: out std_logic_vector(7 downto 0);
    hex0, hex1, hex2, hex3, hex4, hex5, hex6, hex7: out std_logic_vector(6 downto 0);
    char_sw : in std_logic_vector(6 downto 0);
    char_led : out std_logic_vector(6 downto 0);
    ledg : out std_logic_vector(7 downto 0)
);
end notice_board;

architecture synth of notice_board is

type lcd_state_t is (start, clear, idle, delay, send, write_s, line2);

constant clk_freq : integer := 50_000_000;
constant clk_us : integer := 50;  -- 1us = 50 * 20ns
constant clk_ms : integer := 50_000;  -- 1ms = 50,000 * 20ns

signal clk_count : integer := 0;
signal lcd_line1 : string (1 to line_size) := "Welcome to the  ";
signal lcd_line2 : string (1 to line_size) := "Group 4 project ";

begin
    lcd_blon <= '1';
    lcd_on <= '1';

    -- Display group number "grp4" on a common-cathode 7-segment display
    --       abcdefg
    hex7 <= "1111111";
    hex6 <= "1111111";
    hex5 <= "1111111";
    hex4 <= "1111111";
    hex3 <= "0000100";  -- g
    hex2 <= "1111010";  -- r
    hex1 <= "0011000";  -- p
    hex0 <= "1001100";  -- 4

    char_led <= char_sw;
    line1_led <= line1_en;
    line2_led <= line2_en;
    override_led <= override;

    process(clk, btn0, btn1, btn2, reset)

        variable lcd_state : lcd_state_t;
        variable lcd_delay_prev_state : lcd_state_t;
        variable lcd_send_prev_state: lcd_state_t;

        variable lcd_send_stage : integer;
        variable lcd_clear_stage : integer := 0;
        variable lcd_start_stage : integer := 0;

        variable lcd_data : std_logic_vector(7 downto 0);
        variable lcd_char_bits : std_logic_vector(7 downto 0);
        variable lcd_char_index : integer := 0;
        variable lcd_delay : integer;

        variable arg_integer : integer;
        variable arg_logic_vec : std_logic_vector(7 downto 0);

        variable line1_ptr : integer := 1;
        variable line2_ptr : integer := 1;

        variable btn_press : std_logic := '0';
        variable sw_press : std_logic := '0';

        procedure lcd_delay_us(variable duration : in integer) is
        begin
            lcd_delay := duration * clk_us;
            lcd_delay_prev_state := lcd_state;
            lcd_state := delay;
        end lcd_delay_us;

        procedure lcd_delay_ms(variable duration : in integer) is
        begin
            lcd_delay := duration * clk_ms;
            lcd_delay_prev_state := lcd_state;
            lcd_state := delay;
        end lcd_delay_ms;

        procedure lcd_send_ir(variable data : in std_logic_vector(7 downto 0)) is
        begin
            lcd_rs <= '0'; lcd_r_w <= '0';
            lcd_data := data;
            lcd_send_prev_state := lcd_state;
            lcd_state := send;
            lcd_send_stage := 0;
        end lcd_send_ir;

        procedure lcd_send_dr(variable data : in std_logic_vector(7 downto 0)) is
        begin
            lcd_rs <= '1'; lcd_r_w <= '0';
	    lcd_data := data;
            lcd_send_prev_state := lcd_state;
            lcd_state := send;
	    lcd_send_stage := 0;
        end lcd_send_dr;

        procedure lcd_write is
        begin
            if (lcd_state = idle) then
                lcd_state := write_s;
                lcd_char_index := 0;
            end if;
        end lcd_write;

        procedure lcd_clear is
        begin
            if (lcd_state = idle) then
                lcd_state := clear;
                lcd_clear_stage := 0;
            end if;
        end lcd_clear;

        procedure lcd_main is
        begin
            case lcd_state is

                when start =>
                    ledg <= "00000001";
                    if (lcd_start_stage = 0) then
                        arg_integer := 5;
                        lcd_delay_ms(arg_integer);
                        lcd_start_stage := 1;
                    else
                        lcd_state := clear;
                    end if;

                when delay =>
                    ledg <= "10000000";
                    if (lcd_delay > 0) then
                        lcd_delay := lcd_delay - 1;
                    else
                        lcd_state := lcd_delay_prev_state;
                    end if;

                when idle =>
                    ledg <= "01000000";
                    lcd_state := idle;

                when send =>
                    ledg <= "00100000";
                    case lcd_send_stage is
                        when 0 =>
                            arg_integer := 1;
                            lcd_delay_us(arg_integer);  -- delay_addr_setup
                        when 1 =>
                            lcd_en <= '1';
                            arg_integer := 1;
                            lcd_delay_us(arg_integer);  -- delay_data_delay
                        when 2 =>
                            lcd_db <= lcd_data;
                        when 3 =>
                            arg_integer := 1;
                            lcd_delay_us(arg_integer);  -- delay_data_setup
                        when 4 =>
                            lcd_en <= '0';
                            arg_integer := 5;
                            lcd_delay_ms(arg_integer);  -- delay_hold
                        when others =>
                            lcd_state := lcd_send_prev_state;
                    end case;
                    lcd_send_stage := lcd_send_stage + 1;

                when write_s =>
                    ledg <= "00010000";
                    if (lcd_char_index = 0) then
                        arg_logic_vec := "10000000";
                        lcd_send_ir(arg_logic_vec);  -- Set cursor to beginning of line 1
                    elsif (lcd_char_index > line_size) then
                        lcd_char_index := -1;
                        lcd_state := line2;
                    else
                        lcd_char_bits := char_to_bits(lcd_line1(lcd_char_index));
                        lcd_send_dr(lcd_char_bits);  -- Send next character
                    end if;
                    lcd_char_index := lcd_char_index + 1;

                 when line2 =>
                    ledg <= "00001000";
                    if (lcd_char_index = 0) then
                        arg_logic_vec := "10101000";
                        lcd_send_ir(arg_logic_vec);  -- Set cursor to beginning of line 2
                    elsif (lcd_char_index > line_size) then
                        lcd_state := idle;
                    else
                        lcd_char_bits := char_to_bits(lcd_line2(lcd_char_index));
                        lcd_send_dr(lcd_char_bits);  -- Send next character
                    end if;
                    lcd_char_index := lcd_char_index + 1;

                when clear =>
                    ledg <= "00000100";
                    if (lcd_clear_stage = 0) then
                        arg_logic_vec := "00000001";
                        lcd_send_ir(arg_logic_vec);
                        lcd_clear_stage := 1;
                    else
                        lcd_state := idle;
                    end if;

            end case;
        end lcd_main;

        begin

        if (clk'event and clk = '1') then
            if (clk_count = clk_freq - 1) then
                clk_count <= 0;
            else
                clk_count <= clk_count + 1;
            end if;

            lcd_main;  -- LCD operations

            if (reset = '0' and btn_press = '0') then  -- reset
                line1_ptr := 1;
                line2_ptr := 1;
                lcd_line1 <= "Welcome to the  ";
                lcd_line2 <= "Group 4 project ";
                lcd_write;

            elsif (btn1 = '0' and btn_press = '0') then  -- clear display
                lcd_clear;
                line1_ptr := 1;
                line2_ptr := 1;
                lcd_line1 <= "                ";
                lcd_line2 <= "                ";

            elsif (override = '1') then  -- display custom message

                if (btn0 = '0' and btn_press = '0') then  -- input character
                    if (line1_en = '1' and line1_ptr <= line_size) then
                        lcd_line1(line1_ptr) <= bits_to_char(char_sw);
                        line1_ptr := line1_ptr + 1;
                    elsif (line2_en = '1' and line2_ptr <= line_size) then
                        lcd_line2(line2_ptr) <= bits_to_char(char_sw);
                        line2_ptr := line2_ptr + 1;
                    end if;
                    lcd_write;

                elsif (btn2 = '0' and btn_press = '0') then  -- backspace
                    if (line1_en = '1' and line1_ptr > 1) then
                        line1_ptr := line1_ptr - 1;
                        lcd_line1(line1_ptr) <= ' ';
                    elsif (line2_en = '1' and line2_ptr > 1) then
                        line2_ptr := line2_ptr - 1;
                        lcd_line2(line2_ptr) <= ' ';
                    end if;
                    lcd_write;

                end if;

            elsif (override = '0') then  -- display pre-defined message

                if (char_sw(0) = '1' and sw_press = '0') then
                    lcd_line1 <= "Monday:         ";
                    lcd_line2 <= "Task 1          ";
                    lcd_write;

                elsif (char_sw(1) = '1' and sw_press = '0') then
                    lcd_line1 <= "Tuesday:        ";
                    lcd_line2 <= "Task 2          ";
                    lcd_write;

                elsif (char_sw(2) = '1' and sw_press = '0') then
                    lcd_line1 <= "Wednesday:      ";
                    lcd_line2 <= "Task 3          ";
                    lcd_write;

                elsif (char_sw(3) = '1' and sw_press = '0') then
                    lcd_line1 <= "Thursday:       ";
                    lcd_line2 <= "Task 4          ";
                    lcd_write;

                elsif (char_sw(4) = '1' and sw_press = '0') then
                    lcd_line1 <= "Friday:         ";
                    lcd_line2 <= "Task 5          ";
                    lcd_write;

                end if;

                line1_ptr := 1;
                line2_ptr := 1;

            end if;

            if (reset = '1' and btn0 = '1' and btn1 = '1' and btn2 = '1') then
                btn_press := '0';
            else
                btn_press := '1';
            end if;

            if (override = '0' and char_sw(4 downto 0) = "00000") then
                sw_press := '0';
            else
                sw_press := '1';
            end if;

        end if;

    end process;

end synth;
