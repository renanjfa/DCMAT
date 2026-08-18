#ifndef DCMAT_H
#define DCMAT_H

/* ------------------------------------------------------------------ */
/* Limite de matriz definido pelo enunciado (secao 5.3): 10x10.       */
/* ------------------------------------------------------------------ */
#define MAX_DIM 10

/* Tamanho maximo da string que acumula a representacao RPN de uma   */
/* expressao (usada pelo comando rpn(...), que NAO avalia a expressao,*/
/* apenas lista a ordem das operacoes).                               */
#define RPN_BUF_SIZE 1024

/* ==================================================================
 * Matriz
 * ================================================================== */
typedef struct {
    int n_linhas;
    int n_colunas;
    float dados[MAX_DIM][MAX_DIM];
} Matriz;

/* ==================================================================
 * Estruturas auxiliares usadas apenas durante a CONSTRUCAO de um
 * literal de matriz (regras Linha / ListaLinhas), antes do "padding"
 * final feito em MatrizValor. Cada linha pode ter um numero de
 * elementos diferente das demais; o numero de colunas final e
 * definido pela maior linha (secao 1.16/2.2 do enunciado).
 * ================================================================== */
typedef struct {
    int n;
    float vals[MAX_DIM];
} LinhaBruta;

typedef struct {
    int n_linhas;
    LinhaBruta linhas[MAX_DIM];
} MatrizBruta;

/* ==================================================================
 * Valor sintetizado por Expressao: pode ser FLOAT, MATRIZ ou
 * INVALIDO (quando um erro semantico ja ocorreu na subexpressao,
 * para permitir que o parser continue construindo a arvore e
 * ACUMULANDO erros sem abortar no primeiro problema encontrado).
 *
 * O campo rpn acumula a representacao pos-fixa (RPN) da expressao,
 * construida em paralelo com a avaliacao normal, para ser usada
 * pelo comando rpn(...) sem precisar de uma segunda gramatica.
 * ================================================================== */
typedef enum {
    DCMAT_FLOAT,
    DCMAT_MATRIZ,
    DCMAT_INVALIDO
} TipoValor;

typedef struct {
    TipoValor tipo;
    float fval;
    Matriz mval;
    char rpn[RPN_BUF_SIZE];
} ValorDCMAT;

/* ==================================================================
 * Tabela de simbolos (lista ligada, com retipagem dinamica: um
 * simbolo pode alternar entre FLOAT e MATRIZ a cada nova atribuicao,
 * secao 2.1 do enunciado).
 * ================================================================== */
typedef enum {
    TIPO_FLOAT,
    TIPO_MATRIZ
} TipoSimbolo;

typedef struct Simbolo {
    char nome[256];
    TipoSimbolo tipo;
    float valor_float;
    Matriz valor_matriz;
    struct Simbolo *prox;
} Simbolo;

/* ==================================================================
 * Configuracoes internas do sistema (secao 6 do enunciado).
 * ================================================================== */
typedef struct {
    float h_view_lo, h_view_hi;
    float v_view_lo, v_view_hi;
    int float_precision;
    int integral_steps;
    int axis_on;
    int erase_plot_on;
    int connect_dots_on;
} SettingsDCMAT;

/* ==================================================================
 * Estado global compartilhado entre lexico.l / sintatico.y / dcmat.c
 * ================================================================== */
extern SettingsDCMAT settings;

extern Simbolo *tabela_simbolos;

extern Matriz matriz_global;
extern int matriz_global_definida;

/* Ativado enquanto a variavel x pode legalmente aparecer em uma
 * expressao (dentro de plot(...), integrate(...), sum(...) e
 * rpn(...) -- secao 3.1 do enunciado). */
extern int dentro_contexto_x;

/* Ativado dentro de rpn(...): suprime a impressao de "Undefined
 * symbol" e o calculo efetivo da expressao, pois o rpn so lista a
 * ordem das operacoes (secao 2 do enunciado, exemplo de rpn(n*abobrinha)). */
extern int modo_rpn;

