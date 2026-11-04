# PWM simplificado para DE0-Nano

Versao simplificada: somente dente de serra, uma saida e nenhum tempo morto.
O pacote substitui a arquitetura anterior, com a entidade `pwm_core`.

## Interface

| Porta | Funcao |
|---|---|
| clk | Clock de 50 MHz da placa |
| reset | Ativo alto: zera o contador e mantem pwm_out em zero |
| period_ticks | Periodo completo N, unsigned de 16 bits |
| duty_ticks | Largura D do pulso alto, unsigned de 16 bits |
| pwm_out | Unica saida PWM registrada |

Unico sinal interno declarado: `counter`, unsigned de 16 bits.
Um unico processo sequencial implementa contador, comparacao e saida.

O contador avanca de 0 ate N-1 e volta a zero. Em cada borda de subida,
pwm_out recebe 1 quando o valor anterior de counter e menor que D.
Caso contrario, recebe 0. Como as atribuicoes de sinais ocorrem juntas,
o contador observado depois da borda ja mostra o proximo valor. Isso nao
acrescenta um clock ao periodo do PWM.

    f_PWM = f_clk / N
    razao_ciclica = D / N

Exemplo: clk=50 MHz, N=1000, D=400: f_PWM=50 kHz e duty=40%.
O periodo e 20 us, com 8 us em nivel alto e 12 us em nivel baixo.

## Simplificacoes

- Retirados carrier_mode, deadtime_ticks, enable e a saida complementar.
- Retirados todos os registradores de configuracao e sinais de tempo morto.
- Retirado o generic WIDTH. Os dois parametros usam 16 bits fixos.
- Sem prescaler, barramento, handshake ou atualizacao durante operacao.
- Mantida uma verificacao simples de limites, sem sinal interno de validade.

## Operacao e limites

- Aplicar reset na inicializacao. Para parar, manter reset=1.
- Alterar period_ticks e duty_ticks enquanto reset=1.
- Manter os dois parametros estaveis enquanto reset=0.
- A assercao do reset e assincrona. O circuito externo deve sincronizar sua
  liberacao com clk e garantir que os parametros respeitem setup/hold.
- N valido: 2 a 65535. D valido: 0 a N.
- D=0 gera saida sempre baixa. D=N gera saida sempre alta apos liberar reset.
- N invalido ou D>N zera contador e saida na proxima borda de subida.
- Cada contagem representa 20 ns. O passo de duty e 1/N.

## Simulacao

No ModelSim/Questa, dentro do diretorio dos arquivos:

    do run_modelsim.do

O testbench varre todos os duties para pequenos periodos e verifica tambem
o exemplo de 50 kHz, o limite de 16 bits, 0%, 100%, reset e parametros invalidos.

Estado: codigo revisado e testbench preparado. A simulacao desta versao ainda
nao foi executada. Na tentativa anterior, o GHDL deste ambiente apresentou
falha interna antes da analise do VHDL. Nao ha validacao de sintese, timing
ou teste na placa nesta entrega.

## Integracao

Esta entrega contem somente o componente e os testes. Top-level, pinos,
constraints de clock e interface com o driver pertencem a integracao posterior.
