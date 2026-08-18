#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <math.h>

#include "dcmat.h"

/* ================================================================== */
/* Estado global                                                      */
/* ================================================================== */
SettingsDCMAT settings;

Simbolo *tabela_simbolos = NULL;

Matriz matriz_global;
int matriz_global_definida = 0;

int dentro_contexto_x = 0;
int modo_rpn = 0;
int erro_semantico = 0;

/* ================================================================== */
/* Erros semanticos: imprime e acumula (nao aborta o parsing).        */
/* ================================================================== */
void erro_semantico_msg(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vprintf(fmt, args);
    printf("\n");
    va_end(args);
    erro_semantico = 1;
}

/* ================================================================== */
/* Tabela de simbolos                                                  */
/* ================================================================== */
Simbolo *busca_simbolo(const char *nome) {
    Simbolo *s = tabela_simbolos;
    while (s != NULL) {
        if (strcmp(s->nome, nome) == 0) return s;
        s = s->prox;
    }
    return NULL;
}

static Simbolo *garante_simbolo(const char *nome) {
    Simbolo *s = busca_simbolo(nome);
    if (s != NULL) return s;

    s = (Simbolo *) malloc(sizeof(Simbolo));
    strncpy(s->nome, nome, sizeof(s->nome) - 1);
    s->nome[sizeof(s->nome) - 1] = '\0';
    s->prox = tabela_simbolos;
    tabela_simbolos = s;
    return s;
}

void define_simbolo_float(const char *nome, float valor) {
    Simbolo *s = garante_simbolo(nome);
    s->tipo = TIPO_FLOAT;
    s->valor_float = valor;
}

void define_simbolo_matriz(const char *nome, Matriz m) {
    Simbolo *s = garante_simbolo(nome);
    s->tipo = TIPO_MATRIZ;
    s->valor_matriz = m;
}

void libera_simbolos(void) {
    Simbolo *s = tabela_simbolos;
    while (s != NULL) {
        Simbolo *prox = s->prox;
        free(s);
        s = prox;
    }
    tabela_simbolos = NULL;
}

void imprime_symbols(void) {
    Simbolo *s = tabela_simbolos;
    if (s == NULL) return; /* enunciado nao define mensagem para tabela vazia */
    while (s != NULL) {
        if (s->tipo == TIPO_FLOAT) {
            printf("%s - FLOAT\n", s->nome);
        } else {
            printf("%s - MATRIX [%d][%d]\n", s->nome,
                   s->valor_matriz.n_linhas, s->valor_matriz.n_colunas);
        }
        s = s->prox;
    }
}

/* ================================================================== */
/* Settings (secao 6 do enunciado: valores padrao)                    */
/* ================================================================== */
void reset_settings(void) {
    settings.h_view_lo = -6.5f;
    settings.h_view_hi = 6.5f;
    settings.v_view_lo = -3.5f;
    settings.v_view_hi = 3.5f;
    settings.float_precision = 6;
    settings.integral_steps = 1000;
    settings.axis_on = 1;
    settings.erase_plot_on = 1;
    settings.connect_dots_on = 0;
}

void imprime_settings(void) {
    /* show settings SEMPRE usa 6 casas decimais para os campos de     */
    /* ponto flutuante, independente do float_precision configurado    */
    /* (secao 4 do enunciado).                                         */
    printf("h_view_lo: %.6f\n", settings.h_view_lo);
    printf("h_view_hi: %.6f\n", settings.h_view_hi);
    printf("v_view_lo: %.6f\n", settings.v_view_lo);
    printf("v_view_hi: %.6f\n", settings.v_view_hi);
    printf("float precision: %d\n", settings.float_precision);
    printf("integral_steps: %d\n", settings.integral_steps);
    printf("Draw Axis: %s\n", settings.axis_on ? "ON" : "OFF");
    printf("Erase Plot: %s\n", settings.erase_plot_on ? "ON" : "OFF");
    printf("Connect Dots: %s\n", settings.connect_dots_on ? "ON" : "OFF");
}

