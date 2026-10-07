/*
 * Trabalho 1 - Compiladores: Linter e Extrator de Metricas para miniLua
 * Integrantes:
 *   - Caio Uehara Martins - NUSP: 13672022
 *   - Milena Rodrigues Monteiro - NUSP: 12566157
 *   - Taiane Lopes de Oliveira Terassaka - NUSP: 11814291
 *
 * Ponto de entrada: abre o arquivo .lua, dispara o parser (que orquestra o
 * lexer) e imprime o relatorio final de metricas e alertas.
 */
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

#include <FlexLexer.h>
#include "LinterContext.hh"

using namespace std;

// Contexto global compartilhado entre main, Flex e Bison
LinterContext* linterCtx = nullptr;

static yyFlexLexer* lexer = nullptr;

int yyparse();

// Ponte entre o Bison (que chama a funcao global yylex) e o objeto do Flex
int yylex() {
    return lexer->yylex();
}

int main(int argc, char** argv) {
    if (argc != 2) {
        fprintf(stderr, "Uso: %s <arquivo.lua>\n", argv[0]);
        return 1;
    }

    error_code codigoErro;
    if (filesystem::is_directory(argv[1], codigoErro)) {
        fprintf(stderr, "Erro: '%s' é um diretório, não um arquivo\n", argv[1]);
        return 1;
    }

    ifstream entrada(argv[1]);
    if (!entrada.is_open()) {
        fprintf(stderr, "Erro: não foi possível abrir '%s'\n", argv[1]);
        return 1;
    }

    LinterContext ctx;
    linterCtx = &ctx;

    yyFlexLexer scanner(&entrada, &cout);
    lexer = &scanner;

    if (yyparse() != 0) {
        return 2;
    }

    // no relatorio aparece so o nome do arquivo, sem os diretorios
    string nome = argv[1];
    size_t barra = nome.find_last_of('/');
    if (barra != string::npos) nome = nome.substr(barra + 1);

    ctx.imprimeRelatorio(nome);
    return 0;
}
