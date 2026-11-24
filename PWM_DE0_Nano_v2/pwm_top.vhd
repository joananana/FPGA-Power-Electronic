
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pwm_top is
    port (
        CLOCK_50 : in  std_logic;
        KEY0     : in  std_logic;
        SW       : in  std_logic_vector(3 downto 0);
        PWM_OUT  : out std_logic
    );
end entity pwm_top;

architecture rtl of pwm_top is

    -- Periodo do PWM: 50 MHz / 1000 = 50 kHz
    constant PERIOD_TICKS : positive := 1000;

    -- Sincronizacao das chaves
    signal sw_meta : std_logic_vector(3 downto 0);
    signal sw_sync : std_logic_vector(3 downto 0);

    -- Sincronizacao do reset
    signal reset_sync : std_logic_vector(1 downto 0);
    signal reset_int  : std_logic;

    -- Comando de duty cycle
    signal duty_cmd : unsigned(15 downto 0);

begin

    --------------------------------------------------
    -- 1. Tratamento do reset
    --------------------------------------------------

    process(CLOCK_50, KEY0)
    begin
        if KEY0 = '0' then
            reset_sync <= (others => '1');

        elsif rising_edge(CLOCK_50) then
            reset_sync <= reset_sync(0) & '0';
        end if;
    end process;

    reset_int <= reset_sync(1);

    --------------------------------------------------
    -- 2. Sincronizacao das chaves DIP
    --------------------------------------------------

    process(CLOCK_50, reset_int)
    begin
        if reset_int = '1' then
            sw_meta <= (others => '0');
            sw_sync <= (others => '0');

        elsif rising_edge(CLOCK_50) then
            sw_meta <= SW;
            sw_sync <= sw_meta;
        end if;
    end process;

    --------------------------------------------------
    -- 3. Selecao do duty cycle
    --------------------------------------------------

    with sw_sync select
        duty_cmd <=
            to_unsigned(0,    16) when "0000",
            to_unsigned(100,  16) when "0001",
            to_unsigned(200,  16) when "0010",
            to_unsigned(300,  16) when "0011",
            to_unsigned(400,  16) when "0100",
            to_unsigned(500,  16) when "0101",
            to_unsigned(600,  16) when "0110",
            to_unsigned(700,  16) when "0111",
            to_unsigned(800,  16) when "1000",
            to_unsigned(900,  16) when "1001",
            to_unsigned(1000, 16) when "1010",
            to_unsigned(1,    16) when "1011",
            to_unsigned(250,  16) when "1100",
            to_unsigned(750,  16) when "1101",
            to_unsigned(999,  16) when "1110",
            to_unsigned(1200, 16) when "1111",
            to_unsigned(0,    16) when others;

    --------------------------------------------------
    -- 4. Instanciacao do modulador PWM V2
    --------------------------------------------------

    u_pwm : entity work.pwm_core
        generic map (
            PERIOD_TICKS => PERIOD_TICKS
        )
        port map (
            clk      => CLOCK_50,
            reset    => reset_int,
            duty_cmd => duty_cmd,
            pwm_out  => PWM_OUT
        );

end architecture rtl;