/* ================================================================== */
/* Impressao de valores com a precisao configurada pelo usuario       */
/* (secao 4 do enunciado: afeta todos os resultados, exceto           */
/* show settings, ja tratado acima).                                  */
/* ================================================================== */
static void imprime_float(float f) {
    printf("%.*f\n", settings.float_precision, f);
}

void imprime_matriz(const Matriz *m) {
    /* Calcula a largura de campo necessaria para alinhar colunas com  */
    /* numeros negativos (secao 1.17 do enunciado).                    */
    int largura = 0;
    for (int i = 0; i < m->n_linhas; i++) {
        for (int j = 0; j < m->n_colunas; j++) {
            char buf[64];
            int len = snprintf(buf, sizeof(buf), "%.*f",
                                settings.float_precision, m->dados[i][j]);
            if (len > largura) largura = len;
        }
    }

    printf("+- ");
    for (int j = 0; j < m->n_colunas; j++) printf(" ");
    for (int j = 1; j < m->n_colunas; j++) {
        for (int k = 0; k < largura; k++) printf(" ");
        printf(" ");
    }
    printf("-+\n");

    for (int i = 0; i < m->n_linhas; i++) {
        printf("| ");
        for (int j = 0; j < m->n_colunas; j++) {
            printf("%*.*f ", largura, settings.float_precision, m->dados[i][j]);
        }
        printf("|\n");
    }

    printf("+- ");
    for (int j = 0; j < m->n_colunas; j++) printf(" ");
    for (int j = 1; j < m->n_colunas; j++) {
        for (int k = 0; k < largura; k++) printf(" ");
        printf(" ");
    }
    printf("-+\n");
}

/* ================================================================== */
/* Construcao de literais de matriz                                    */
/* ================================================================== */
MatrizBruta matriz_bruta_inicial(LinhaBruta primeira) {
    MatrizBruta mb;
    mb.n_linhas = 1;
    mb.linhas[0] = primeira;
    return mb;
}

MatrizBruta matriz_bruta_acrescenta(MatrizBruta atual, LinhaBruta nova) {
    if (atual.n_linhas < MAX_DIM) {
        atual.linhas[atual.n_linhas] = nova;
        atual.n_linhas++;
    } else {
        /* Mais uma linha do que o limite: sinaliza atraves de um     */
        /* numero de linhas "impossivel" (> MAX_DIM), detectado em    */
        /* constroi_matriz(), que emite o erro da secao 5.3.          */
        atual.n_linhas++;
    }
    return atual;
}

ValorDCMAT constroi_matriz(MatrizBruta bruta) {
    int n_colunas = 0;
    for (int i = 0; i < bruta.n_linhas && i < MAX_DIM; i++) {
        if (bruta.linhas[i].n > n_colunas) n_colunas = bruta.linhas[i].n;
    }

    if (bruta.n_linhas > MAX_DIM || n_colunas > MAX_DIM) {
        erro_semantico_msg("ERROR: Matrix limits out of boundaries.");
        return val_invalido();
    }

    Matriz m;
    m.n_linhas = bruta.n_linhas;
    m.n_colunas = n_colunas;
    for (int i = 0; i < m.n_linhas; i++) {
        for (int j = 0; j < m.n_colunas; j++) {
            m.dados[i][j] = (j < bruta.linhas[i].n) ? bruta.linhas[i].vals[j] : 0.0f;
        }
    }

    return val_matriz(m);
}

/* ================================================================== */
/* Construtores de ValorDCMAT                                          */
/* ================================================================== */
ValorDCMAT val_float(float f) {
    ValorDCMAT v;
    v.tipo = DCMAT_FLOAT;
    v.fval = f;
    v.rpn[0] = '\0';
    return v;
}

ValorDCMAT val_matriz(Matriz m) {
    ValorDCMAT v;
    v.tipo = DCMAT_MATRIZ;
    v.mval = m;
    v.rpn[0] = '\0';
    return v;
}

ValorDCMAT val_invalido(void) {
    ValorDCMAT v;
    v.tipo = DCMAT_INVALIDO;
    v.fval = 0.0f;
    v.rpn[0] = '\0';
    return v;
}

