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

// buffer para mensagem de erro
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

// Acrescenta o lexema reconhecido ao linha_buffer, respeitando o tamanho do buffer, e avanca o contador de coluna
static void avanca(const char* texto) {
    int len = strlen(texto);
    coluna += len;
    if (pos_linha_buffer + len < LINHA_BUFFER_SIZE - 1) {
        memcpy(linha_buffer + pos_linha_buffer, texto, len);
        pos_linha_buffer += len;
        linha_buffer[pos_linha_buffer] = '\0';
    }
}

// chamado dps de \n para reiniciar o buffer
void finalizar_linha() {
    pos_linha_buffer = 0;
    linha_buffer[0] = '\0';
    coluna = 1;
}

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

[0-9]+ {    
    avanca(yytext); 
    yylval.val.tipo = DCMAT_FLOAT;
    yylval.val.fval = (float) atof(yytext);  // transformacao float
    strncpy(yylval.val.rpn, yytext, RPN_BUF_SIZE - 1);
    yylval.val.rpn[RPN_BUF_SIZE - 1] = '\0';
    return NUM_INTEGER; 
}

[0-9]+"."[0-9]+ { 
    avanca(yytext); 
    yylval.val.tipo = DCMAT_FLOAT;
    yylval.val.fval = (float) atof(yytext);
    strncpy(yylval.val.rpn, yytext, RPN_BUF_SIZE - 1);
    yylval.val.rpn[RPN_BUF_SIZE - 1] = '\0';
    return NUM_REAL; 
}

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
        strncpy(yylval.sval, yytext, 255);
        yylval.sval[255] = '\0';
        return IDENTIFIER;
    }
}

\n {
    finalizar_linha();
    return 0;
}

\r { }

[ \t]+ { avanca(yytext); }

. {
    printf("Invalid Symbol: %s\n", yytext);
    avanca(yytext);
}



%%