/* Setado quando QUALQUER erro semantico ocorre durante a analise do
 * comando corrente; consultado ao final do comando para decidir se a
 * acao final (atribuicao, plot, solve, etc.) deve ser executada. */
extern int erro_semantico;

/* ------------------------------------------------------------------
 * Tabela de simbolos
 * ------------------------------------------------------------------ */
Simbolo *busca_simbolo(const char *nome);
void define_simbolo_float(const char *nome, float valor);
void define_simbolo_matriz(const char *nome, Matriz m);
void libera_simbolos(void);
void imprime_symbols(void);

/* ------------------------------------------------------------------
 * Settings
 * ------------------------------------------------------------------ */
void reset_settings(void);
void imprime_settings(void);

/* ------------------------------------------------------------------
 * Matrizes
 * ------------------------------------------------------------------ */
MatrizBruta matriz_bruta_inicial(LinhaBruta primeira);
MatrizBruta matriz_bruta_acrescenta(MatrizBruta atual, LinhaBruta nova);
/* Converte a MatrizBruta (linhas de tamanhos variados) na Matriz
 * final, preenchendo com zero as posicoes que faltam e validando o
 * limite de 10x10. Em caso de estouro, imprime a mensagem da secao
 * 5.3 e devolve tipo == DCMAT_INVALIDO. */
ValorDCMAT constroi_matriz(MatrizBruta bruta);
void imprime_matriz(const Matriz *m);

/* Imprime um float respeitando settings.float_precision (secao 4). */
void dcmat_imprime_float(float f);

/* ------------------------------------------------------------------
 * Avaliacao de expressoes (usadas nas acoes semanticas de Expressao)
 * ------------------------------------------------------------------ */
ValorDCMAT val_float(float f);
ValorDCMAT val_matriz(Matriz m);
ValorDCMAT val_invalido(void);

ValorDCMAT eval_identifier(const char *nome);
ValorDCMAT eval_variavel_x(void);

/* op_char: '+' '-' '*' '/' '%' '^'  (usado tambem para a mensagem de erro) */
ValorDCMAT eval_binaria(char op_char, ValorDCMAT a, ValorDCMAT b);
ValorDCMAT eval_unaria(char op_char, ValorDCMAT a);
/* nome_func: "SEN" "COS" "TAN" "ABS" (ja em maiusculas, como exigido
 * na mensagem de erro da secao 5.9) */
ValorDCMAT eval_funcao(const char *nome_func, ValorDCMAT a);

/* ------------------------------------------------------------------
 * Erros semanticos: imprime a mensagem e marca erro_semantico = 1,
 * sem interromper o parsing (acumulo de erros).
 * ------------------------------------------------------------------ */
void erro_semantico_msg(const char *fmt, ...);

/* ------------------------------------------------------------------
 * Comandos de alto nivel (secoes 1.18-1.20 do enunciado). A resolucao
 * de determinante/sistema linear opera sempre sobre matriz_global.
 * ------------------------------------------------------------------ */
void dcmat_solve_determinant(void);
void dcmat_solve_linear_system(void);
void dcmat_about(void);

/* ------------------------------------------------------------------
 * Pontos de extensao para a fase de AVALIACAO NUMERICA (fora do
 * escopo desta etapa de analise semantica): plot precisa amostrar a
 * expressao para varios valores de x e desenhar o grafico ASCII;
 * integrate precisa somar a expressao amostrada segundo
 * settings.integral_steps; sum precisa iterar a variavel de controle
 * do valor inferior ao superior. As checagens semanticas (tipos,
 * simbolos, escopo de x, limites) ja estao completas nas acoes de
 * sintatico.y; estas funcoes apenas registram que o comando foi
 * aceito, ate que o avaliador numerico seja implementado.
 * ------------------------------------------------------------------ */
void dcmat_plot_stub(ValorDCMAT funcao);
void dcmat_integrate_stub(float lim_inf, float lim_sup, ValorDCMAT funcao);
void dcmat_sum_stub(const char *var, float lim_inf, float lim_sup, ValorDCMAT corpo);

#endif /* DCMAT_H */
