# Modulador PWM em VHDL — DE0-Nano V2

## 1. Descrição geral

Esta versão apresenta a evolução do modulador PWM desenvolvido em VHDL para a FPGA Cyclone IV E da placa DE0-Nano, com foco na **atualização sincronizada do duty cycle**.

O módulo utiliza um contador crescente de 16 bits para gerar um sinal PWM com frequência fixa. O comando de duty cycle pode ser alterado durante a operação, sem necessidade de reset.

A principal característica desta versão é que o novo duty cycle é aplicado somente no início do próximo período PWM, evitando alterações na largura dos pulsos durante o ciclo em andamento.

O projeto contempla a implementação em VHDL, a validação funcional no Questa e a posterior verificação experimental na DE0-Nano.

## 2. Interface

O modulador está implementado no arquivo `pwm_core.vhd`.

| Porta | Tipo | Função |
|---|---|---|
| `clk` | `std_logic` | Clock de referência de 50 MHz |
| `reset` | `std_logic` | Reset assíncrono ativo em nível alto |
| `duty_cmd` | `unsigned(15 downto 0)` | Comando de duty cycle |
| `pwm_out` | `std_logic` | Saída PWM |

A frequência é definida pelo parâmetro `PERIOD_TICKS`, configurado como `generic` VHDL. O valor padrão é 1000, correspondente a 50 kHz com clock de 50 MHz.

## 3. Funcionamento

### 3.1. Contador e frequência

O contador interno (`counter`) possui 16 bits e percorre os valores de 0 até `PERIOD_TICKS - 1`, retornando a zero ao final de cada período.

A frequência é determinada por:

`f_PWM = f_clk / PERIOD_TICKS`

Para a configuração atual:

- Clock: 50 MHz
- `PERIOD_TICKS = 1000`
- Frequência PWM: 50 kHz
- Período PWM: 20 µs

### 3.2. Atualização sincronizada do duty cycle

O módulo utiliza dois sinais para controlar a razão cíclica:

- `duty_cmd`: recebe o comando externo, podendo mudar durante o período.
- `duty_active`: armazena o duty utilizado na geração do PWM, permanecendo constante durante todo o período.

O novo comando é capturado somente quando o contador atinge `PERIOD_TICKS - 1`, iniciando um novo ciclo.

Por exemplo, se o PWM estiver operando com 40% de duty e receber um comando de 70% no meio do período, continuará utilizando 40% até o final desse ciclo. Na próxima virada do contador, o novo duty será aplicado.

A saída PWM é registrada e calculada de forma alinhada à contagem, garantindo a duração correta dos níveis alto e baixo.

Quando o comando é alterado exatamente na borda de captura, o registrador utiliza o valor anterior de `duty_cmd`, conforme o comportamento sequencial do VHDL.

### 3.3. Saturação e resolução

O comando recebido é limitado ao valor máximo de `PERIOD_TICKS`, correspondente a 100% de duty cycle.

Para `PERIOD_TICKS = 1000`:

| `duty_cmd` | Duty aplicado |
|---|---|
| 0 | 0% |
| 200 | 20% |
| 400 | 40% |
| 700 | 70% |
| 1000 | 100% |
| 1200 | 100% (saturado) |

A resolução do duty cycle é de 0,1 ponto percentual, correspondente a um ciclo de clock.

## 4. Simulação e validação

A validação funcional foi realizada no **Questa Altera FPGA Starter Edition 2025.2**.

O projeto contém os arquivos:

| Arquivo | Função |
|---|---|
| `pwm_core.vhd` | Implementação do PWM sincronizado |
| `tb_pwm_core.vhd` | Testbench de validação |
| `run_modelsim.do` | Script de compilação e simulação |

Para executar a simulação no diretório dos arquivos:

`do run_modelsim.do`

### 4.1. Testes realizados

O testbench ampliado verifica:

1. Alterações de duty cycle durante o período, sem reset.
2. Múltiplos comandos recebidos no mesmo período.
3. Atualização do duty somente na fronteira entre períodos.
4. Comandos recebidos exatamente na borda de captura e imediatamente antes dela.
5. Saturação para valores superiores a 100%.
6. Duty cycles extremos e pulsos mínimos.
7. Reset assíncrono e retomada do funcionamento.

As verificações utilizam instruções `assert` para comparar a saída PWM com os valores esperados.

### 4.2. Resultados

A simulação foi concluída com sucesso, apresentando:

`Note: PASS: sincronismo, mudancas multiplas, fronteira, saturacao, extremos e reset`

Os resultados confirmam que, nas condições simuladas, o duty ativo permanece constante durante cada período e é atualizado somente na virada do contador.

## 5. Implementação na DE0-Nano

Além da validação por simulação, está prevista a implementação do modulador PWM isoladamente na FPGA DE0-Nano.

Para isso, será desenvolvido um módulo superior (`pwm_top.vhd`) que permitirá fornecer diferentes comandos de duty cycle ao `pwm_core`, utilizando as chaves disponíveis na placa.

A saída PWM será direcionada a um pino GPIO para análise com um osciloscópio.

Os testes experimentais terão como objetivos:

- Verificar a frequência fixa de 50 kHz.
- Medir a largura dos pulsos para diferentes valores de duty cycle.
- Testar os limites de 0% e 100%.
- Observar o comportamento durante alterações do comando.
- Comparar os resultados experimentais com as simulações.

O módulo superior também deverá tratar adequadamente os sinais provenientes das chaves físicas, incluindo sua sincronização com o clock da FPGA.

## 6. Próximas etapas

As atividades restantes para a conclusão do módulo PWM são:

1. **Projeto no Quartus Prime:** configurar a FPGA Cyclone IV E e realizar a síntese do modulador.
2. **Módulo de teste:** desenvolver o `pwm_top.vhd` para fornecer diferentes comandos de duty utilizando as chaves da placa.
3. **Configuração da FPGA:** definir os pinos de entrada e saída e as restrições de clock.
4. **Análise de implementação:** verificar a utilização de recursos e o atendimento aos requisitos de temporização.
5. **Validação experimental:** programar a DE0-Nano e verificar a saída PWM com um osciloscópio.

## 7. Estado atual

A segunda versão do modulador PWM está implementada em VHDL e foi validada funcionalmente no Questa.

O módulo opera com frequência fixa, permite receber novos comandos de duty cycle durante a operação e realiza sua atualização somente no início de cada período.

**A próxima etapa é implementar e testar o PWM isoladamente na DE0-Nano**, confirmando em hardware os resultados obtidos nas simulações.

Após essa validação, o módulo poderá ser disponibilizado para integração com os demais componentes da malha de controle.
