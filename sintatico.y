%locations

%code requires {#include "dcmat.h"}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex();
extern char* yytext;
extern FILE* yyin;
extern void print_token();
extern void finalizar_linha();
extern void descarta_resto_linha();   /* consome o resto da linha apos um erro sintatico */
extern char linha_buffer[];

void yyerror(const char *s);

/* Flag para quit do programa (1 == quit) */
int dcmat_quit = 0;

%}

%union {
    ValorDCMAT val;      /* NUM_INTEGER, NUM_REAL, Expressao, Funcao, Valor, MatrizValor */
    char sval[256];      /* IDENTIFIER */
    LinhaBruta linha;    /* Linha, ListaValores */
    MatrizBruta bruta;   /* ListaLinhas */
    int ival;            /* Estado (on/off) */
}

%token <val> NUM_INTEGER NUM_REAL 
%token <sval> IDENTIFIER
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

%type <val> Expressao Funcao MatrizValor Valor
%type <linha> Linha ListaValores
%type <bruta> ListaLinhas
%type <ival> Estado

/* Precedencia dos operadores */
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
       | Expressao { 
            if (!erro_semantico) {
                if ($1.tipo == DCMAT_FLOAT) dcmat_imprime_float($1.fval);
                 else if ($1.tipo == DCMAT_MATRIZ) imprime_matriz(&$1.mval);
            }
        }
;

/* ---------------------------------------------------------------- */
/* 1.1 / 2.4 show settings | show matrix | show symbols             */
/* ---------------------------------------------------------------- */
Comando_Show: SHOW SETTINGS SEMICOLON { imprime_settings(); }
            | SHOW MATRIX SEMICOLON {
                  if (matriz_global_definida) imprime_matriz(&matriz_global);
                  else printf("No Matrix defined!\n");
              }

            | SHOW SYMBOLS SEMICOLON { imprime_symbols(); }
;

/* ---------------------------------------------------------------- */
/* 1.3 quit (unico comando sem ponto-e-virgula)                     */
/* ---------------------------------------------------------------- */
Comando_Quit: QUIT { dcmat_quit = 1; }
;

/* ---------------------------------------------------------------- */
/* 1.2 reset settings                                                */
/* ---------------------------------------------------------------- */
Comando_Reset: RESET SETTINGS SEMICOLON { reset_settings(); }
;

/* ---------------------------------------------------------------- */
/* 1.4 - 1.7 / 1.10 - 1.11 / 1.13 / 4.1 set ...                      */
/* ---------------------------------------------------------------- */
Comando_Set: SET Set_Opcao SEMICOLON
;

Set_Opcao: H_VIEW Valor COLON Valor {
               if ($2.fval >= $4.fval)
                   erro_semantico_msg("ERROR: h_view_lo must be smaller than h_view_hi");
               else {
                   settings.h_view_lo = $2.fval;
                   settings.h_view_hi = $4.fval;
               }
           }
         | V_VIEW Valor COLON Valor {
               if ($2.fval >= $4.fval)
                   erro_semantico_msg("ERROR: v_view_lo must be smaller than v_view_hi");
               else {
                   settings.v_view_lo = $2.fval;
                   settings.v_view_hi = $4.fval;
               }
           }
         | AXIS Estado { settings.axis_on = $2; }
         | ERASE PLOT Estado { settings.erase_plot_on = $3; }
         | INTEGRAL_STEPS Valor {
            if ($2.fval <= 0)
                erro_semantico_msg("ERROR: integral_steps must be a positive non-zero integer");
            else
                settings.integral_steps = (int) $2.fval;
          }
         | FLOAT PRECISION Valor {
               int p = (int) $3.fval;
               if (p < 0 || p > 8)
                   erro_semantico_msg("ERROR: float precision must be from 0 to 8");
               else
                   settings.float_precision = p;
           }
         | CONNECT_DOTS Estado { settings.connect_dots_on = $2; }
;

Estado: ON  { $$ = 1; }
      | OFF { $$ = 0; }
;

/* ---------------------------------------------------------------- */
/* 1.8 / 1.9 plot; | plot(funcao);                                  */
/* ---------------------------------------------------------------- */
Comando_Plot: PLOT Plot_Opcional
;

Plot_Opcional: SEMICOLON {printf("No Function defined!\n");}
             | LEFT_PAREN { dentro_contexto_x = 1; } Expressao { dentro_contexto_x = 0; } RIGHT_PAREN SEMICOLON {
                   if (!erro_semantico) dcmat_plot_stub($3);
               }
