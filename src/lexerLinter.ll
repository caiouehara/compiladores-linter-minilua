/*
 * Trabalho 1 - Compiladores: Linter e Extrator de Metricas para miniLua
 * Integrantes:
 *   - Caio Uehara Martins - NUSP: 13672022
 *   - Milena Rodrigues Monteiro - NUSP: 12566157
 *   - Taiane Lopes de Oliveira Terassaka - NUSP: 11814291
 *
 * Analisador lexico do miniLua. Alem de tokenizar, alimenta o contexto com
 * a contagem de linhas fisicas (todo '\n', inclusive dentro de comentarios)
 * e marca as linhas que possuem tokens uteis (linhas logicas).
 */
%option c++ noyywrap batch

%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include "LinterContext.hh"
#include "parserLinter.tab.hh"

extern LinterContext* linterCtx;

/* posicao (linha) do token corrente, consumida pelo %locations do Bison */
#define YY_USER_ACTION \
    yylloc.first_line = yylloc.last_line = linterCtx->linhaAtual();

/* todo token entregue ao parser marca a linha atual como linha logica */
#define TOKEN(t) do { linterCtx->marcaLinhaComCodigo(); return (t); } while (0)

/* linha onde o comentario de bloco corrente comecou (para diagnostico) */
static int linhaInicioComentario = 0;
%}

ID          [a-zA-Z_][a-zA-Z0-9_]*
DECIMAL     [0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?
HEXA        0[xX][0-9a-fA-F]+
STRING      \"([^\\\"\n]|\\.)*\"|'([^\\'\n]|\\.)*'

%x COMENTARIO_BLOCO

%%

 /* comentarios: descartados antes de chegar ao Bison, mas as quebras de
    linha internas continuam contando como linhas fisicas */
"--[["                      { linhaInicioComentario = linterCtx->linhaAtual(); BEGIN(COMENTARIO_BLOCO); }
<COMENTARIO_BLOCO>"]]"      { BEGIN(INITIAL); }
<COMENTARIO_BLOCO>\n        { linterCtx->novaLinha(); }
<COMENTARIO_BLOCO>[^\]\n]+  { }
<COMENTARIO_BLOCO>"]"       { }
<COMENTARIO_BLOCO><<EOF>>   {
                                fprintf(stderr,
                                        "Erro léxico: comentário de bloco iniciado na"
                                        " linha %d não foi fechado com ']]'\n",
                                        linhaInicioComentario);
                                exit(2);
                            }

"--["[^\[\n][^\n]*          { }
"--["                       { }
"--"[^\[\n][^\n]*           { }
"--"                        { }

 /* palavras reservadas */
"if"        { TOKEN(TOKEN_IF); }
"then"      { TOKEN(TOKEN_THEN); }
"elseif"    { TOKEN(TOKEN_ELSEIF); }
"else"      { TOKEN(TOKEN_ELSE); }
"end"       { TOKEN(TOKEN_END); }
"while"     { TOKEN(TOKEN_WHILE); }
"do"        { TOKEN(TOKEN_DO); }
"for"       { TOKEN(TOKEN_FOR); }
"repeat"    { TOKEN(TOKEN_REPEAT); }
"until"     { TOKEN(TOKEN_UNTIL); }
"break"     { TOKEN(TOKEN_BREAK); }
"return"    { TOKEN(TOKEN_RETURN); }
"function"  { TOKEN(TOKEN_FUNCTION); }
"local"     { TOKEN(TOKEN_LOCAL); }
"nil"       { TOKEN(TOKEN_NIL); }
"true"      { TOKEN(TOKEN_TRUE); }
"false"     { TOKEN(TOKEN_FALSE); }
"and"       { TOKEN(TOKEN_AND); }
"or"        { TOKEN(TOKEN_OR); }
"not"       { TOKEN(TOKEN_NOT); }

 /* literais */
{HEXA}      { yylval.texto = strdup(YYText()); TOKEN(TOKEN_NUM); }
{DECIMAL}   { yylval.texto = strdup(YYText()); TOKEN(TOKEN_NUM); }
{ID}        { yylval.texto = strdup(YYText()); TOKEN(TOKEN_ID); }
{STRING}    { TOKEN(TOKEN_STR); }

 /* operadores compostos */
"=="        { TOKEN(TOKEN_EQ); }
"~="        { TOKEN(TOKEN_NE); }
"<="        { TOKEN(TOKEN_LE); }
">="        { TOKEN(TOKEN_GE); }
".."        { TOKEN(TOKEN_CONCAT); }

 /* operadores e pontuacao de um caractere */
[+\-*/%^#<>=()\[\],;]       { TOKEN(YYText()[0]); }

[ \t\r]+    { }
\n          { linterCtx->novaLinha(); }

.           { TOKEN(YYText()[0]); /* caractere invalido: o Bison acusa o erro */ }

%%
