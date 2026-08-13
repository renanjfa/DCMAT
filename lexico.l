%option noyywrap
%option yylineno

%{

#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <stdlib.h>

int coluna = 1;
int comment_line;
int comment_col;
int comment_level = 0;
int first = 1;

void print_token(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);

    if (!first) printf("\n");
    vprintf(fmt, args);

    first = 0;
    va_end(args);
}

%}

%%

[0-9]+ {
    print_token("NUM_INTEGER(%s)", yytext);
    coluna += yyleng;
}

[0-9]+"."[0-9]+ {
    print_token("NUM_REAL(%s)", yytext);
    coluna += yyleng;
}



"about" {
    print_token("ABOUT");
    coluna += yyleng;
}

"abs" {
    print_token("ABS");
    coluna += yyleng;
}

"axis" {
    print_token("AXIS");
    coluna += yyleng;
}

"connect_dots" {
    print_token("CONNECT_DOTS");
    coluna += yyleng;
}

"cos" {
    print_token("COS");
    coluna += yyleng;
}

"determinant" {
    print_token("DETERMINANT");
    coluna += yyleng;
}

"e" {
    print_token("EULER");
    coluna += yyleng;
}

"erase" {
    print_token("ERASE");
    coluna += yyleng;
}

"float" {
    print_token("FLOAT");
    coluna += yyleng;
}

"h_view" {
    print_token("H_VIEW");
    coluna += yyleng;
}

"integral_steps" {
    print_token("INTEGRAL_STEPS");
    coluna += yyleng;
}

"integrate" {
    print_token("INTEGRATE");
    coluna += yyleng;
}

"linear_system" {
    print_token("LINEAR_SYSTEM");
    coluna += yyleng;
}

"matrix" {
    print_token("MATRIX");
    coluna += yyleng;
}

"off" {
    print_token("OFF");
    coluna += yyleng;
}

"on" {
    print_token("ON");
    coluna += yyleng;
}

"pi" {
    print_token("PI");
    coluna += yyleng;
}

"plot" {
    print_token("PLOT");
    coluna += yyleng;
}

"precision" {
    print_token("PRECISION");
    coluna += yyleng;
}

"quit" {
    print_token("QUIT");
    coluna += yyleng;
}

"reset" {
    print_token("RESET");
    coluna += yyleng;
}

"rpn" {
    print_token("RPN");
    coluna += yyleng;
}

"sen" {
    print_token("SEN");
    coluna += yyleng;
}

"set" {
    print_token("SET");
    coluna += yyleng;
}

"settings" {
    print_token("SETTINGS");
    coluna += yyleng;
}

"show" {
    print_token("SHOW");
    coluna += yyleng;
}

"solve" {
    print_token("SOLVE");
    coluna += yyleng;
}

"sum" {
    print_token("SUM");
    coluna += yyleng;
}

"symbols" {
    print_token("SYMBOLS");
    coluna += yyleng;
}

"tan" {
    print_token("TAN");
    coluna += yyleng;
}

"v_view" {
    print_token("V_VIEW");
    coluna += yyleng;
}

"x" {
    print_token("VARIAVEL");
    coluna += yyleng;
}



"+" {
    print_token("ADICAO");
    coluna += yyleng;
}

"-" {
    print_token("SUBTRACAO");
    coluna += yyleng;
}

"*" {
    print_token("MULTIPLY");
    coluna += yyleng;
}

"/" {
    print_token("DIVISION");
    coluna += yyleng;
}

"^" {
    print_token("POTENCIACAO");
    coluna += yyleng;
}

"%" {
    print_token("RESTO_DIVISAO");
    coluna += yyleng;
}

"(" {
    print_token("LEFT_PAREN");
    coluna += yyleng;
}

")" {
    print_token("RIGHT_PAREN");
    coluna += yyleng;
}

":" {
    print_token("COLON");
    coluna += yyleng;
}

"=" {
    print_token("EQUAL");
    coluna += yyleng;
}

":=" {
    print_token("ATRIBUICAO");
    coluna += yyleng;
}

"[" {
    print_token("L_SQUARE_BRACKET");
    coluna += yyleng;
}

"]" {
    print_token("R_SQUARE_BRACKET");
    coluna += yyleng;
}

";" {
    print_token("SEMICOLON");
    coluna += yyleng;
}

"," {
    print_token("COMMA");
    coluna += yyleng;
}



[a-zA-Z_][a-zA-Z0-9_]* {
    int start_col = coluna;
    coluna += yyleng;

    if (yyleng > 255) {
        print_token(
            "error:lexical:%d:%d: identifier too long",
            yylineno,
            start_col
        );
    } else {
        print_token("IDENTIFIER(%s)", yytext);
    }
}



\n {
    coluna = 1;
}

\r {
    coluna = 1;
}

[ \t]+ {
    coluna += yyleng;
}



. {
    print_token(
        "error:lexical:%d:%d: %s",
        yylineno,
        coluna,
        yytext
    );

    coluna += yyleng;
}

%%

int main() {
    yylex();
    return 0;
}