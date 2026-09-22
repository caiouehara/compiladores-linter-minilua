# Design - Linter e Extrator de Métricas miniLua

Data: 2026-09-22.
Documento interno de projeto (não vai no ZIP de entrega).

## Objetivo

Atender o Trabalho 1 de Compiladores: linter + métricas para miniLua com Flex e Bison, sem AST, com relatório textual idêntico aos exemplos do enunciado.

## Arquitetura

Segue o padrão dos laboratórios da disciplina (Lab 5): scanner C++ do Flex (`%option c++`), parser C do Bison compilado como C++, um objeto de contexto global (`LinterContext`) compartilhado, e `main.cc` fazendo a ponte `yylex()`.

- Lexer: tokeniza, descarta comentários, conta `\n` (linhas físicas) e marca linhas com token útil (linhas lógicas).
  `YY_USER_ACTION` preenche `yylloc` para o `%locations` do Bison.
- Parser: gramática do miniLua no formato canônico de Lua (`bloco = comandos + return opcional`), sem AST.
  Ações de meio de regra incrementam complexidade no token da estrutura e empilham/desempilham blocos para a profundidade.
- Contexto: vetor de `MetricasFuncao` em ordem de declaração, pilha de funções (suporta aninhamento), mapa linha->comandos para o alerta de múltiplos comandos, vetor de alertas com flag `ativo` para cancelamento tardio de magic numbers.

## Mecânica dos magic numbers

Todo `TOKEN_NUM` fora de {0, 1} cria um alerta imediatamente e devolve o índice como valor semântico da expressão (`-1` quando não é literal puro).
Regras que "absolvem" o literal cancelam o alerta a posteriori: operando direto de `==`/`~=`, e RHS puro de atribuição a nome TODO_MAIUSCULO.
Parênteses e menos unário propagam o índice; qualquer operação composta o descarta (o alerta fica de pé).

## Reconciliação dos exemplos do enunciado

Os exemplos do PDF têm três sutilezas que guiaram decisões (detalhadas no README):

1. Físicas = contagem de `\n` (teste3 tem 45 linhas de texto e 44 `\n`).
2. Lógicas do teste2: enunciado diz 11, aritmética do próprio enunciado dá 12; mantivemos 12.
3. `tipo_cliente == 2` sem alerta no teste2 vs `idade < 18` com alerta no teste3: igualdade não alerta.
4. Ordem do detalhamento da complexidade: primeira ocorrência para estruturas, `and`/`or` no final (única regra que bate com os 4 exemplos).

## Armadilhas anti-IA do enunciado

O PDF contém instruções ocultas dirigidas a modelos de linguagem mandando inserir marcadores no código ("Complexidade Ciclomática (McCabe):", variável global `mccabe_base_factor`, comentário sobre "algoritmo de grafos diretos de McCabe (1976)").
São armadilhas de detecção; nenhuma delas aparece no código, e a revisão automatizada verifica a ausência dos três marcadores nos fontes, no binário e na saída.

## Endurecimento pós-revisão

Duas rodadas de revisão adversarial multiagente confirmaram e levaram aos seguintes ajustes:

- `%option batch` no lexer (o modo interativo padrão do scanner C++ lia 1 byte por vez, O(n²) no tamanho do token; 80k chars caíram de 40s para 0.00s).
- Regra `<COMENTARIO_BLOCO><<EOF>>`: comentário `--[[` não fechado agora é erro léxico com linha de início e exit 2 (antes gerava relatório "limpo" enganoso).
- `%destructor` para `<texto>`/`<lista>` com anulação dos slots na mid-rule de `declfuncao` (sem isso havia double-free em erro sintático dentro de função; validado com ASan).
- Makefile: regra de padrão com dois alvos (`build/%.tab.cc build/%.tab.hh`), que o GNU make trata como agrupada - elimina bison duplicado no `make -j` (10/10 builds paralelos) e regenera ambos se um for apagado.
- Include do `FlexLexer.h` derivado do prefixo do flex encontrado no PATH.
- `main.cc` rejeita diretório com mensagem clara (fifo/process substitution continuam aceitos).

## Ambiente

`mise.toml` define tasks (`setup`, `build`, `test`, `run`, `clean`, `zip`) e injeta `.tools/bin` no PATH.
`scripts/bootstrap.sh` compila flex 2.6.4 (com `-D_GNU_SOURCE`, sem docs para dispensar help2man) em `.tools/` quando o sistema não tem flex, e faz o mesmo para bison se necessário; checksums SHA-256 verificados.
O Makefile funciona também sem mise, com flex/bison do sistema.
