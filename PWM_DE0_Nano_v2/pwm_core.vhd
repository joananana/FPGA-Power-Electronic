library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- PWM com periodo fixo e duty atualizado somente na virada do periodo.
-- Premissa: duty_cmd e gerado no mesmo dominio de clk (e permanece estavel
-- durante setup/hold na borda de amostragem).
entity pwm_core is
    generic (
        PERIOD_TICKS : positive := 1000  -- 50 MHz / 1000 = 50 kHz
    );
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;  -- ativo em '1', assercao assincrona
        duty_cmd  : in  unsigned(15 downto 0); -- 0 ate PERIOD_TICKS
        pwm_out   : out std_logic
    );
end entity pwm_core;

architecture rtl of pwm_core is
    constant PERIOD_LAST : unsigned(15 downto 0) :=
        to_unsigned(PERIOD_TICKS - 1, 16);
    constant PERIOD_MAX : unsigned(15 downto 0) :=
        to_unsigned(PERIOD_TICKS, 16);

    signal counter     : unsigned(15 downto 0);
    signal duty_active : unsigned(15 downto 0);
begin
    assert PERIOD_TICKS >= 2 and PERIOD_TICKS <= 65535
        report "PERIOD_TICKS deve estar entre 2 e 65535"
        severity failure;

    process(clk, reset)
        variable new_duty : unsigned(15 downto 0);
    begin
        if reset = '1' then
            -- Deixa o contador pronto para iniciar um periodo na primeira
            -- borda de subida apos a liberacao sincronizada do reset.
            counter     <= PERIOD_LAST;
            duty_active <= (others => '0');
            pwm_out     <= '0';
        elsif rising_edge(clk) then
            if counter = PERIOD_LAST then
                -- Fronteira do periodo: captura o comando mais recente.
                if duty_cmd > PERIOD_MAX then
                    new_duty := PERIOD_MAX;  -- satura em 100%
                else
                    new_duty := duty_cmd;
                end if;

                counter     <= (others => '0');
                duty_active <= new_duty;

                -- Valor da saida para o tick 0 do NOVO periodo.
                if new_duty /= to_unsigned(0, 16) then
                    pwm_out <= '1';
                else
                    pwm_out <= '0';
                end if;
            else
                counter <= counter + 1;

                -- Valor da saida para o PROXIMO tick do periodo atual.
                -- duty_active nao e alterado durante o periodo.
                if (counter + 1) < duty_active then
                    pwm_out <= '1';
                else
                    pwm_out <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