/* ================================================================== */
/* Identificadores e variavel x                                        */
/* ================================================================== */
ValorDCMAT eval_identifier(const char *nome) {
    ValorDCMAT v;

    if (modo_rpn) {
        /* rpn(...) apenas lista a ordem das operacoes: nao valida se   */
        /* o simbolo existe (secao 2, exemplo rpn(n*abobrinha)).        */
        v = val_float(0.0f);
        snprintf(v.rpn, RPN_BUF_SIZE, "%s", nome);
        return v;
    }

    Simbolo *s = busca_simbolo(nome);
    if (s == NULL) {
        erro_semantico_msg("Undefined symbol [%s]", nome);
        v = val_invalido();
        snprintf(v.rpn, RPN_BUF_SIZE, "%s", nome);
        return v;
    }

    if (s->tipo == TIPO_FLOAT) {
        v = val_float(s->valor_float);
    } else {
        v = val_matriz(s->valor_matriz);
    }
    snprintf(v.rpn, RPN_BUF_SIZE, "%s", nome);
    return v;
}

ValorDCMAT eval_variavel_x(void) {
    ValorDCMAT v;

    if (!dentro_contexto_x) {
        erro_semantico_msg("The x variable cannot be present on expressions.");
        v = val_invalido();
        snprintf(v.rpn, RPN_BUF_SIZE, "x");
        return v;
    }

    /* Fora de uma avaliacao numerica ponto-a-ponto (plot/integrate/sum),
     * o valor concreto de x nao existe: usamos 0 como placeholder. A
     * substituicao real por cada amostra de x cabe ao avaliador
     * numerico de plot/integrate/sum (fase posterior, fora do escopo
     * desta analise semantica). */
    v = val_float(0.0f);
    snprintf(v.rpn, RPN_BUF_SIZE, "x");
    return v;
}

/* ================================================================== */
/* Operacoes binarias / unarias / funcoes                              */
/* ================================================================== */
static const char *nome_tipo(TipoValor t) {
    return (t == DCMAT_MATRIZ) ? "MATRIX" : "FLOAT";
}

static ValorDCMAT combina_rpn_bin(ValorDCMAT a, ValorDCMAT b, char op) {
    ValorDCMAT v = val_invalido();
    snprintf(v.rpn, RPN_BUF_SIZE, "%s %s %c", a.rpn, b.rpn, op);
    return v;
}