;

/* ---------------------------------------------------------------- */
/* 1.12 rpn(expressao);                                             */
/* ---------------------------------------------------------------- */
Comando_RPN: RPN LEFT_PAREN { modo_rpn = 1; dentro_contexto_x = 1; } Expressao { modo_rpn = 0; dentro_contexto_x = 0; } RIGHT_PAREN SEMICOLON {
                   printf("Expression in RPN format:\n%s\n", $4.rpn);
             }
;

/* ---------------------------------------------------------------- */
/* 1.14 integrate(limite_inf:limite_sup, funcao);                   */
/* ---------------------------------------------------------------- */
Comando_Integrate: INTEGRATE LEFT_PAREN Expressao COLON Expressao COMMA
                        { dentro_contexto_x = 1; }
                    Expressao
                        { dentro_contexto_x = 0; }
                    RIGHT_PAREN SEMICOLON {
                        if (!erro_semantico) {
                            if ($3.tipo != DCMAT_FLOAT || $5.tipo != DCMAT_FLOAT) {
                                erro_semantico_msg("Incorrect type for operator 'integrate' - limits must be FLOAT");
                            } else if ($3.fval > $5.fval) {
                                erro_semantico_msg("ERROR: lower limit must be smaller than upper limit");
                            } else {
                                dcmat_integrate_stub($3.fval, $5.fval, $8);
                            }
                        }
                    }
;

/* ---------------------------------------------------------------- */
/* 1.15 sum(variavel, limite_inf:limite_sup, expressao);            */
/* ---------------------------------------------------------------- */
Comando_Sum: SUM LEFT_PAREN IDENTIFIER COMMA Expressao COLON Expressao COMMA
                 { define_simbolo_float($3, $5.fval); }
             Expressao RIGHT_PAREN SEMICOLON {
                 if (!erro_semantico) {
                     if ($5.tipo != DCMAT_FLOAT || $7.tipo != DCMAT_FLOAT) {
                         erro_semantico_msg("Incorrect type for operator 'sum' - limits must be FLOAT");
                     } else {
                         dcmat_sum_stub($3, $5.fval, $7.fval, $10);
                     }
                 }
             }
;

/* ---------------------------------------------------------------- */
/* 1.16 matrix = [ [valor,...], ... ];  (matriz "global")           */
/* ---------------------------------------------------------------- */
Comando_Matrix: MATRIX EQUAL MatrizValor SEMICOLON {
                    if ($3.tipo == DCMAT_MATRIZ) {
                        matriz_global = $3.mval;
                        matriz_global_definida = 1;
                    }
                }
;

/* ---------------------------------------------------------------- */
/* 1.18 / 1.19 solve determinant; | solve linear_system;            */
/* ---------------------------------------------------------------- */
Comando_Solve: SOLVE DETERMINANT SEMICOLON { dcmat_solve_determinant(); }
             | SOLVE LINEAR_SYSTEM SEMICOLON { dcmat_solve_linear_system(); }
;

/* ---------------------------------------------------------------- */
/* 1.20 about;                                                       */
/* ---------------------------------------------------------------- */
Comando_About: ABOUT SEMICOLON { dcmat_about(); }
;

/* ---------------------------------------------------------------- */
/* 2.1 / 2.2 [variavel] := [expressao|matriz] ;                     */
/* Como MatrizValor eh uma das alternativas de Expressao, esta      */
/* unica regra cobre tanto atribuicao escalar quanto matricial.     */
/* ---------------------------------------------------------------- */
Atribuir_Valor_Matriz: IDENTIFIER ATRIBUICAO Expressao SEMICOLON {
                            if (!erro_semantico) {
                                if ($3.tipo == DCMAT_FLOAT) {
                                    define_simbolo_float($1, $3.fval);
                                    dcmat_imprime_float($3.fval);
                                } else if ($3.tipo == DCMAT_MATRIZ) {
                                    define_simbolo_matriz($1, $3.mval);
                                    imprime_matriz(&$3.mval);
                                }
                            }
                        }
;

/* ---------------------------------------------------------------- */
/* 2.3 [variavel] ;  -> mostra o valor (escalar ou matriz) do simbolo */
/* ---------------------------------------------------------------- */
Mostrar_Variavel_Matriz: IDENTIFIER SEMICOLON {
                              Simbolo *s = busca_simbolo($1);
                              if (s == NULL) {
                                  printf("Undefined symbol\n");
                              } else if (s->tipo == TIPO_FLOAT) {
                                  printf("%s = ", $1);
                                  dcmat_imprime_float(s->valor_float);
                              } else {
                                  imprime_matriz(&s->valor_matriz);
                              }
                          }
