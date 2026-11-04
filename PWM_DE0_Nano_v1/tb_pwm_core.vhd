library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_pwm_core is end entity;

architecture sim of tb_pwm_core is
    signal clk : std_logic := '0';
    signal reset : std_logic := '1';
    signal finished : boolean := false;
    signal period_ticks, duty_ticks : unsigned(15 downto 0) := (others=>'0');
    signal pwm_out : std_logic;
begin
    clk <= not clk after 10 ns when not finished else '0';
    dut : entity work.pwm_core
        port map(clk, reset, period_ticks, duty_ticks, pwm_out);

    stimulus : process
        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;
        procedure configure(n,d : natural) is
        begin
            reset <= '1';
            period_ticks <= to_unsigned(n,16);
            duty_ticks <= to_unsigned(d,16);
            tick;
            assert pwm_out='0' report "Reset nao bloqueou" severity failure;
            wait until falling_edge(clk);
            reset <= '0';
        end procedure;
        procedure check_pwm(n,d : natural) is
            variable high_count : natural;
        begin
            configure(n,d);
            for cycle in 1 to 3 loop
                high_count := 0;
                for phase in 0 to n-1 loop
                    tick;
                    if phase < d then
                        assert pwm_out='1' report "Pulso alto incorreto" severity failure;
                    else
                        assert pwm_out='0' report "Pulso baixo incorreto" severity failure;
                    end if;
                    if pwm_out='1' then high_count:=high_count+1; end if;
                end loop;
                assert high_count=d report "Duty incorreto" severity failure;
            end loop;
        end procedure;
    begin
        for n in 2 to 24 loop
            for d in 0 to n loop check_pwm(n,d); end loop;
        end loop;
        check_pwm(1000,400);  -- 50 kHz, 40%, clock de 50 MHz
        check_pwm(65535,32768);
        check_pwm(65535,65535);
        -- Reset assincrono durante nivel alto.
        wait for 3 ns;
        reset <= '1'; wait for 1 ns;
        assert pwm_out='0' report "Reset assincrono falhou" severity failure;
        for bad in 0 to 2 loop
            case bad is
                when 0 => configure(0,0);
                when 1 => configure(1,0);
                when others => configure(10,11);
            end case;
            for k in 1 to 25 loop
                tick;
                assert pwm_out='0' report "Parametro invalido nao bloqueado" severity failure;
            end loop;
        end loop;
        report "PASS: periodo, duty, extremos, reset e parametros invalidos" severity note;
        finished <= true;
        wait;
    end process;
end architecture sim;
