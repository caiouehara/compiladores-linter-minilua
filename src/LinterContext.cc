/*
 * Trabalho 1 - Compiladores: Linter e Extrator de Metricas para miniLua
 * Integrantes:
 *   - Caio Uehara Martins - NUSP: 13672022
 */
#include "LinterContext.hh"

#include <algorithm>
#include <cstdio>
#include <cstdlib>

using namespace std;

void LinterContext::novaLinha() {
    linha++;
    linhasFisicas++;
}

void LinterContext::marcaLinhaComCodigo() {
    linhasComCodigo.insert(linha);
}

MetricasFuncao* LinterContext::funcaoAtual() {
    if (pilhaFuncoes.empty()) return nullptr;
    return &funcoes[pilhaFuncoes.back()];
}

void LinterContext::iniciaFuncao(const char* nome, vector<string>* params) {
    MetricasFuncao f;
    f.nome = nome;
    if (params != nullptr) f.parametros = *params;
    funcoes.push_back(f);
    pilhaFuncoes.push_back((int)funcoes.size() - 1);
}

void LinterContext::terminaFuncao() {
    if (!pilhaFuncoes.empty()) pilhaFuncoes.pop_back();
}

void LinterContext::registraChamada(const char* nome) {
    MetricasFuncao* f = funcaoAtual();
    if (f == nullptr) return;              // chamada em escopo global: ignorada
    if (f->nome == nome) return;           // recursao nao conta como externa
    f->chamadasExternas.push_back(nome);
}

void LinterContext::empilhaBloco(const char* rotulo) {
    MetricasFuncao* f = funcaoAtual();
    if (f == nullptr) return;
    f->profundidadeAtual++;
    f->pilhaBlocos.push_back(rotulo);
    if (f->profundidadeAtual > f->profundidadeMaxima) {
        f->profundidadeMaxima = f->profundidadeAtual;
        f->cadeiaMaxima = f->pilhaBlocos;
    }
}

void LinterContext::desempilhaBloco() {
    MetricasFuncao* f = funcaoAtual();
    if (f == nullptr) return;
    f->profundidadeAtual--;
    if (!f->pilhaBlocos.empty()) f->pilhaBlocos.pop_back();
}

void LinterContext::contaDecisao(const char* categoria) {
    MetricasFuncao* f = funcaoAtual();
    if (f == nullptr) return;
    f->totalDecisoes++;

    string cat = categoria;
    if (cat == "and") { f->contadorAnd++; return; }
    if (cat == "or")  { f->contadorOr++;  return; }
    for (auto& par : f->estruturas) {
        if (par.first == cat) { par.second++; return; }
    }
    f->estruturas.push_back({cat, 1}); // primeira ocorrencia define a ordem
}

void LinterContext::iniciaComando(int linhaComando) {
    int& contador = comandosPorLinha[linhaComando];
    contador++;
    if (contador == 2) {
        alertas.push_back({linhaComando,
                           "Múltiplos comandos na mesma linha detectados.",
                           true});
    }
}

int LinterContext::alertaMagicNumber(const char* lexema, int linhaLiteral) {
    double valor = strtod(lexema, nullptr);
    if (valor == 0.0 || valor == 1.0) return -1;
    string msg = "'Magic Number' detectado (";
    msg += lexema;
    msg += "). Considere extrair para uma constante.";
    alertas.push_back({linhaLiteral, msg, true});
    return (int)alertas.size() - 1;
}

void LinterContext::cancelaAlerta(int indice) {
    if (indice >= 0 && indice < (int)alertas.size()) {
        alertas[indice].ativo = false;
    }
}

void LinterContext::imprimeRelatorio(const string& nomeArquivo) const {
    printf("=== RELATÓRIO DE ANÁLISE ===\n");
    printf("Arquivo: %s\n", nomeArquivo.c_str());
    printf("Linhas Físicas: %d\n", linhasFisicas);
    printf("Linhas Lógicas: %d\n", (int)linhasComCodigo.size());

    for (const MetricasFuncao& f : funcoes) {
        printf("\n--- Função: %s ---\n", f.nome.c_str());

        printf("Parâmetros: %d", (int)f.parametros.size());
        if (!f.parametros.empty()) {
            printf(" (");
            for (size_t i = 0; i < f.parametros.size(); i++) {
                printf("%s%s", i ? ", " : "", f.parametros[i].c_str());
            }
            printf(")");
        }
        printf("\n");

        printf("Chamadas de Funções Externas: %d", (int)f.chamadasExternas.size());
        if (!f.chamadasExternas.empty()) {
            printf(" (");
            for (size_t i = 0; i < f.chamadasExternas.size(); i++) {
                printf("%s%s", i ? ", " : "", f.chamadasExternas[i].c_str());
            }
            printf(")");
        }
        printf("\n");

        printf("Profundidade Máxima de Aninhamento: %d", f.profundidadeMaxima);
        if (f.profundidadeMaxima >= 3) {
            // mostra o caminho de blocos que atingiu o maximo
            printf(" (função");
            for (const string& rotulo : f.cadeiaMaxima) {
                printf(" -> %s", rotulo.c_str());
            }
            printf(")");
        }
        printf("\n");

        int complexidade = 1 + f.totalDecisoes;
        printf("Complexidade Ciclomática: %d", complexidade);
        if (f.totalDecisoes > 0) {
            printf(" (1 base");
            for (const auto& par : f.estruturas) {
                printf(" + %d %s", par.second, par.first.c_str());
            }
            if (f.contadorAnd > 0) printf(" + %d and", f.contadorAnd);
            if (f.contadorOr > 0)  printf(" + %d or", f.contadorOr);
            printf(")");
        }
        printf("\n");
    }

    printf("\n--- Alertas do Linter ---\n");
    vector<Alerta> ativos;
    for (const Alerta& a : alertas) {
        if (a.ativo) ativos.push_back(a);
    }
    stable_sort(ativos.begin(), ativos.end(),
                [](const Alerta& a, const Alerta& b) { return a.linha < b.linha; });
    if (ativos.empty()) {
        printf("Nenhuma infração de estilo detectada.\n");
    } else {
        for (const Alerta& a : ativos) {
            printf("[Aviso] Linha %d: %s\n", a.linha, a.mensagem.c_str());
        }
    }
    printf("============================\n");
}