;

/* ---------------------------------------------------------------- */
/* 1.16 / 2.2  Literal de matriz: [ [v,v,...], [v,...], ... ]       */
/* ---------------------------------------------------------------- */
MatrizValor: L_SQUARE_BRACKET ListaLinhas R_SQUARE_BRACKET { $$ = constroi_matriz($2); }
;

ListaLinhas: Linha { $$ = matriz_bruta_inicial($1); }
           | ListaLinhas COMMA Linha { $$ = matriz_bruta_acrescenta($1, $3); }
;

Linha: L_SQUARE_BRACKET ListaValores R_SQUARE_BRACKET { $$ = $2; }
;

ListaValores: Valor {
                  $$.n = 1;
                  $$.vals[0] = $1.fval;
              }
            | ListaValores COMMA Valor {
                  $$ = $1;
                  if ($$.n < MAX_DIM) $$.vals[$$.n] = $3.fval;
                  $$.n++;
              }
;

/* Valor: numero real/inteiro, podendo ter sinal explicito. Usado   */
/* dentro de literais de matriz e em parametros como h_view/v_view/ */
/* integral_steps/float precision.                                  */
Valor: NUM_INTEGER { $$ = $1; }
     | NUM_REAL { $$ = $1; }
     | ADICAO NUM_INTEGER { $$ = $2; }
     | ADICAO NUM_REAL { $$ = $2; }
     | SUBTRACAO NUM_INTEGER { $$ = $2; $$.fval = -$$.fval; }
     | SUBTRACAO NUM_REAL { $$ = $2; $$.fval = -$$.fval; }
;

/* ---------------------------------------------------------------- */
/* 3.1 / 3.2  Avaliacao de expressoes (numericas e matriciais)      */
/* ---------------------------------------------------------------- */
Expressao: Expressao ADICAO Expressao { $$ = eval_binaria('+', $1, $3); }
         | Expressao SUBTRACAO Expressao { $$ = eval_binaria('-', $1, $3); }
         | Expressao MULTIPLY Expressao { $$ = eval_binaria('*', $1, $3); }
         | Expressao DIVISION Expressao { $$ = eval_binaria('/', $1, $3); }
         | Expressao RESTO_DIVISAO Expressao { $$ = eval_binaria('%', $1, $3); }
         | Expressao POTENCIACAO Expressao { $$ = eval_binaria('^', $1, $3); }
         | ADICAO Expressao %prec UPLUS { $$ = eval_unaria('+', $2); }
         | SUBTRACAO Expressao %prec UMINUS { $$ = eval_unaria('-', $2); }
         | LEFT_PAREN Expressao RIGHT_PAREN { $$ = $2; }
         | Funcao { $$ = $1; }
         | MatrizValor { $$ = $1; }
         | NUM_INTEGER { $$ = $1; }
         | NUM_REAL { $$ = $1; }
         | PI { $$ = val_float(3.14159265358979323846f); snprintf($$.rpn, RPN_BUF_SIZE, "pi"); }
         | EULER { $$ = val_float(2.71828182845904523536f); snprintf($$.rpn, RPN_BUF_SIZE, "e"); }
         | VARIAVEL { $$ = eval_variavel_x(); }
         | IDENTIFIER { $$ = eval_identifier($1); }
;

Funcao: SEN LEFT_PAREN Expressao RIGHT_PAREN { $$ = eval_funcao("SEN", $3); }
      | COS LEFT_PAREN Expressao RIGHT_PAREN { $$ = eval_funcao("COS", $3); }
      | TAN LEFT_PAREN Expressao RIGHT_PAREN { $$ = eval_funcao("TAN", $3); }
      | ABS LEFT_PAREN Expressao RIGHT_PAREN { $$ = eval_funcao("ABS", $3); }
;

%%

void yyerror(const char *s) {
    
    if (yytext == NULL || yytext[0] == '\0') {
        printf("SYNTAX ERROR: Incomplete Command\n");
    } else if (yytext[0] == '\n') {
        printf("SYNTAX ERROR: [quebra de linha]\n");
    } else {
        printf("SYNTAX ERROR: [%s]\n", yytext);
    }
}

int main(int argc, char **argv) {

    reset_settings();

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

        erro_semantico = 0; /* acumulador de erros semanticos, um por comando/linha */

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

    libera_simbolos();

    if (yyin != stdin) {
        fclose(yyin);
    }

    return 0;
}
