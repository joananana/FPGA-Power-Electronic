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

O modulador PWM foi sintetizado e implementado no Quartus Prime Lite Edition 25.1, utilizando a FPGA Cyclone IV E (EP4CE22F17C6) da placa DE0-Nano.

Foi desenvolvido um módulo superior (`pwm_top.vhd`) responsável pela interface entre o `pwm_core` e os recursos físicos da placa.

O módulo superior contempla:

- Clock de 50 MHz;
- Quatro chaves DIP para seleção do duty cycle;
- Sincronização das entradas em dois estágios;
- Reset com ativação assíncrona e liberação sincronizada;
- Saída PWM direcionada a um GPIO.

### 5.1. Configuração da pinagem

| Sinal | Pino FPGA | Função |
|---|---|---|
| `CLOCK_50` | PIN_R8 | Clock de 50 MHz |
| `KEY0` | PIN_J15 | Reset ativo baixo |
| `SW[0]` | PIN_M1 | Seleção do duty |
| `SW[1]` | PIN_T8 | Seleção do duty |
| `SW[2]` | PIN_B9 | Seleção do duty |
| `SW[3]` | PIN_M15 | Seleção do duty |
| `PWM_OUT` | PIN_D3 | Saída PWM (GPIO) |

Todos os pinos utilizados foram configurados com o padrão elétrico **3.3-V LVTTL**.

### 5.2. Seleção do duty cycle

As quatro chaves DIP permitem selecionar 16 condições de operação:

| SW[3:0] | `duty_cmd` | Duty aplicado |
|---|---:|---:|
| 0000 | 0 | 0% |
| 0001 | 100 | 10% |
| 0010 | 200 | 20% |
| 0011 | 300 | 30% |
| 0100 | 400 | 40% |
| 0101 | 500 | 50% |
| 0110 | 600 | 60% |
| 0111 | 700 | 70% |
| 1000 | 800 | 80% |
| 1001 | 900 | 90% |
| 1010 | 1000 | 100% |
| 1011 | 1 | 0,1% |
| 1100 | 250 | 25% |
| 1101 | 750 | 75% |
| 1110 | 999 | 99,9% |
| 1111 | 1200 | 100% (saturado) |

### 5.3. Arquivos de implementação

| Arquivo | Função |
|---|---|
| `pwm_top.vhd` | Interface com os recursos físicos da placa |
| `pwm_top.sdc` | Restrições de temporização |
| `PWM_DE0_Nano_v2.qpf` | Projeto do Quartus |
| `PWM_DE0_Nano_v2.qsf` | Configuração do dispositivo e pinagem |

Para compilar o projeto, abrir o arquivo `.qpf` no Quartus e executar `Processing > Start Compilation`.

### 5.4. Resultados da implementação

A compilação completa foi concluída com sucesso.

| Parâmetro | Resultado |
|---|---:|
| Elementos lógicos utilizados | 67 |
| Registradores | 37 |
| Utilização lógica | 0,30% |
| Frequência máxima estimada (Fmax) | 200,88 MHz |
| Setup Slack | 15,022 ns |
| Hold Slack | 0,194 ns |
| Total Negative Slack (TNS) | 0 ns |

Os resultados correspondem à implementação do modulador PWM juntamente com o módulo superior.

A análise de temporização indica que os caminhos restritos atendem aos requisitos de operação com clock de 50 MHz.


## 6. Próximas etapas

As atividades restantes para a conclusão do módulo PWM são:

1. **Programação da FPGA:** carregar o arquivo `.sof` gerado pelo Quartus na DE0-Nano.
2. **Validação experimental:** verificar o funcionamento do modulador e da interface com as chaves DIP utilizando um osciloscópio.
3. **Integração com o controlador PI:** substituir o comando manual de duty cycle pelo comando proveniente da malha de controle.

Os testes experimentais terão como objetivos:

- Verificar a frequência fixa de 50 kHz.
- Verificar as razões cíclicas selecionadas pelas chaves DIP.
- Medir a largura dos pulsos para diferentes valores de duty cycle.
- Testar os limites de 0% e 100%.
- Verificar a saturação do comando.
- Verificar o funcionamento do reset.
- Observar o comportamento durante alterações do duty cycle.
- Comparar os resultados experimentais com as simulações.

## 7. Estado atual

- [x] Desenvolvimento do modulador PWM V2.
- [x] Validação funcional do `pwm_core` no Questa.
- [x] Desenvolvimento do módulo superior.
- [x] Configuração da pinagem e das restrições de clock.
- [x] Síntese e fitting no Quartus.
- [x] Análise de recursos e temporização dos caminhos restritos.
- [ ] Programação da DE0-Nano.
- [ ] Validação experimental com osciloscópio.
- [ ] Integração com o controlador PI.

O modulador PWM está implementado em VHDL, validado funcionalmente no Questa e sintetizado com sucesso no Quartus Prime.

Os resultados da análise de temporização indicam que os caminhos restritos atendem aos requisitos de operação com clock de 50 MHz.

**A próxima etapa é programar a DE0-Nano e validar experimentalmente o funcionamento do PWM, incluindo a interface com os recursos físicos da placa.**

Após essa validação, o módulo poderá ser disponibilizado para integração com os demais componentes da malha de controle.