ValorDCMAT eval_binaria(char op, ValorDCMAT a, ValorDCMAT b) {
    /* Propaga invalidez sem gerar novas mensagens (evita cascata de   */
    /* erros a partir de um unico problema na subexpressao).           */
    if (a.tipo == DCMAT_INVALIDO || b.tipo == DCMAT_INVALIDO) {
        return combina_rpn_bin(a, b, op);
    }

    ValorDCMAT rpn_base = combina_rpn_bin(a, b, op);

    /* --- FLOAT x FLOAT --- */
    if (a.tipo == DCMAT_FLOAT && b.tipo == DCMAT_FLOAT) {
        float r;
        switch (op) {
            case '+': r = a.fval + b.fval; break;
            case '-': r = a.fval - b.fval; break;
            case '*': r = a.fval * b.fval; break;
            case '/': r = a.fval / b.fval; break; /* divisao por zero -> inf, secao 3.1 */
            case '%': r = fmodf(a.fval, b.fval); break;
            case '^': r = powf(a.fval, b.fval); break;
            default:  r = 0.0f; break;
        }
        ValorDCMAT v = val_float(r);
        strcpy(v.rpn, rpn_base.rpn);
        return v;
    }

    /* --- MATRIZ +/- MATRIZ (mesmas dimensoes) --- */
    if (a.tipo == DCMAT_MATRIZ && b.tipo == DCMAT_MATRIZ && (op == '+' || op == '-')) {
        if (a.mval.n_linhas != b.mval.n_linhas || a.mval.n_colunas != b.mval.n_colunas) {
            erro_semantico_msg(
                "Incorrect dimensions for operator '%c' - have MATRIX [%d][%d] and MATRIX [%d][%d]",
                op, a.mval.n_linhas, a.mval.n_colunas, b.mval.n_linhas, b.mval.n_colunas);
            ValorDCMAT v = val_invalido();
            strcpy(v.rpn, rpn_base.rpn);
            return v;
        }
        Matriz r;
        r.n_linhas = a.mval.n_linhas;
        r.n_colunas = a.mval.n_colunas;
        for (int i = 0; i < r.n_linhas; i++)
            for (int j = 0; j < r.n_colunas; j++)
                r.dados[i][j] = (op == '+')
                    ? a.mval.dados[i][j] + b.mval.dados[i][j]
                    : a.mval.dados[i][j] - b.mval.dados[i][j];
        ValorDCMAT v = val_matriz(r);
        strcpy(v.rpn, rpn_base.rpn);
        return v;
    }

    /* --- MATRIZ * MATRIZ (dimensoes compativeis: MxN * NxP) --- */
    if (a.tipo == DCMAT_MATRIZ && b.tipo == DCMAT_MATRIZ && op == '*') {
        if (a.mval.n_colunas != b.mval.n_linhas) {
            erro_semantico_msg(
                "Incorrect dimensions for operator '*' - have MATRIX [%d][%d] and MATRIX [%d][%d]",
                a.mval.n_linhas, a.mval.n_colunas, b.mval.n_linhas, b.mval.n_colunas);
            ValorDCMAT v = val_invalido();
            strcpy(v.rpn, rpn_base.rpn);
            return v;
        }
        Matriz r;
        r.n_linhas = a.mval.n_linhas;
        r.n_colunas = b.mval.n_colunas;
        for (int i = 0; i < r.n_linhas; i++) {
            for (int j = 0; j < r.n_colunas; j++) {
                float soma = 0.0f;
                for (int k = 0; k < a.mval.n_colunas; k++)
                    soma += a.mval.dados[i][k] * b.mval.dados[k][j];
                r.dados[i][j] = soma;
            }
        }
        ValorDCMAT v = val_matriz(r);
        strcpy(v.rpn, rpn_base.rpn);
        return v;
    }

    /* --- escalar * MATRIZ ou MATRIZ * escalar --- */
    if (op == '*' && ((a.tipo == DCMAT_MATRIZ && b.tipo == DCMAT_FLOAT) ||
                       (a.tipo == DCMAT_FLOAT && b.tipo == DCMAT_MATRIZ))) {
        Matriz base = (a.tipo == DCMAT_MATRIZ) ? a.mval : b.mval;
        float escalar = (a.tipo == DCMAT_FLOAT) ? a.fval : b.fval;
        Matriz r;
        r.n_linhas = base.n_linhas;
        r.n_colunas = base.n_colunas;
        for (int i = 0; i < r.n_linhas; i++)
            for (int j = 0; j < r.n_colunas; j++)
                r.dados[i][j] = base.dados[i][j] * escalar;
        ValorDCMAT v = val_matriz(r);
        strcpy(v.rpn, rpn_base.rpn);
        return v;
    }

    /* --- Qualquer outra combinacao envolvendo matriz: tipo invalido --- */
    erro_semantico_msg("Incorrect type for operator '%c' - have %s and %s",
                        op, nome_tipo(a.tipo), nome_tipo(b.tipo));
    ValorDCMAT v = val_invalido();
    strcpy(v.rpn, rpn_base.rpn);
    return v;
}

ValorDCMAT eval_unaria(char op, ValorDCMAT a) {
    ValorDCMAT v;
    if (a.tipo == DCMAT_INVALIDO) {
        v = val_invalido();
        snprintf(v.rpn, RPN_BUF_SIZE, "%s %cu", a.rpn, op);
        return v;
    }

    if (a.tipo == DCMAT_FLOAT) {
        v = val_float(op == '-' ? -a.fval : a.fval);
    } else {
        /* Sinal unario aplicado a uma matriz: nega/mantem elemento a  */
        /* elemento (o enunciado nao ilustra este caso explicitamente; */
        /* interpretacao adotada por analogia a soma/subtracao). */
        Matriz r = a.mval;
        if (op == '-') {
            for (int i = 0; i < r.n_linhas; i++)
                for (int j = 0; j < r.n_colunas; j++)
                    r.dados[i][j] = -r.dados[i][j];
        }
        v = val_matriz(r);
    }
    snprintf(v.rpn, RPN_BUF_SIZE, "%s %cu", a.rpn, op);
    return v;
}

