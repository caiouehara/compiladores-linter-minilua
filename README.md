# Trabalho 1 - Linter e Extrator de Métricas para miniLua

Analisador estático de código para o subconjunto miniLua, implementado com Flex (análise léxica) e Bison (análise sintática e orquestração de contexto), em C++.
O programa lê um arquivo `.lua` e imprime um relatório com métricas de volume, acoplamento, aninhamento e complexidade ciclomática, além de alertas de estilo (magic numbers e múltiplos comandos por linha).

## Integrantes

- Caio Uehara Martins - NUSP: 13672022

## Como compilar e rodar

Requisitos: `flex` (>= 2.6), `bison` (>= 3.0), `g++` e `make`.

```sh
make            # gera build/linter
make test       # roda os três exemplos do enunciado e compara byte a byte
./build/linter tests/teste1.lua
```

Alternativamente, com [mise](https://mise.jdx.dev) o projeto é autossuficiente: `mise run test` compila uma toolchain local em `.tools/` (flex 2.6.4) se o sistema não tiver as ferramentas, e depois builda e testa.

```sh
mise run setup  # instala a toolchain local (só na primeira vez)
mise run test   # build + testes
mise run zip    # gera o pacote de entrega em entrega/
```

## Estrutura

- `src/lexerLinter.ll` - analisador léxico: tokens, comentários (linha e bloco), contagem de linhas físicas e marcação de linhas lógicas.
- `src/parserLinter.yy` - gramática do miniLua; as ações semânticas alimentam o contexto com as métricas (sem construção de AST).
- `src/LinterContext.{hh,cc}` - estado da análise: métricas por função, pilhas de escopo/profundidade, alertas e impressão do relatório.
- `src/main.cc` - abre o arquivo, conecta Flex e Bison e emite o relatório.
- `tests/` - os três cenários do enunciado com as saídas esperadas em `tests/expected/`.

## Decisões de interpretação do enunciado

O enunciado define as métricas por exemplos, e alguns detalhes precisaram de interpretação.
As decisões abaixo reproduzem exatamente os exemplos das Seções II.1-II.3, exceto onde indicado.

**Linhas físicas** são a quantidade de caracteres `\n` do arquivo.
É a única regra que reconcilia os três exemplos (o `teste3.lua` tem 45 linhas de texto, mas não termina com quebra de linha, e o enunciado espera 44).

**Linhas lógicas** são as linhas com pelo menos um token fora de comentários, isto é, descontam-se linhas em branco e linhas só de comentário, como pede a Seção I.1.
Para o `teste2.lua` isso resulta em 12, embora o enunciado diga 11: o arquivo tem 15 linhas físicas, 3 em branco e nenhum comentário, e 15 - 3 = 12.
Não existe regra consistente com o teste1 (4) e o teste3 (37) que produza 11, então mantivemos a definição do texto do enunciado e assumimos um cochilo na saída de exemplo.

**Magic numbers**: qualquer literal numérico diferente de 0 e 1 gera alerta, com duas exceções.
Operandos diretos de `==` e `~=` não alertam, pois comparam códigos discretos e não magnitudes - é o que faz o próprio enunciado, que não alerta o `2` de `tipo_cliente == 2` no teste2 mas alerta o `18` de `idade < 18` no teste3.
Um literal sozinho atribuído a um nome TODO_MAIUSCULO também não alerta, pois é justamente a "constante descritiva" que o enunciado pede para extrair (`local TAXA_JUROS = 0.15` é a correção sugerida pelo alerta, não uma nova infração).

**Múltiplos comandos**: o alerta dispara quando dois comandos se iniciam na mesma linha física, com ou sem `;` de separação; um `;` sozinho ao fim da linha não alerta.

**Detalhamento da complexidade**: as estruturas aparecem na ordem de primeira ocorrência dentro da função, com `and` e `or` ao final, reproduzindo os quatro exemplos do enunciado.
A cadeia de aninhamento (`função -> for -> if`) é exibida quando a profundidade máxima é 3 ou mais, como nos exemplos.

**Escopos**: chamadas no escopo global (fora de função) não entram nas métricas, e recursão não conta como chamada externa, conforme a Seção III.5.

## Bônus implementados

- Números em notação científica (`1.5e3`) e hexadecimal (`0x1F`), Seção III.2.
- Supressão de magic numbers em comparações de igualdade e em atribuições a constantes descritivas (heurísticas de linter descritas acima).
