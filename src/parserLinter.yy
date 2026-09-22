/*
 * Trabalho 1 - Compiladores: Linter e Extrator de Metricas para miniLua
 * Integrantes:
 *   - Caio Uehara Martins - NUSP: 13672022
 *
 * Analisador sintatico do miniLua. Nao construimos AST: as acoes semanticas
 * apenas alimentam o LinterContext com as metricas de cada funcao
 * (parametros, chamadas externas, profundidade e complexidade ciclomatica)
 * e com os alertas de estilo do linter.
 */
%{
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include "LinterContext.hh"

using namespace std;

int yylex();
void yyerror(const char* s);

extern LinterContext* linterCtx;

// Nomes TODOS_MAIUSCULOS sao tratados como constantes descritivas:
// atribuir um literal a elas nao configura magic number.
static bool nomeDeConstante(const char* nome) {
    bool temLetra = false;
    for (const char* p = nome; *p != '\0'; p++) {
        if (islower((unsigned char)*p)) return false;
        if (isupper((unsigned char)*p)) temLetra = true;
    }
    return temLetra;
}
%}

%locations

%code requires {
#include <vector>
#include <string>
}

%union {
    char* texto;                      /* lexema de identificadores e numeros */
    int magia;                        /* indice de alerta pendente (-1 = nenhum) */
    std::vector<std::string>* lista;  /* lista de parametros */
}

%token TOKEN_IF TOKEN_THEN TOKEN_ELSEIF TOKEN_ELSE TOKEN_END
%token TOKEN_WHILE TOKEN_DO TOKEN_FOR TOKEN_REPEAT TOKEN_UNTIL
%token TOKEN_BREAK TOKEN_RETURN TOKEN_FUNCTION TOKEN_LOCAL
%token TOKEN_NIL TOKEN_TRUE TOKEN_FALSE
%token TOKEN_AND TOKEN_OR TOKEN_NOT
%token TOKEN_EQ TOKEN_NE TOKEN_LE TOKEN_GE TOKEN_CONCAT
%token <texto> TOKEN_ID TOKEN_NUM
%token TOKEN_STR

%type <texto> var
%type <magia> expr
%type <lista> params paramlist

/* em erro sintatico, o Bison descarta simbolos da pilha: libere os donos */
%destructor { free($$); } <texto>
%destructor { delete $$; } <lista>

/* Precedencia dos operadores de Lua (da menor para a maior) */
%left TOKEN_OR
%left TOKEN_AND
%left TOKEN_EQ TOKEN_NE '<' '>' TOKEN_LE TOKEN_GE
%right TOKEN_CONCAT
%left '+' '-'
%left '*' '/' '%'
%precedence TOKEN_NOT UNARIO
%right '^'

%start programa

%%

programa:
    bloco
    ;

/* Um bloco e uma sequencia de comandos com um "return" opcional no fim,
   como na gramatica de referencia de Lua. */
bloco:
    comandos retorno_opcional
    ;

comandos:
    %empty
    | comandos comando
    | comandos ';'
    ;

comando:
    declfuncao      { linterCtx->iniciaComando(@1.first_line); }
    | atribuicao    { linterCtx->iniciaComando(@1.first_line); }
    | decllocal     { linterCtx->iniciaComando(@1.first_line); }
    | chamada       { linterCtx->iniciaComando(@1.first_line); }
    | se            { linterCtx->iniciaComando(@1.first_line); }
    | enquanto      { linterCtx->iniciaComando(@1.first_line); }
    | repita        { linterCtx->iniciaComando(@1.first_line); }
    | laconumerico  { linterCtx->iniciaComando(@1.first_line); }
    | TOKEN_BREAK   { linterCtx->iniciaComando(@1.first_line); }
    ;

retorno_opcional:
    %empty
    | TOKEN_RETURN          { linterCtx->iniciaComando(@1.first_line); }
    | TOKEN_RETURN expr     { linterCtx->iniciaComando(@1.first_line); }
    ;

/* ---------- funcoes ---------- */

declfuncao:
    TOKEN_FUNCTION TOKEN_ID '(' params ')'
        {
            linterCtx->iniciaFuncao($2, $4);
            /* anula os slots apos consumir: eles permanecem na pilha do
               parser e o %destructor os liberaria de novo em erro sintatico */
            free($2);   $2 = nullptr;
            delete $4;  $4 = nullptr;
        }
    bloco TOKEN_END
        { linterCtx->terminaFuncao(); }
    ;

params:
    %empty     { $$ = new std::vector<std::string>(); }
    | paramlist     { $$ = $1; }
    ;

paramlist:
    TOKEN_ID
        {
            $$ = new std::vector<std::string>();
            $$->push_back($1);
            free($1);
        }
    | paramlist ',' TOKEN_ID
        {
            $$ = $1;
            $$->push_back($3);
            free($3);
        }
    ;

chamada:
    TOKEN_ID '(' argumentos ')'
        {
            linterCtx->registraChamada($1);
            free($1);
        }
    ;

argumentos:
    %empty
    | listaexpr
    ;

