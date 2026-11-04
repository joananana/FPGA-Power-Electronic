library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- PWM de dente de serra, uma saida, sem prescaler nem tempo morto.
-- Manter os parametros estaveis enquanto reset = '0'.
entity pwm_core is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;  -- ativo alto
        period_ticks : in  unsigned(15 downto 0);
        duty_ticks   : in  unsigned(15 downto 0);
        pwm_out      : out std_logic
    );
end entity pwm_core;

architecture rtl of pwm_core is
    signal counter : unsigned(15 downto 0);
begin
    process(clk, reset)
    begin
        if reset = '1' then
            counter <= (others => '0');
            pwm_out <= '0';
        elsif rising_edge(clk) then
            -- Periodo minimo de 2 clocks e duty entre zero e o periodo.
            if period_ticks >= 2 and duty_ticks <= period_ticks then
                if counter >= period_ticks - 1 then
                    counter <= (others => '0');
                else
                    counter <= counter + 1;
                end if;

                -- Usa a contagem anterior a borda, como as atribuicoes
                -- de sinais de um processo sequencial em VHDL.
                if counter < duty_ticks then
                    pwm_out <= '1';
                else
                    pwm_out <= '0';
                end if;
            else
                counter <= (others => '0');
                pwm_out <= '0';
            end if;
        end if;
    end process;
end architecture rtl;
