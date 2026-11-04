library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- PWM independente. Todas as entradas, exceto a assercao de reset,
-- devem estar sincronizadas ao clk. Configurar com enable = '0'.
entity pwm_core is
    generic (WIDTH : positive := 16);
    port (
        clk            : in  std_logic;
        reset          : in  std_logic;  -- ativo alto; assercao assincrona
        enable         : in  std_logic;  -- habilitacao sincrona
        carrier_mode   : in  std_logic;  -- 0: borda; 1: centro (triangular)
        period_ticks   : in  unsigned(WIDTH-1 downto 0);
        duty_ticks     : in  unsigned(WIDTH-1 downto 0);
        deadtime_ticks : in  unsigned(WIDTH-1 downto 0);
        pwm_a          : out std_logic;
        pwm_b          : out std_logic
    );
end entity;

architecture rtl of pwm_core is
    signal period_reg, duty_reg, dead_reg : unsigned(WIDTH-1 downto 0)
        := (others => '0');
    signal mode_reg, valid_reg : std_logic := '0';
    signal phase : unsigned(WIDTH-1 downto 0) := (others => '0');
    signal raw_pwm : std_logic;
    signal a_reg, b_reg : std_logic := '0';
    signal pending : std_logic := '0';
    signal last_target : std_logic := '0';
    signal remaining : unsigned(WIDTH-1 downto 0) := (others => '0');
begin
    assert WIDTH >= 2 report "WIDTH deve ser >= 2" severity failure;

    pwm_a <= a_reg;
    pwm_b <= b_reg;

    -- 1. Configuracao e contador: sem clocks derivados ou prescaler.
    -- Um periodo tem exatamente period_reg ciclos, em ambos os modos.
    p_counter : process(clk, reset)
    begin
        if reset = '1' then
            period_reg <= (others => '0');
            duty_reg <= (others => '0');
            dead_reg <= (others => '0');
            mode_reg <= '0';
            valid_reg <= '0';
            phase <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '0' then
                period_reg <= period_ticks;
                duty_reg <= duty_ticks;
                dead_reg <= deadtime_ticks;
                mode_reg <= carrier_mode;
                phase <= (others => '0');
                -- Periodo >= 2, duty em [0, periodo], dead time < periodo.
                -- No modo centralizado, periodo par para duas metades iguais.
                valid_reg <= '0';
                if period_ticks >= 2 and duty_ticks <= period_ticks and
                   deadtime_ticks < period_ticks then
                    if carrier_mode = '0' or
                       (carrier_mode = '1' and period_ticks(0) = '0') then
                        valid_reg <= '1';
                    end if;
                end if;
            elsif valid_reg = '1' then
                if phase = period_reg - 1 then
                    phase <= (others => '0');
                else
                    phase <= phase + 1;
                end if;
            else
                phase <= (others => '0');
            end if;
        end if;
    end process;

    -- 2. Modulacao. No modo triangular, produz o pulso centralizado
    -- equivalente, usando limites de fase em vez de outro contador up/down.
    -- Ex.: N=1000,D=400 => intervalo [300,700). Duty impar tem assimetria
    -- de um clock entre as margens, mas preserva exatamente a largura D.
    p_modulator : process(phase, period_reg, duty_reg, mode_reg, valid_reg)
        variable pulse_start, pulse_end : unsigned(WIDTH-1 downto 0);
    begin
        raw_pwm <= '0';
        pulse_start := (others => '0');
        pulse_end := (others => '0');
        if valid_reg = '1' then
            if mode_reg = '0' then
                if phase < duty_reg then
                    raw_pwm <= '1';
                end if;
            else
                pulse_start := shift_right(period_reg - duty_reg, 1);
                pulse_end := pulse_start + duty_reg;
                if phase >= pulse_start and phase < pulse_end then
                    raw_pwm <= '1';
                end if;
            end if;
        end if;
    end process;

    -- 3. Saidas registradas e tempo morto por atraso de ligamento.
    -- Uma troca desliga ambas nesta borda e espera dead_reg clocks.
    -- Se a referencia mudar antes do ligamento, o pulso e suprimido.
    -- Na partida tambem se espera o tempo morto antes de ligar uma saida.
    p_outputs : process(clk, reset)
    begin
        if reset = '1' then
            a_reg <= '0';
            b_reg <= '0';
            pending <= '0';
            last_target <= '0';
            remaining <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '0' or valid_reg = '0' then
                a_reg <= '0';
                b_reg <= '0';
                pending <= '0';
                last_target <= '0';
                remaining <= (others => '0');
            elsif dead_reg = 0 then
                a_reg <= raw_pwm;
                b_reg <= not raw_pwm;
                pending <= '0';
                last_target <= raw_pwm;
                remaining <= (others => '0');
            elsif pending = '0' or raw_pwm /= last_target then
                a_reg <= '0';
                b_reg <= '0';
                pending <= '1';
                last_target <= raw_pwm;
                remaining <= dead_reg;
            elsif remaining > 1 then
                remaining <= remaining - 1;
            else
                remaining <= (others => '0');
                a_reg <= raw_pwm;
                b_reg <= not raw_pwm;
            end if;
        end if;
    end process;
end architecture;
