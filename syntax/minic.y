%{
#include <stdio.h>
#include <stdlib.h>

// Declare tokens from Lex
%}

%token BREAK CHAR CONTINUE ELSE FOR IF INT SHORT RETURN VOID WHILE
%token IDENTIFIER CONSTANT STRING_LITERAL
%token ADD_OP SUB_OP MUL_OP DIV_OP MOD_OP
%token INC_OP DEC_OP
%token LE_OP GE_OP EQ_OP NE_OP LT_OP GT_OP
%token AND_OP OR_OP NOT_OP
%token SEMICOLON LBRACE RBRACE LPAREN RPAREN LBRACKET RBRACKET
%token COMMA COLON ASSIGN_OP

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
    | type_specifier IDENTIFIER LBRACKET CONSTANT RBRACKET SEMICOLON
    | type_specifier IDENTIFIER LPAREN param_list RPAREN compound_stmt
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

compound_stmt:
      LBRACE statements RBRACE
    ;

statements:
    | statements statement
    ;

statement:
      expression_stmt
    | compound_stmt
    | if_stmt
    | while_stmt
    | return_stmt
    | break_stmt
    | continue_stmt
    | for_stmt
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
    | simple_expr
    ;

simple_expr:
    ADD_OP simple_expr %prec UPLUS
    | SUB_OP simple_expr %prec UMINUS
    | INC_OP simple_expr
    | simple_expr INC_OP
    | DEC_OP simple_expr
    | simple_expr DEC_OP
    | NOT_OP simple_expr
    | simple_expr MUL_OP simple_expr
    | simple_expr DIV_OP simple_expr
    | simple_expr MOD_OP simple_expr
    | simple_expr ADD_OP simple_expr
    | simple_expr SUB_OP simple_expr
    | simple_expr GT_OP simple_expr
    | simple_expr LT_OP simple_expr
    | simple_expr GE_OP simple_expr
    | simple_expr LE_OP simple_expr
    | simple_expr EQ_OP simple_expr
    | simple_expr NE_OP simple_expr
    | simple_expr AND_OP simple_expr
    | simple_expr OR_OP simple_expr
    | IDENTIFIER
    | CONSTANT
    ;
    

%%
int main() {
    return yyparse();
}

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
}
