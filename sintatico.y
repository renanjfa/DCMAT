%locations

%{
#include <stdio.h>
#include <stdlib.h>

extern int yylex();
extern char* yytext;
extern FILE* yyin;
extern void print_token();
extern void finalizar_linha();
extern void descarta_resto_linha();   /* consome o resto da linha apos um erro de sintaxe */
extern char linha_buffer[];

void yyerror(const char *s);

/* Fica ligado (1) quando o comando "quit" e reconhecido, para o loop principal encerrar. */
int dcmat_quit = 0;

%}

%token NUM_INTEGER NUM_REAL IDENTIFIER
%token ABOUT ABS AXIS
%token CONNECT_DOTS COS 
%token DETERMINANT
%token EULER ERASE
%token FLOAT
%token H_VIEW
%token INTEGRAL_STEPS INTEGRATE
%token LINEAR_SYSTEM
%token MATRIX
%token OFF ON
%token PI PLOT PRECISION
%token QUIT
%token RESET RPN
%token SEN SET SETTINGS SHOW SOLVE SUM SYMBOLS
%token TAN
%token V_VIEW VARIAVEL
%token ADICAO SUBTRACAO MULTIPLY DIVISION POTENCIACAO RESTO_DIVISAO
%token LEFT_PAREN RIGHT_PAREN 
%token COLON SEMICOLON COMMA
%token EQUAL ATRIBUICAO
%token L_SQUARE_BRACKET R_SQUARE_BRACKET
%token ERROR

/*
 * Precedencia dos operadores, da menor para a maior.
 * UMINUS/UPLUS tratam o sinal unario de + e -.
 * A potenciacao fica acima do sinal unario para que
 * -2^2 seja interpretado como -(2^2), seguindo a convencao matematica usual.
 */
%left ADICAO SUBTRACAO
%left MULTIPLY DIVISION RESTO_DIVISAO
%precedence UMINUS UPLUS
%right POTENCIACAO

%start Programa

%%

Programa: Comando
        |
;

Comando: Comando_Show
       | Comando_Reset
       | Comando_Quit
       | Comando_Set 
       | Comando_Plot
       | Comando_RPN
       | Comando_Integrate
       | Comando_Sum
       | Comando_Matrix
       | Comando_Solve
       | Comando_About
       | Atribuir_Valor_Matriz
       | Mostrar_Variavel_Matriz
       | Expressao
;

/* ---------------------------------------------------------------- */
/* 1.1 / 2.4 show settings | show matrix | show symbols             */
/* ---------------------------------------------------------------- */
Comando_Show: SHOW SETTINGS SEMICOLON
            | SHOW MATRIX SEMICOLON
            | SHOW SYMBOLS SEMICOLON
;

/* ---------------------------------------------------------------- */
/* 1.3 quit (unico comando sem ponto-e-virgula)                     */
/* ---------------------------------------------------------------- */
Comando_Quit: QUIT { dcmat_quit = 1; }
;

/* ---------------------------------------------------------------- */
/* 1.2 reset settings                                                */
/* ---------------------------------------------------------------- */
Comando_Reset: RESET SETTINGS SEMICOLON
;

/* ---------------------------------------------------------------- */
/* 1.4 - 1.7 / 1.10 - 1.11 / 1.13 / 4.1 set ...                      */
/* ---------------------------------------------------------------- */
Comando_Set: SET Set_Opcao SEMICOLON
;

Set_Opcao: H_VIEW Valor COLON Valor
         | V_VIEW Valor COLON Valor
         | AXIS Estado
         | ERASE PLOT Estado
         | INTEGRAL_STEPS Valor
         | FLOAT PRECISION Valor
         | CONNECT_DOTS Estado
;

Estado: ON
      | OFF
;

/* ---------------------------------------------------------------- */
/* 1.8 / 1.9 plot; | plot(funcao);                                  */
/* ---------------------------------------------------------------- */
Comando_Plot: PLOT Plot_Opcional
;

Plot_Opcional: SEMICOLON {printf("No Function defined!\n");}
             | LEFT_PAREN Expressao RIGHT_PAREN SEMICOLON
;

/* ---------------------------------------------------------------- */
/* 1.12 rpn(expressao);                                             */
/* ---------------------------------------------------------------- */
Comando_RPN: RPN LEFT_PAREN Expressao RIGHT_PAREN SEMICOLON
;

/* ---------------------------------------------------------------- */
/* 1.14 integrate(limite_inf:limite_sup, funcao);                   */
/* ---------------------------------------------------------------- */
Comando_Integrate: INTEGRATE LEFT_PAREN Expressao COLON Expressao COMMA Expressao RIGHT_PAREN SEMICOLON
;

/* ---------------------------------------------------------------- */
/* 1.15 sum(variavel, limite_inf:limite_sup, expressao);            */
/* ---------------------------------------------------------------- */
Comando_Sum: SUM LEFT_PAREN IDENTIFIER COMMA Expressao COLON Expressao COMMA Expressao RIGHT_PAREN SEMICOLON
;

/* ---------------------------------------------------------------- */
/* 1.16 matrix = [ [valor,...], ... ];  (matriz "global")           */
/* ---------------------------------------------------------------- */
Comando_Matrix: MATRIX EQUAL MatrizValor SEMICOLON
;