ValorDCMAT eval_funcao(const char *nome_func, ValorDCMAT a) {
    ValorDCMAT v;
    if (a.tipo == DCMAT_INVALIDO) {
        v = val_invalido();
        snprintf(v.rpn, RPN_BUF_SIZE, "%s %s", a.rpn, nome_func);
        return v;
    }

    if (a.tipo == DCMAT_MATRIZ) {
        erro_semantico_msg("Incorrect type for operator '%s' - have MATRIX", nome_func);
        v = val_invalido();
        snprintf(v.rpn, RPN_BUF_SIZE, "%s %s", a.rpn, nome_func);
        return v;
    }

    float r = 0.0f;
    if (strcmp(nome_func, "SEN") == 0) r = sinf(a.fval);
    else if (strcmp(nome_func, "COS") == 0) r = cosf(a.fval);
    else if (strcmp(nome_func, "TAN") == 0) r = tanf(a.fval);
    else if (strcmp(nome_func, "ABS") == 0) r = fabsf(a.fval);

    v = val_float(r);
    snprintf(v.rpn, RPN_BUF_SIZE, "%s %s", a.rpn, nome_func);
    return v;
}

/* Impressao publica de um float com a precisao configurada, usada   */
/* pelas acoes semanticas de sintatico.y (atribuicao, expressao solta,*/
/* mostrar variavel, etc.). Declarada aqui para reuso simples.        */
void dcmat_imprime_float(float f) {
    imprime_float(f);
}

/* ================================================================== */
/* solve determinant / solve linear_system (secoes 1.18/1.19/5.7/5.8) */
/* ================================================================== */

/* Copia a matriz global para um buffer local de trabalho (evita       */
/* corromper matriz_global durante o escalonamento).                   */
static void copia_para_buffer(const Matriz *m, double buf[MAX_DIM][MAX_DIM + 1], int n_linhas, int n_colunas) {
    for (int i = 0; i < n_linhas; i++)
        for (int j = 0; j < n_colunas; j++)
            buf[i][j] = (double) m->dados[i][j];
}

void dcmat_solve_determinant(void) {
    if (!matriz_global_definida) {
        printf("No Matrix defined!\n");
        return;
    }

    Matriz *m = &matriz_global;
    if (m->n_linhas != m->n_colunas) {
        printf("Matrix format incorrect!\n");
        return;
    }

    int n = m->n_linhas;
    double buf[MAX_DIM][MAX_DIM + 1];
    copia_para_buffer(m, buf, n, n);

    double det = 1.0;
    for (int col = 0; col < n; col++) {
        int pivo = col;
        for (int i = col + 1; i < n; i++)
            if (fabs(buf[i][col]) > fabs(buf[pivo][col])) pivo = i;

        if (fabs(buf[pivo][col]) < 1e-9) { det = 0.0; break; }

        if (pivo != col) {
            for (int j = 0; j < n; j++) {
                double tmp = buf[col][j];
                buf[col][j] = buf[pivo][j];
                buf[pivo][j] = tmp;
            }
            det = -det;
        }

        det *= buf[col][col];
        for (int i = col + 1; i < n; i++) {
            double fator = buf[i][col] / buf[col][col];
            for (int j = col; j < n; j++)
                buf[i][j] -= fator * buf[col][j];
        }
    }

    dcmat_imprime_float((float) det);
}

