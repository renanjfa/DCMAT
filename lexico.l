%option noyywrap
%option yylineno

%{

#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stdlib.h>

#include "sintatico.tab.h"

int coluna = 1;
int comment_line;
int comment_col;
int comment_level = 0;
int first = 1;

/* Buffer com o texto ja consumido da linha atual (declarado como
 * extern em sintatico.y). Usado para depuracao / mensagens de erro
 * que precisem exibir o que ja foi lido na linha corrente. */
#define LINHA_BUFFER_SIZE 1024
char linha_buffer[LINHA_BUFFER_SIZE];
static int pos_linha_buffer = 0;

void print_token(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);

    if (!first) printf("\n");
    vprintf(fmt, args);

    first = 0;
    va_end(args);
}

/* Acrescenta o lexema reconhecido ao linha_buffer, respeitando o
 * tamanho do buffer, e avanca o contador de coluna. Deve ser chamada
 * por (quase) toda regra que reconhece um token. */
static void avanca(const char* texto) {
    int len = strlen(texto);
    coluna += len;
    if (pos_linha_buffer + len < LINHA_BUFFER_SIZE - 1) {
        memcpy(linha_buffer + pos_linha_buffer, texto, len);
        pos_linha_buffer += len;
        linha_buffer[pos_linha_buffer] = '\0';
    }
}

/* Chamada ao final de cada linha (via '\n' ou apos descarte de erro)
 * para reiniciar o estado do buffer/coluna para a proxima linha. */
void finalizar_linha() {
    pos_linha_buffer = 0;
    linha_buffer[0] = '\0';
    coluna = 1;
}

/* Chamada pelo main() (sintatico.y) quando yyparse() retorna erro de
 * sintaxe, para descartar o restante da linha atual sem tokeniza-la,
 * evitando que sobras de uma linha invalida "vazem" para a proxima
 * chamada de yyparse(). */
static int input(void);

void descarta_resto_linha() {
    int c;
    while ((c = input()) != '\n' && c != EOF) {
        coluna++;
    }
    finalizar_linha();
}

%}

%%

[0-9]+ { avanca(yytext); return NUM_INTEGER; }

[0-9]+"."[0-9]+ { avanca(yytext); return NUM_REAL; }

"about" { avanca(yytext); return ABOUT; }

"abs" { avanca(yytext); return ABS; }

"axis" { avanca(yytext); return AXIS; }

"connect_dots" { avanca(yytext); return CONNECT_DOTS; }

"cos" { avanca(yytext); return COS; }

"determinant" { avanca(yytext); return DETERMINANT; }

"erase" { avanca(yytext); return ERASE; }

"float" { avanca(yytext); return FLOAT; }

"h_view" { avanca(yytext); return H_VIEW; }

"integral_steps" { avanca(yytext); return INTEGRAL_STEPS; }

"integrate" { avanca(yytext); return INTEGRATE; }

"linear_system" { avanca(yytext); return LINEAR_SYSTEM; }

"matrix" { avanca(yytext); return MATRIX; }

"off" { avanca(yytext); return OFF; }

"on" { avanca(yytext); return ON; }

"plot" { avanca(yytext); return PLOT; }

"precision" { avanca(yytext); return PRECISION; }

"quit" { avanca(yytext); return QUIT; }

"reset" { avanca(yytext); return RESET; }

"rpn" { avanca(yytext); return RPN; }

"sen" { avanca(yytext); return SEN; }

"set" { avanca(yytext); return SET; }

"settings" { avanca(yytext); return SETTINGS; }

"show" { avanca(yytext); return SHOW; }

"solve" { avanca(yytext); return SOLVE; }

"sum" { avanca(yytext); return SUM; }

"symbols" { avanca(yytext); return SYMBOLS; }

"tan" { avanca(yytext); return TAN; }

"v_view" { avanca(yytext); return V_VIEW; }

 /* pi, e (Euler) e x sao as UNICAS palavras reservadas que nao
    distinguem maiusculas de minusculas (PI, Pi, pI, pi / E, e / X, x) */
[Pp][Ii] { avanca(yytext); return PI; }

[Ee] { avanca(yytext); return EULER; }

[Xx] { avanca(yytext); return VARIAVEL; }



"+" { avanca(yytext); return ADICAO; }

"-" { avanca(yytext); return SUBTRACAO; }

"*" { avanca(yytext); return MULTIPLY; }

"/" { avanca(yytext); return DIVISION; }

"^" { avanca(yytext); return POTENCIACAO; }

"%" { avanca(yytext); return RESTO_DIVISAO; }

"(" { avanca(yytext); return LEFT_PAREN; }

")" { avanca(yytext); return RIGHT_PAREN; }

":=" { avanca(yytext); return ATRIBUICAO; }

":" { avanca(yytext); return COLON; }

"=" { avanca(yytext); return EQUAL; }

"[" { avanca(yytext); return L_SQUARE_BRACKET; }

"]" { avanca(yytext); return R_SQUARE_BRACKET; }

";" { avanca(yytext); return SEMICOLON; }

"," { avanca(yytext); return COMMA; }



[a-zA-Z_][a-zA-Z0-9_]* {
    avanca(yytext);

    if (yyleng > 255) {
        return ERROR;
    } else {
        return IDENTIFIER;
    }
}

\n {
    /* fim da linha: encerra a chamada atual de yyparse() (retorno 0
       sinaliza "fim de tokens" para o parser) e prepara o estado
       para a proxima linha/prompt. */
    finalizar_linha();
    return 0;
}

\r { /* ignorado: o \n de "\r\n" ja encerra a linha na regra acima */ }

[ \t]+ { avanca(yytext); }

. {
    /* Caractere invalido (secao 5.1): imprime a mensagem exigida e
       descarta o caractere sem repassa-lo ao parser como token, para
       nao gerar tambem um SYNTAX ERROR redundante. */
    printf("Invalid Symbol: %s\n", yytext);
    avanca(yytext);
}



%%
