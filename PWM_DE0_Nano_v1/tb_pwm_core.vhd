library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pwm_core is end entity;

architecture sim of tb_pwm_core is
    constant W : positive := 16;
    signal clk : std_logic := '0';
    signal done : boolean := false;
    signal reset : std_logic := '1';
    signal enable, mode : std_logic := '0';
    signal period_ticks, duty_ticks, deadtime_ticks : unsigned(W-1 downto 0)
        := (others => '0');
    signal a, b : std_logic;
begin
    clk <= not clk after 10 ns when not done else '0';
    dut : entity work.pwm_core
        generic map (WIDTH => W)
        port map (clk, reset, enable, mode, period_ticks, duty_ticks,
                  deadtime_ticks, a, b);

    -- Verificacao continua de exclusao mutua, inclusive entre clocks.
    monitor : process(a, b)
    begin
        assert not (a = '1' and b = '1')
            report "Sobreposicao entre as saidas" severity failure;
    end process;

    stimulus : process
        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;

        procedure configure(n, d, dt : natural; m : std_logic) is
        begin
            enable <= '0';
            period_ticks <= to_unsigned(n, W);
            duty_ticks <= to_unsigned(d, W);
            deadtime_ticks <= to_unsigned(dt, W);
            mode <= m;
            tick;
            assert a = '0' and b = '0' severity failure;
            enable <= '1';
        end procedure;

        -- Calcula uma sequencia de referencia por intervalos de fase e
        -- conta o tempo decorrido desde cada mudanca de comando.
        -- Compara cada amostra, cobrindo periodo, fase, largura e dead time.
        procedure check_wave(n, d, dt : natural; m : std_logic;
                             cycles : positive := 4) is
            variable target, previous : std_logic := '0';
            variable expected_a, expected_b : std_logic;
            variable age, phase, start_at : natural := 0;
        begin
            for k in 0 to cycles*n-1 loop
                phase := k mod n;
                if m = '0' then
                    start_at := 0;
                else
                    start_at := (n-d)/2;
                end if;
                target := '0';
                if phase >= start_at and phase < start_at+d then
                    target := '1';
                end if;
                if k = 0 or target /= previous then
                    age := 0;
                else
                    age := age+1;
                end if;
                expected_a := '0';
                expected_b := '0';
                if age >= dt then
                    expected_a := target;
                    expected_b := not target;
                end if;
                tick;
                assert a = expected_a and b = expected_b
                    report "Forma incorreta: N=" & integer'image(n) &
                    " D=" & integer'image(d) & " DT=" & integer'image(dt) &
                    " amostra=" & integer'image(k) severity failure;
                previous := target;
            end loop;
        end procedure;

        variable m : std_logic;
    begin
        wait for 3 ns;
        assert a = '0' and b = '0' severity failure;
        reset <= '0';

        -- Varredura de todos os duties, inclusive extremos, pulsos menores
        -- e iguais ao dead time, em ambos os modos e periodos distintos.
        for mi in 0 to 1 loop
            if mi = 0 then m := '0'; else m := '1'; end if;
            for n in 2 to 20 loop
                if m = '0' or n mod 2 = 0 then
                    for d in 0 to n loop
                        for dt in 0 to n-1 loop
                            configure(n,d,dt,m);
                            check_wave(n,d,dt,m);
                        end loop;
                    end loop;
                end if;
            end loop;
        end loop;

        -- Exemplo de 50 kHz, 40%, 1 us e periodo maximo de 16 bits.
        configure(1000,400,50,'0'); check_wave(1000,400,50,'0');
        configure(1000,400,50,'1'); check_wave(1000,400,50,'1');
        configure(65535,32767,7,'0'); check_wave(65535,32767,7,'0',2);
        configure(65534,32767,7,'1'); check_wave(65534,32767,7,'1',2);

        -- Entradas alteradas durante operacao devem ser ignoradas.
        configure(10,4,1,'0'); check_wave(10,4,1,'0');
        period_ticks <= to_unsigned(20,W);
        duty_ticks <= to_unsigned(15,W);
        deadtime_ticks <= to_unsigned(3,W);
        mode <= '1';
        -- Primeira amostra e uma nova transicao de B para A.
        check_wave(10,4,1,'0');

        -- Disable bloqueia no proximo clock; habilitar inicia nova fase.
        enable <= '0'; tick;
        assert a = '0' and b = '0' severity failure;
        enable <= '1'; check_wave(20,15,3,'1');

        -- Reset entre bordas deve desligar sem esperar novo clock.
        configure(10,10,0,'0'); tick;
        assert a = '1' and b = '0' severity failure;
        wait for 3 ns; reset <= '1'; wait for 1 ns;
        assert a = '0' and b = '0' severity failure;
        reset <= '0'; tick;
        assert a = '0' and b = '0' severity failure;

        -- Configuracoes invalidas permanecem bloqueadas.
        for bad in 0 to 4 loop
            case bad is
                when 0 => configure(0,0,0,'0');
                when 1 => configure(1,0,0,'0');
                when 2 => configure(10,11,0,'0');
                when 3 => configure(10,4,10,'0');
                when others => configure(9,4,0,'1');
            end case;
            for k in 0 to 25 loop
                tick;
                assert a = '0' and b = '0'
                    report "Configuracao invalida nao bloqueada" severity failure;
            end loop;
        end loop;
        report "PASS: formas, limites, dead time, reset e enable verificados"
            severity note;
        done <= true;
        wait;
    end process;
end architecture;
