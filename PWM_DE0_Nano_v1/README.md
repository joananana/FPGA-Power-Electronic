
# Modulador PWM em VHDL — DE0-Nano

## 1. Descrição geral

Este projeto apresenta a implementação de um modulador PWM (*Pulse Width Modulation*) em VHDL, desenvolvido para a FPGA Cyclone IV E da placa DE0-Nano.

O módulo utiliza um contador crescente de 16 bits, que gera uma rampa digital do tipo dente de serra. A comparação entre o contador e a referência de duty cycle determina a largura dos pulsos de saída.

A implementação permite configurar o período e o duty cycle de forma independente. Posteriormente, o módulo será adaptado para integração com um controlador PI.

## 2. Interface

O modulador está implementado no arquivo `pwm_core.vhd`.

| Porta | Tipo | Função |
|---|---|---|
| `clk` | `std_logic` | Clock de referência de 50 MHz |
| `reset` | `std_logic` | Reset assíncrono ativo em nível alto |
| `period_ticks` | `unsigned(15 downto 0)` | Número de ciclos de clock por período |
| `duty_ticks` | `unsigned(15 downto 0)` | Número de ciclos em nível alto |
| `pwm_out` | `std_logic` | Saída PWM |

## 3. Funcionamento

O contador interno (`counter`) possui 16 bits e é incrementado a cada borda de subida do clock, percorrendo os valores de 0 até `period_ticks - 1`. Ao atingir esse limite, retorna a zero e inicia um novo período.

A geração do PWM é realizada pela comparação:

```vhdl
if counter < duty_ticks then
    pwm_out <= '1';
else
    pwm_out <= '0';
end if;
```

Assim, a saída permanece em nível alto enquanto o contador for menor que `duty_ticks`, e em nível baixo no restante do período.

Como a saída é registrada, a comparação utiliza o valor anterior do contador, produzindo um deslocamento de um ciclo de clock em relação ao contador atualizado, sem alterar a frequência ou o duty cycle em regime permanente.

A frequência e a razão cíclica são determinadas por:


A frequência e a razão cíclica são determinadas por:

**Frequência do PWM:**

`f_PWM = f_clk / period_ticks`

**Duty cycle:**

`D (%) = (duty_ticks / period_ticks) × 100`

**Exemplo:** considerando `f_clk = 50 MHz`, `period_ticks = 1000` e `duty_ticks = 400`:

| Parâmetro | Resultado |
|---|---|
| Frequência PWM | 50 kHz |
| Período | 20 µs |
| Duty cycle | 40% |
| Tempo em nível alto | 8 µs |
| Tempo em nível baixo | 12 µs |
| Resolução do duty | 0,1% |

Embora o contador possua 16 bits, a resolução efetiva depende de `period_ticks`. Quanto maior o número de ciclos por período, menor o incremento possível do duty cycle.

## 4. Condições de operação

O módulo possui reset assíncrono, que zera o contador e desliga a saída PWM quando ativado.

Os parâmetros devem respeitar os seguintes limites:

- `period_ticks`: 2 a 65535.
- `duty_ticks`: 0 até `period_ticks`.
- `duty_ticks = 0`: saída permanentemente baixa.
- `duty_ticks = period_ticks`: saída permanentemente alta em regime permanente.

Configurações inválidas zeram o contador e a saída na próxima borda de subida do clock.

Nesta versão, os parâmetros devem ser configurados durante o reset e mantidos estáveis durante a operação. A liberação do reset deve ser sincronizada externamente ao clock.

## 5. Simulação e validação

A validação funcional foi realizada no **Questa Altera FPGA Starter Edition 2025.2**, utilizando os seguintes arquivos:

| Arquivo | Função |
|---|---|
| `pwm_core.vhd` | Implementação do PWM |
| `tb_pwm_core.vhd` | Testbench de validação |
| `run_modelsim.do` | Script de execução da simulação |

Para executar a simulação no diretório dos arquivos:

```tcl
do run_modelsim.do
```

O testbench verifica diferentes combinações de períodos e duty cycles, incluindo valores extremos, reset assíncrono e parâmetros inválidos.

Também é realizado o teste de PWM de 50 kHz com duty cycle de 40%.

As verificações são realizadas automaticamente por meio de instruções `assert`.

A simulação foi concluída com sucesso, apresentando:

```text
Note: PASS: periodo, duty, extremos, reset e parametros invalidos
```

Esse resultado confirma que o módulo passou nos testes funcionais implementados.

## 6. Próximas etapas

A próxima etapa será adaptar o modulador para integração com o controlador PI desenvolvido por outro grupo.

As principais modificações previstas são:

1. **Frequência fixa:** definir o período de chaveamento conforme os requisitos do sistema.
2. **Interface com o PI:** receber o comando de duty cycle no formato numérico estabelecido entre os grupos.
3. **Atualização dinâmica do duty:** permitir alterações durante o funcionamento, aplicando o novo valor no início do período PWM.
4. **Validação da integração:** testar alterações de duty sem reset e verificar a manutenção da frequência.
5. **Implementação na FPGA:** realizar a síntese no Quartus Prime, configurar os pinos e o clock e testar o funcionamento na DE0-Nano.

## 7. Estado atual

O modulador PWM está implementado em VHDL e foi validado funcionalmente no Questa, incluindo testes de frequência, duty cycle, condições extremas e reset.

A versão atual permite configurar independentemente o período e a razão cíclica. As próximas etapas envolvem sua adaptação para receber o comando de um controlador PI e a posterior validação em hardware.