/* ---------------------------------------------------------------- */
/* 1.18 / 1.19 solve determinant; | solve linear_system;            */
/* ---------------------------------------------------------------- */
Comando_Solve: SOLVE DETERMINANT SEMICOLON
             | SOLVE LINEAR_SYSTEM SEMICOLON
;

/* ---------------------------------------------------------------- */
/* 1.20 about;                                                       */
/* ---------------------------------------------------------------- */
Comando_About: ABOUT SEMICOLON
;

/* ---------------------------------------------------------------- */
/* 2.1 / 2.2 [variavel] := [expressao|matriz] ;                     */
/* Como MatrizValor eh uma das alternativas de Expressao, esta      */
/* unica regra cobre tanto atribuicao escalar quanto matricial.     */
/* ---------------------------------------------------------------- */
Atribuir_Valor_Matriz: IDENTIFIER ATRIBUICAO Expressao SEMICOLON
;

/* ---------------------------------------------------------------- */
/* 2.3 [variavel] ;  -> mostra o valor (escalar ou matriz) do simbolo */
/* ---------------------------------------------------------------- */
Mostrar_Variavel_Matriz: IDENTIFIER SEMICOLON
;

/* ---------------------------------------------------------------- */
/* 1.16 / 2.2  Literal de matriz: [ [v,v,...], [v,...], ... ]       */
/* ---------------------------------------------------------------- */
MatrizValor: L_SQUARE_BRACKET ListaLinhas R_SQUARE_BRACKET
;

ListaLinhas: Linha
           | ListaLinhas COMMA Linha
;

Linha: L_SQUARE_BRACKET ListaValores R_SQUARE_BRACKET
;

ListaValores: Valor
            | ListaValores COMMA Valor
;

/* Valor: numero real/inteiro, podendo ter sinal explicito. Usado   */
/* dentro de literais de matriz e em parametros como h_view/v_view/ */
/* integral_steps/float precision.                                  */
Valor: NUM_INTEGER
     | NUM_REAL
     | ADICAO NUM_INTEGER
     | ADICAO NUM_REAL
     | SUBTRACAO NUM_INTEGER
     | SUBTRACAO NUM_REAL
;

/* ---------------------------------------------------------------- */
/* 3.1 / 3.2  Avaliacao de expressoes (numericas e matriciais)      */
/* ---------------------------------------------------------------- */
Expressao: Expressao ADICAO Expressao
         | Expressao SUBTRACAO Expressao
         | Expressao MULTIPLY Expressao
         | Expressao DIVISION Expressao
         | Expressao RESTO_DIVISAO Expressao
         | Expressao POTENCIACAO Expressao
         | ADICAO Expressao %prec UPLUS
         | SUBTRACAO Expressao %prec UMINUS
         | LEFT_PAREN Expressao RIGHT_PAREN
         | Funcao
         | MatrizValor
         | NUM_INTEGER
         | NUM_REAL
         | PI
         | EULER
         | VARIAVEL
         | IDENTIFIER
;

Funcao: SEN LEFT_PAREN Expressao RIGHT_PAREN
      | COS LEFT_PAREN Expressao RIGHT_PAREN
      | TAN LEFT_PAREN Expressao RIGHT_PAREN
      | ABS LEFT_PAREN Expressao RIGHT_PAREN
;

%%

void yyerror(const char *s) {
    /* A distincao entre "SYNTAX ERROR: [token]" e
     * "SYNTAX ERROR: Incomplete Command" (secao 5.2 do enunciado)
     * deve ser feita aqui, verificando se o erro ocorreu por falta
     * de mais tokens (fim de linha, ou seja yytext vazio / so "\0")
     * ou por um token inesperado no meio do comando.
     */
    if (yytext == NULL || yytext[0] == '\0') {
        printf("SYNTAX ERROR: Incomplete Command\n");
    } else if (yytext[0] == '\n') {
        printf("SYNTAX ERROR: [quebra de linha]\n");
    } else {
        printf("SYNTAX ERROR: [%s]\n", yytext);
    }
}

int main(int argc, char **argv) {

    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) {
            fprintf(stderr, "Nao foi possivel abrir o arquivo %s\n", argv[1]);
            return 1;
        }
    } else {
        yyin = stdin;
    }

    printf(">");
    fflush(stdout);

    /* Cada chamada de yyparse() consome exatamente UMA linha, pois a
     * regra de '\n' no flex devolve 0 (fim de tokens para o parser).
     * Por isso o loop chama yyparse() repetidamente ate o quit ou o EOF. */
    while (!dcmat_quit && !feof(yyin)) {

        int resultado = yyparse();

        if (resultado != 0) {
            /* erro de sintaxe: yyerror() ja imprimiu a mensagem.
             * descarta o que sobrou da linha para nao vazar para o
             * proximo comando. */
            descarta_resto_linha();
        }

        if (dcmat_quit) {
            break;
        }

        if (!feof(yyin)) {
            printf(">");
            fflush(stdout);
        }
    }

    if (yyin != stdin) {
        fclose(yyin);
    }

    return 0;
}
