%{
#include <stdio.h>
#include <stdlib.h>

int yylex(void);
void yyerror(char *);

// Declare tokens from Lex
%}

%token _COMMENT BREAK CHAR CONTINUE ELSE FOR IF INT SHORT RETURN VOID WHILE CONSTANT IDENTIFIER STRING_LITERAL
%token ADD_OP SUB_OP MUL_OP DIV_OP MOD_OP INC_OP DEC_OP
%token LE_OP GE_OP EQ_OP NE_OP LT_OP GT_OP
%token AND_OP OR_OP NOT_OP DOLLAR RIGHT_OP LEFT_OP
%token SEMICOLON LBRACE RBRACE COMMA COLON ASSIGN_OP
%token LPAREN RPAREN LBRACKET RBRACKET DOT BITAND_OP BITINV_OP BITXOR BITOR
%token _UNMATCH

%left NO_ELSE
%left ELSE

%right ASSIGN_OP
%left OR_OP
%left AND_OP
%left EQ_OP NE_OP
%left GT_OP LT_OP GE_OP LE_OP
%left ADD_OP SUB_OP
%left MUL_OP DIV_OP MOD_OP
%right UPLUS UMINUS INC_OP DEC_OP NOT_OP

%%
program:
    declarations
    ;

declarations:
    | declarations declaration
    ;

declaration:
      type_specifier IDENTIFIER SEMICOLON
    | type_specifier array SEMICOLON
    | type_specifier IDENTIFIER LPAREN param_list RPAREN LBRACE statements RBRACE
    ;

type_specifier:
      CHAR
    | INT
    | SHORT
    | VOID
    ;

array:
      IDENTIFIER LBRACKET CONSTANT RBRACKET
    ;

param_list:
    | param_list COMMA type_specifier IDENTIFIER
    | type_specifier IDENTIFIER
    ;

statements:
    | statements statement
    ;

statement:
      expression_stmt
    | LBRACE statements RBRACE
    | if_stmt
    | while_stmt
    | return_stmt
    | break_stmt
    | continue_stmt
    | for_stmt
    | declaration
    ;

expression_stmt:
      expression SEMICOLON
    | SEMICOLON
    ;

if_stmt:
      IF LPAREN expression RPAREN statement %prec NO_ELSE
    | IF LPAREN expression RPAREN statement ELSE statement
    ;

while_stmt:
      WHILE LPAREN expression RPAREN statement
    ;

return_stmt:
      RETURN expression SEMICOLON
    | RETURN SEMICOLON
    ;

break_stmt:
      BREAK SEMICOLON
    ;

continue_stmt:
      CONTINUE SEMICOLON
    ;

for_stmt:
      FOR LPAREN expression_stmt expression_stmt expression RPAREN statement
    ;

expression:
    IDENTIFIER ASSIGN_OP expression
    | array ASSIGN_OP expression
    | ADD_OP expression %prec UPLUS
    | SUB_OP expression %prec UMINUS
    | INC_OP expression
    | expression INC_OP
    | DEC_OP expression
    | expression DEC_OP
    | NOT_OP expression
    | expression MUL_OP expression    { printf("multiply\n"); }
    | expression DIV_OP expression
    | expression MOD_OP expression
    | expression ADD_OP expression
    | expression SUB_OP expression
    | expression GT_OP expression
    | expression LT_OP expression
    | expression GE_OP expression
    | expression LE_OP expression
    | expression EQ_OP expression
    | expression NE_OP expression
    | expression AND_OP expression
    | expression OR_OP expression
    | LPAREN expression RPAREN
    | IDENTIFIER
    | array
    | CONSTANT
    ;
    

%%
void yyerror(char *str){
    fprintf(stderr,"error:%s\n",str);
}

int yywrap(){
    return 1;
}
int main()
{
    yyparse();
}
