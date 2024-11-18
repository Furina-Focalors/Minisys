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
%token AND_OP OR_OP NOT_OP ADDR_OP RIGHT_OP LEFT_OP
%token SEMICOLON LBRACE RBRACE COMMA COLON ASSIGN_OP
%token LPAREN RPAREN LBRACKET RBRACKET DOT BITAND_OP BITINV_OP BITXOR_OP BITOR_OP
%token _UNMATCH

%left NO_ELSE
%left ELSE

%right ASSIGN_OP
%left OR_OP
%left AND_OP
%left BITOR_OP
%left BITXOR_OP
%left BITAND_OP
%left EQ_OP NE_OP
%left GT_OP LT_OP GE_OP LE_OP
%left LEFT_OP RIGHT_OP
%left ADD_OP SUB_OP
%left MUL_OP DIV_OP MOD_OP
%right UPLUS UMINUS INC_OP DEC_OP NOT_OP BITINV_OP ADDR_OP

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
    | type_specifier IDENTIFIER LPAREN param_list RPAREN SEMICOLON
    | type_specifier IDENTIFIER LPAREN param_list RPAREN LBRACE statements RBRACE
    | type_specifier IDENTIFIER LPAREN VOID RPAREN SEMICOLON
    | type_specifier IDENTIFIER LPAREN VOID RPAREN LBRACE statements RBRACE
    ;

type_specifier:
      CHAR
    | INT
    | SHORT
    | VOID
    ;

param_list:
    | param_list COMMA type_specifier IDENTIFIER
    | type_specifier IDENTIFIER
    ;

array:
      IDENTIFIER LBRACKET expression RBRACKET
    ;

func_call:
    IDENTIFIER LPAREN arg_list RPAREN
    ;

arg_list:
    | arg_list COMMA expression
    | expression
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
    IDENTIFIER ASSIGN_OP expression SEMICOLON
    | array ASSIGN_OP expression SEMICOLON
    | ADDR_OP expression ASSIGN_OP expression SEMICOLON
    | expression SEMICOLON
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
    ADD_OP expression %prec UPLUS
    | SUB_OP expression %prec UMINUS
    | INC_OP IDENTIFIER
    | IDENTIFIER INC_OP
    | DEC_OP IDENTIFIER
    | IDENTIFIER DEC_OP
    | INC_OP array
    | array INC_OP
    | DEC_OP array
    | array DEC_OP
    | NOT_OP expression
    | BITINV_OP expression
    | ADDR_OP expression
    | expression MUL_OP expression
    | expression DIV_OP expression
    | expression MOD_OP expression
    | expression ADD_OP expression
    | expression SUB_OP expression
    | IDENTIFIER LEFT_OP expression
    | IDENTIFIER RIGHT_OP expression
    | array LEFT_OP expression
    | array RIGHT_OP expression
    | expression GT_OP expression
    | expression LT_OP expression
    | expression GE_OP expression
    | expression LE_OP expression
    | expression EQ_OP expression
    | expression NE_OP expression
    | expression BITAND_OP expression
    | expression BITXOR_OP expression
    | expression BITOR_OP expression
    | expression AND_OP expression
    | expression OR_OP expression
    | LPAREN expression RPAREN
    | IDENTIFIER
    | array
    | func_call
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
