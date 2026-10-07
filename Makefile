# Trabalho 1 - Compiladores: Linter e Extrator de Metricas para miniLua
# Integrantes:
#   - Caio Uehara Martins - NUSP: 13672022
#   - Milena Rodrigues Monteiro - NUSP: 12566157
#
# Alvos: all (padrao), test, zip, clean

FLEX     ?= flex
BISON    ?= bison
CXX      ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall
# FlexLexer.h: cobre a toolchain local (.tools), o prefixo de onde o flex
# do PATH foi instalado e os diretorios padrao do sistema
INCLUDES := -Isrc -Ibuild -I.tools/include
FLEX_PATH := $(shell command -v $(FLEX) 2>/dev/null)
ifneq ($(FLEX_PATH),)
INCLUDES += -I$(dir $(FLEX_PATH))../include
endif

SRCS := src/main.cc src/LinterContext.cc build/parserLinter.tab.cc build/lex.yy.cc

all: build/linter

build:
	mkdir -p build

# regra de padrao com dois alvos: o GNU make a trata como agrupada (a receita
# roda uma unica vez para gerar os dois arquivos), o que evita bison duplicado
# com make -j e regenera ambos se qualquer um for apagado
build/%.tab.cc build/%.tab.hh: src/%.yy | build
	$(BISON) -d -Wall -o build/$*.tab.cc src/$*.yy

build/lex.yy.cc: src/lexerLinter.ll build/parserLinter.tab.hh | build
	$(FLEX) -o $@ src/lexerLinter.ll

build/linter: $(SRCS) src/LinterContext.hh | build
	$(CXX) $(CXXFLAGS) $(INCLUDES) -o $@ $(SRCS)

test: build/linter
	@status=0; \
	for t in 1 2 3 4; do \
		./build/linter tests/teste$$t.lua > build/teste$$t.out; \
		if diff -u tests/expected/teste$$t.out build/teste$$t.out > /dev/null; then \
			echo "teste$$t: OK"; \
		else \
			echo "teste$$t: FALHOU"; \
			diff -u tests/expected/teste$$t.out build/teste$$t.out || true; \
			status=1; \
		fi; \
	done; \
	exit $$status

zip: all
	rm -rf entrega && mkdir -p entrega
	zip -r entrega/t1-linter-minilua.zip \
		src Makefile README.md tests mise.toml scripts \
		-x "*/.*"

clean:
	rm -rf build entrega

.PHONY: all test zip clean
