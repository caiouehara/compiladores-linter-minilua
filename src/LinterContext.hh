/*
 * Trabalho 1 - Compiladores: Linter e Extrator de Metricas para miniLua
 * Integrantes:
 *   - Caio Uehara Martins - NUSP: 13672022
 *
 * Contexto compartilhado entre o lexer (Flex) e o parser (Bison).
 * Concentra o estado da analise: contagem de linhas, metricas por funcao,
 * pilhas de escopo/profundidade e os alertas do linter.
 */
#ifndef LINTER_CONTEXT_HH
#define LINTER_CONTEXT_HH

#include <map>
#include <set>
#include <string>
#include <utility>
#include <vector>

// Um alerta de estilo emitido durante a analise. Alertas de magic number
// nascem "pendentes" e podem ser cancelados quando o contexto sintatico
// mostra que o literal e aceitavel (ex.: comparacao de igualdade).
struct Alerta {
    int linha;
    std::string mensagem;
    bool ativo;
};

// Metricas acumuladas para uma funcao declarada no arquivo.
struct MetricasFuncao {
    std::string nome;
    std::vector<std::string> parametros;
    std::vector<std::string> chamadasExternas; // em ordem, com repeticoes

    // Profundidade de aninhamento: o corpo da funcao ja conta como 1.
    int profundidadeAtual = 1;
    int profundidadeMaxima = 1;
    std::vector<std::string> pilhaBlocos;      // blocos abertos no momento
    std::vector<std::string> cadeiaMaxima;     // caminho que atingiu o maximo

    // Nos de decisao da complexidade ciclomatica. As estruturas de controle
    // ficam em ordem de primeira ocorrencia; and/or sao exibidos ao final.
    std::vector<std::pair<std::string, int>> estruturas;
    int contadorAnd = 0;
    int contadorOr = 0;
    int totalDecisoes = 0;
};

class LinterContext {
public:
    // ---- interface usada pelo lexer ----
    void novaLinha();            // conta um '\n' (linhas fisicas)
    void marcaLinhaComCodigo();  // linha atual carrega token util (linha logica)
    int linhaAtual() const { return linha; }

    // ---- delimitacao de funcoes ----
    void iniciaFuncao(const char* nome, std::vector<std::string>* params);
    void terminaFuncao();
    void registraChamada(const char* nome);

    // ---- profundidade de aninhamento ----
    void empilhaBloco(const char* rotulo);
    void desempilhaBloco();

    // ---- complexidade ciclomatica ----
    void contaDecisao(const char* categoria);

    // ---- linter ----
    void iniciaComando(int linhaComando);
    // Retorna o indice do alerta criado, ou -1 quando o literal nao e
    // considerado magic number (valores 0 e 1).
    int alertaMagicNumber(const char* lexema, int linhaLiteral);
    void cancelaAlerta(int indice);

    // ---- relatorio final ----
    void imprimeRelatorio(const std::string& nomeArquivo) const;

private:
    int linha = 1;
    int linhasFisicas = 0;               // total de '\n' no arquivo
    std::set<int> linhasComCodigo;       // linhas logicas

    std::vector<MetricasFuncao> funcoes; // em ordem de declaracao
    std::vector<int> pilhaFuncoes;       // indices das funcoes abertas

    std::map<int, int> comandosPorLinha; // deteccao de multiplos comandos
    std::vector<Alerta> alertas;

    MetricasFuncao* funcaoAtual();
};

#endif