void dcmat_solve_linear_system(void) {
    if (!matriz_global_definida) {
        printf("No Matrix defined!\n");
        return;
    }

    Matriz *m = &matriz_global;
    int n = m->n_linhas;
    if (m->n_colunas != n + 1) {
        printf("Matrix format incorrect!\n");
        return;
    }

    double buf[MAX_DIM][MAX_DIM + 1];
    copia_para_buffer(m, buf, n, n + 1);

    int posto_coef = 0, posto_aum = 0;
    int linha_atual = 0;

    for (int col = 0; col < n && linha_atual < n; col++) {
        int pivo = linha_atual;
        for (int i = linha_atual + 1; i < n; i++)
            if (fabs(buf[i][col]) > fabs(buf[pivo][col])) pivo = i;

        if (fabs(buf[pivo][col]) < 1e-9) continue;

        if (pivo != linha_atual) {
            for (int j = 0; j <= n; j++) {
                double tmp = buf[linha_atual][j];
                buf[linha_atual][j] = buf[pivo][j];
                buf[pivo][j] = tmp;
            }
        }

        for (int i = linha_atual + 1; i < n; i++) {
            double fator = buf[i][col] / buf[linha_atual][col];
            for (int j = col; j <= n; j++)
                buf[i][j] -= fator * buf[linha_atual][j];
        }
        linha_atual++;
    }

    /* posto (rank) da matriz de coeficientes e da matriz aumentada,   */
    /* apos o escalonamento, para classificar o sistema em SPD/SPI/SI. */
    for (int i = 0; i < n; i++) {
        int coef_nao_nulo = 0;
        for (int j = 0; j < n; j++)
            if (fabs(buf[i][j]) > 1e-9) { coef_nao_nulo = 1; break; }
        int aum_nao_nulo = coef_nao_nulo || fabs(buf[i][n]) > 1e-9;
        if (coef_nao_nulo) posto_coef++;
        if (aum_nao_nulo) posto_aum++;
    }

    if (posto_coef < posto_aum) {
        printf("SI - The Linear System has no solution\n");
        return;
    }
    if (posto_coef < n) {
        printf("SPI - The Linear System has infinitely many solutions\n");
        return;
    }

    /* SPD: retro-substituicao */
    double x[MAX_DIM];
    for (int i = n - 1; i >= 0; i--) {
        double soma = buf[i][n];
        for (int j = i + 1; j < n; j++) soma -= buf[i][j] * x[j];
        x[i] = soma / buf[i][i];
    }

    printf("Matrix x:\n");
    for (int i = 0; i < n; i++) dcmat_imprime_float((float) x[i]);
}

/* ================================================================== */
/* about (secao 1.20)                                                  */
/* ================================================================== */
void dcmat_about(void) {
    /* TODO: substituir pelo numero de matricula e nome do aluno,      */
    /* conforme exigido no enunciado (secao 1.20, "IMPORTANTE"). */
    printf("+------------------------------------------------+\n");
    printf("|                                                |\n");
    printf("|   DCMAT - CopyRight - Aluno DC-UEL             |\n");
    printf("|   Renan Jusan Fernandes Azevedo                |\n");
    printf("|   Num. Matricula: 202400560474                 |\n");
    printf("|   V. 2026.08                                   |\n");
    printf("|                                                |\n");
    printf("+------------------------------------------------+\n");
}

/* ================================================================== */
/* Pontos de extensao para avaliacao numerica (ver comentario no .h)  */
/* ================================================================== */
void dcmat_plot_stub(ValorDCMAT funcao) {
    (void) funcao;
    printf("No Function defined!\n");
    /* Substituir por: amostrar a expressao para x variando conforme
     * settings.h_view_lo/hi, calcular o range vertical, e desenhar o
     * grafico ASCII conforme settings.v_view_lo/hi,
     * settings.connect_dots_on e settings.axis_on. */
}

void dcmat_integrate_stub(float lim_inf, float lim_sup, ValorDCMAT funcao) {
    (void) funcao;
    if (lim_inf == lim_sup) {
        dcmat_imprime_float(0.0f);
        return;
    }
    /* Substituir por integracao numerica (ex.: regra do trapezio ou
     * Simpson) usando settings.integral_steps amostras da expressao,
     * substituindo x por cada ponto do intervalo [lim_inf, lim_sup]. */
    dcmat_imprime_float(0.0f);
}

void dcmat_sum_stub(const char *var, float lim_inf, float lim_sup, ValorDCMAT corpo) {
    (void) var;
    (void) corpo;
    if (lim_inf > lim_sup) return;
    /* Substituir por um loop que, para cada valor inteiro de 'var'
     * entre lim_inf e lim_sup, redefine o simbolo 'var' com
     * define_simbolo_float() e reavalia a expressao do corpo,
     * acumulando o somatorio. */
    dcmat_imprime_float(0.0f);
}
