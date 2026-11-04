# PWM independente — arquitetura inicial

Alvo: DE0-Nano / Cyclone IV, clock de 50 MHz. Projeto em VHDL-93,
sem IP do fabricante, processador, barramento ou prescaler.

## Arquivos

- `pwm_core.vhd`: componente sintetizavel, sete entradas e duas saidas.
- `tb_pwm_core.vhd`: testbench com assercoes e varredura de configuracoes.
- `run_modelsim.do`: compilacao e simulacao no ModelSim/Questa.

## Interface

| Porta | Tipo | Contrato |
|---|---|---|
| clk | std_logic | Clock principal; exemplo 50 MHz |
| reset | std_logic | Ativo alto; assercao assincrona, liberacao sincronizada externamente |
| enable | std_logic | Sincrono; 0 bloqueia e carrega configuracao; 1 executa |
| carrier_mode | std_logic | 0: pulso alinhado ao inicio; 1: pulso centralizado |
| period_ticks | unsigned(WIDTH-1 downto 0) | Periodo completo N, em clocks |
| duty_ticks | unsigned(WIDTH-1 downto 0) | Largura D do pulso ideal A, antes do tempo morto |
| deadtime_ticks | unsigned(WIDTH-1 downto 0) | Tempo morto DT, em clocks; zero desabilita |
| pwm_a, pwm_b | std_logic | Comandos ativos altos para as entradas dos drivers |

`WIDTH` e um generic, com padrao 16. Para WIDTH=16: N de 2 a 65535
(ate 65534 no modo centralizado). Duty inclui 0 e N. DT deve ser menor
que N. Periodo impar no modo centralizado ou outros valores fora desses
limites bloqueiam ambas as saidas. Nao ha porta de diagnostico nesta versao.

## Estrutura RTL

1. **Registradores de configuracao e contador de fase:** capturam entradas
   em cada borda de subida com enable=0. A fase percorre 0 a N-1 quando
   habilitada e a configuracao e valida. A configuracao fica congelada
   durante enable=1; nao e necessario config_valid.
2. **Modulador combinacional:** dente de serra: A ideal fica alto em [0,D).
   Triangular: A ideal fica alto em [floor((N-D)/2), floor((N-D)/2)+D).
   O segundo caso produz PWM centralizado equivalente a comparacao com
   uma portadora triangular de vale no centro. Nao existe um sinal de
   portadora analogico nem um segundo contador up/down nesta implementacao.
3. **Saidas registradas e tempo morto:** desligam imediatamente na borda
   em que a mudanca de comando e amostrada. A outra saida liga apos DT clocks,
   se o comando continuar valido. Uma nova mudanca cancela a espera anterior.

As duas saidas sao registradas no mesmo clock. O modulador usa a fase anterior
a borda; portanto a primeira borda habilitada emite a amostra de fase zero,
enquanto o contador visivel ja avanca para um. Isso nao acrescenta um clock
ao periodo. Nao ha clock gerado por logica combinacional.

## Frequencia e resolucao

Em ambos os modos:

    f_PWM = f_clk / N
    duty_ideal = D / N
    t_dead = DT / f_clk

Em 50 MHz, cada contagem corresponde a 20 ns. No modo triangular, exigimos N
par para dividir o periodo em duas metades iguais. D pode ser impar: nesse
caso, as margens diferem em um clock (centro deslocado por meio clock),
preservando exatamente D clocks de nivel alto ideal.

Exemplo: N=1000, D=400, DT=50 -> 50 kHz, duty ideal de 40%, tempo morto de 1 us.
No modo 0, o comando ideal A fica alto nas fases 0..399. No modo 1, 300..699.
Em regime, para 0<D<N:

    largura_A = max(D-DT, 0) clocks
    largura_B = max(N-D-DT, 0) clocks

Com DT=50, esse exemplo resulta em A=350 clocks (35%) e B=550 clocks (55%).
Os intervalos restantes sao de ambas desligadas. O duty de entrada representa
o comando antes do tempo morto, nao uma compensacao de duty na saida.

Duty 0: A permanece baixa; B liga apos a espera inicial. Duty N: B permanece
baixa; A liga apos a espera inicial. Nesses extremos nao ha comutacao periodica.
Se um pulso tem largura menor ou igual a DT, e suprimido. Se ambos os pulsos
forem suprimidos, ambas as saidas permanecem baixas.

## Sequencia de uso

1. Aplicar reset e depois libera-lo sincronizado ao clk.
2. Manter enable=0 e apresentar os parametros estaveis por pelo menos uma
   borda de subida, respeitando setup/hold.
3. Colocar enable=1. O PWM inicia na fase zero, incluindo a espera inicial DT.
4. Para reconfigurar, colocar enable=0, aguardar captura e habilitar novamente.

Enable=0 bloqueia na proxima borda de subida, nao assincronamente. Reset=1
bloqueia assincronamente. Alterar entradas de configuracao com enable=1 nao
altera o PWM ate uma nova captura com enable=0. Nao ha atualizacao sem
interrupcao nesta primeira versao.

Todos os sinais, exceto a assercao de reset, sao considerados sincronos ao clk.
O modulo externo deve tratar botoes, sincronizacao, debounce e transferencias
de barramentos vindos de outro dominio. Um sincronizador individual por bit
nao garante a captura coerente de um barramento de configuracao.

## Compilacao e testes

ModelSim/Questa, executando no diretorio deste pacote:

    do run_modelsim.do

GHDL:

    ghdl -a --std=93 pwm_core.vhd tb_pwm_core.vhd
    ghdl -e --std=93 tb_pwm_core
    ghdl -r --std=93 tb_pwm_core --assert-level=error

O testbench compara amostra a amostra as duas saidas, verifica exclusao mutua,
varre todos os duties e dead times para pequenos periodos, verifica periodos
maximos de 16 bits, configuracoes invalidas, reset entre bordas, desabilitacao,
reinicio e ignorar mudancas de configuracao durante operacao.

**Estado da validacao desta entrega:** revisao do RTL e testbench preparados.
A tentativa de analise com GHDL 4.1.0 neste ambiente terminou com falha interna
(segmentation fault), inclusive em um comando de consulta de configuracao
do proprio simulador. Portanto, nao foi possivel confirmar a compilacao nem
executar as assercoes. Nao foi realizada sintese no Quartus, analise de timing
ou teste em FPGA. Execute o testbench no ModelSim antes da integracao.

## Integracao posterior

Este pacote contem apenas o componente e sua simulacao. Nao inclui top-level
da placa, atribuicao de pinos, arquivo QSF, nem constraints SDC. Na integracao,
deve-se definir clock de 20 ns, pinos e padroes de I/O, verificar timing no
Quartus e conferir os sinais medidos. As saidas sao comandos logicos para
gate drivers; o tempo morto necessario depende dos drivers e das chaves.
O teste RTL nao verifica atrasos fisicos nem equivale a validacao na placa.