listaexpr:
    expr
    | listaexpr ',' expr
    ;

/* ---------- atribuicoes e declaracoes ---------- */

atribuicao:
    var '=' expr
        {
            /* literal sozinho atribuido a uma constante descritiva e aceito */
            if ($3 != -1 && $1 != nullptr && nomeDeConstante($1))
                linterCtx->cancelaAlerta($3);
            if ($1 != nullptr) free($1);
        }
    ;

decllocal:
    TOKEN_LOCAL TOKEN_ID
        { free($2); }
    | TOKEN_LOCAL TOKEN_ID '=' expr
        {
            if ($4 != -1 && nomeDeConstante($2))
                linterCtx->cancelaAlerta($4);
            free($2);
        }
    ;

/* Alvo de atribuicao: identificador simples ou acesso indexado (a[i][j]).
   O valor semantico guarda o nome apenas quando e um identificador puro. */
var:
    TOKEN_ID
        { $$ = $1; }
    | var '[' expr ']'
        {
            if ($1 != nullptr) free($1);
            $$ = nullptr;
        }
    ;

/* ---------- estruturas de controle ---------- */

se:
    TOKEN_IF                { linterCtx->contaDecisao("if"); }
    expr TOKEN_THEN         { linterCtx->empilhaBloco("if"); }
    bloco                   { linterCtx->desempilhaBloco(); }
    listaelseif parte_else TOKEN_END
    ;

listaelseif:
    %empty
    | listaelseif TOKEN_ELSEIF  { linterCtx->contaDecisao("elseif"); }
      expr TOKEN_THEN           { linterCtx->empilhaBloco("if"); }
      bloco                     { linterCtx->desempilhaBloco(); }
    ;

parte_else:
    %empty
    | TOKEN_ELSE    { linterCtx->empilhaBloco("if"); }
      bloco         { linterCtx->desempilhaBloco(); }
    ;

enquanto:
    TOKEN_WHILE     { linterCtx->contaDecisao("while"); }
    expr TOKEN_DO   { linterCtx->empilhaBloco("while"); }
    bloco           { linterCtx->desempilhaBloco(); }
    TOKEN_END
    ;

repita:
    TOKEN_REPEAT    { linterCtx->contaDecisao("repeat"); linterCtx->empilhaBloco("repeat"); }
    bloco TOKEN_UNTIL
                    { linterCtx->desempilhaBloco(); }
    expr
    ;

laconumerico:
    TOKEN_FOR       { linterCtx->contaDecisao("for"); }
    TOKEN_ID '=' expr ',' expr passo_opcional TOKEN_DO
                    { linterCtx->empilhaBloco("for"); }
    bloco           { linterCtx->desempilhaBloco(); }
    TOKEN_END
                    { free($3); }
    ;

passo_opcional:
    %empty
    | ',' expr
    ;

/* ---------- expressoes ---------- */

expr:
    TOKEN_NUM
        {
            $$ = linterCtx->alertaMagicNumber($1, @1.first_line);
            free($1);
        }
    | TOKEN_STR                 { $$ = -1; }
    | TOKEN_NIL                 { $$ = -1; }
    | TOKEN_TRUE                { $$ = -1; }
    | TOKEN_FALSE               { $$ = -1; }
    | var
        {
            if ($1 != nullptr) free($1);
            $$ = -1;
        }
    | chamada                   { $$ = -1; }
    | '(' expr ')'              { $$ = $2; }
    | expr '+' expr             { $$ = -1; }
    | expr '-' expr             { $$ = -1; }
    | expr '*' expr             { $$ = -1; }
    | expr '/' expr             { $$ = -1; }
    | expr '%' expr             { $$ = -1; }
    | expr '^' expr             { $$ = -1; }
    | expr TOKEN_CONCAT expr    { $$ = -1; }
    | expr '<' expr             { $$ = -1; }
    | expr '>' expr             { $$ = -1; }
    | expr TOKEN_LE expr        { $$ = -1; }
    | expr TOKEN_GE expr        { $$ = -1; }
    | expr TOKEN_EQ expr
        {
            /* igualdade contra literal e comparacao de codigo discreto,
               nao magnitude: nao alertamos magic number aqui */
            linterCtx->cancelaAlerta($1);
            linterCtx->cancelaAlerta($3);
            $$ = -1;
        }
    | expr TOKEN_NE expr
        {
            linterCtx->cancelaAlerta($1);
            linterCtx->cancelaAlerta($3);
            $$ = -1;
        }
    | expr TOKEN_AND expr       { linterCtx->contaDecisao("and"); $$ = -1; }
    | expr TOKEN_OR expr        { linterCtx->contaDecisao("or"); $$ = -1; }
    | TOKEN_NOT expr            { $$ = -1; }
    | '-' expr %prec UNARIO     { $$ = $2; }
    | '#' expr %prec UNARIO     { $$ = -1; }
    ;

%%

void yyerror(const char* s) {
    fprintf(stderr, "Erro sintático (linha %d): %s\n", yylloc.first_line, s);
}
