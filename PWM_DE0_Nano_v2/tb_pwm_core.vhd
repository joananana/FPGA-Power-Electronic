library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pwm_core is
end entity tb_pwm_core;

architecture sim of tb_pwm_core is
    constant TEST_PERIOD : natural := 1000; -- 50 MHz / 1000 = 50 kHz

    signal clk       : std_logic := '0';
    signal reset     : std_logic := '1';
    signal duty_cmd  : unsigned(15 downto 0) := to_unsigned(400, 16);
    signal pwm_out   : std_logic;
    signal finished  : boolean := false;
begin
    -- Clock de 50 MHz; para ao terminar os testes.
    clk <= not clk after 10 ns when not finished else '0';

    dut : entity work.pwm_core
        generic map (PERIOD_TICKS => TEST_PERIOD)
        port map (
            clk      => clk,
            reset    => reset,
            duty_cmd => duty_cmd,
            pwm_out  => pwm_out
        );

    stimulus : process
        variable active_duty : natural;
        variable high_count  : natural;

        procedure check_level(cycle, phase, duty : natural) is
            variable expected : std_logic;
        begin
            if phase < duty then
                expected := '1';
            else
                expected := '0';
            end if;

            assert pwm_out = expected
                report "PWM incorreto: ciclo=" & integer'image(cycle) &
                       " fase=" & integer'image(phase) &
                       " duty_esperado=" & integer'image(duty)
                severity failure;
        end procedure;

        procedure next_tick(cycle, phase, duty : natural) is
        begin
            wait until rising_edge(clk);
            wait for 1 ns; -- aguarda a atualizacao dos sinais registrados
            check_level(cycle, phase, duty);
        end procedure;

    begin
        -- Verifica reset inicial e libera em uma borda de descida.
        wait for 2 ns;
        assert pwm_out = '0'
            report "Falha no reset inicial" severity failure;
        wait until falling_edge(clk);
        reset <= '0';

        -- Cada ciclo corresponde a um periodo PWM de 1000 clocks.
        for cycle in 0 to 12 loop
            case cycle is
                when 0  => active_duty := 400;  -- 40%
                when 1  => active_duty := 700;  -- 70%
                when 2  => active_duty := 200;  -- 20%
                when 3  => active_duty := 0;    -- 0%
                when 4  => active_duty := 1000; -- 100%
                when 5  => active_duty := 1000; -- comando 1200 saturado
                when 6  => active_duty := 400;  -- ultimo comando vence
                when 7  => active_duty := 500;  -- comando alterado na mesma borda
                when 8  => active_duty := 0;    -- novo comando so no proximo periodo
                when 9  => active_duty := 1000; -- comando 1 ns antes da virada
                when 10 => active_duty := 1;    -- menor pulso nao nulo
                when 11 => active_duty := 999;  -- quase 100%
                when others => active_duty := 1000; -- comando 65535 saturado
            end case;

            high_count := 0;

            for phase in 0 to TEST_PERIOD - 1 loop
                if cycle = 7 and phase = 0 then
                    -- Nova entrada escrita NA MESMA borda de captura.
                    -- O DUT deve amostrar o valor anterior (500).
                    wait until rising_edge(clk);
                    duty_cmd <= to_unsigned(0, 16);
                    wait for 1 ns;
                    check_level(cycle, phase, active_duty);
                else
                    next_tick(cycle, phase, active_duty);
                end if;

                if pwm_out = '1' then
                    high_count := high_count + 1;
                end if;

                -- Altera o comando SEM reset, em varias fases do periodo.
                -- A saida deve seguir active_duty ate a proxima virada.
                case cycle is
                    when 0 =>
                        if phase = 200 then
                            duty_cmd <= to_unsigned(900, 16);
                        elsif phase = 600 then
                            duty_cmd <= to_unsigned(700, 16);
                        end if;
                    when 1 =>
                        if phase = 998 then
                            duty_cmd <= to_unsigned(200, 16);
                        end if;
                    when 2 =>
                        if phase = 1 then
                            duty_cmd <= to_unsigned(0, 16);
                        end if;
                    when 3 =>
                        if phase = 500 then
                            duty_cmd <= to_unsigned(1000, 16);
                        end if;
                    when 4 =>
                        if phase = 999 then
                            duty_cmd <= to_unsigned(1200, 16);
                        end if;
                    when 5 =>
                        if phase = 200 then
                            duty_cmd <= to_unsigned(200, 16);
                        elsif phase = 950 then
                            duty_cmd <= to_unsigned(400, 16);
                        end if;
                    when 6 =>
                        if phase = 998 then
                            duty_cmd <= to_unsigned(500, 16);
                        end if;
                    when 8 =>
                        if phase = TEST_PERIOD - 1 then
                            -- Ajuste 1 ns ANTES da proxima borda de subida.
                            wait for 18 ns;
                            duty_cmd <= to_unsigned(1000, 16);
                        end if;
                    when 9 =>
                        if phase = 100 then
                            duty_cmd <= to_unsigned(1, 16);
                        end if;
                    when 10 =>
                        if phase = 100 then
                            duty_cmd <= to_unsigned(999, 16);
                        end if;
                    when 11 =>
                        if phase = 200 then
                            duty_cmd <= to_unsigned(65535, 16);
                        end if;
                    when others => null;
                end case;
            end loop;

            assert high_count = active_duty
                report "Quantidade de clocks altos incorreta no ciclo=" &
                       integer'image(cycle)
                severity failure;
        end loop;

        -- Reset assincrono enquanto a saida esta em nivel alto (100%).
        wait for 3 ns;
        reset <= '1';
        wait for 1 ns;
        assert pwm_out = '0'
            report "Reset assincrono nao desligou a saida" severity failure;

        -- Mesmo com clock e mudanca de comando, reset deve manter PWM=0.
        duty_cmd <= to_unsigned(250, 16);
        for k in 1 to 3 loop
            wait until rising_edge(clk);
            wait for 1 ns;
            assert pwm_out = '0'
                report "PWM ativo durante reset" severity failure;
        end loop;

        -- Retoma com o duty novo, sem pulso parcial na inicializacao.
        wait until falling_edge(clk);
        reset <= '0';
        high_count := 0;
        for phase in 0 to TEST_PERIOD - 1 loop
            next_tick(13, phase, 250);
            if pwm_out = '1' then
                high_count := high_count + 1;
            end if;
        end loop;
        assert high_count = 250
            report "Duty incorreto apos liberar reset" severity failure;

        report "PASS: sincronismo, mudancas multiplas, fronteira, saturacao, extremos e reset"
            severity note;
        finished <= true;
        wait;
    end process;
end architecture sim;
