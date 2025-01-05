%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include "ast.h"
#include "symbol_table.h"

int yylex(void);
void yyerror(const char *format, ...);

ASTNode* root = NULL;

#define PARAM_BUF_MAX 32
FuncParam* paramsBuf[PARAM_BUF_MAX];
int paramNum = 0;

// used to check function parameters
char* funcName = NULL;
%}

%union {
    ASTNode* node;
}

%token <node> INT_CONSTANT CHAR_CONSTANT
%token <node> IDENTIFIER STRING_LITERAL
%token <node> _COMMENT BREAK CONTINUE ELSE FOR IF RETURN WHILE CHAR INT SHORT VOID
%token <node> ADD_OP SUB_OP MUL_OP DIV_OP MOD_OP INC_OP DEC_OP
%token <node> LE_OP GE_OP EQ_OP NE_OP LT_OP GT_OP
%token <node> AND_OP OR_OP NOT_OP ADDR_OP RIGHT_OP LEFT_OP
%token <node> SEMICOLON LBRACE RBRACE COMMA COLON ASSIGN_OP
%token <node> LPAREN RPAREN LBRACKET RBRACKET DOT BITAND_OP BITINV_OP BITXOR_OP BITOR_OP
%token _UNMATCH

%type <node> program declarations declaration type_specifier param_list params param array func_call arg_list func_head
%type <node> statements statement if_stmt for_stmt break_stmt while_stmt return_stmt continue_stmt expression_stmt expression
%type <node> enter_scope leave_scope

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
    declarations                   {
        // this will NOT be executed until yyparse() terminated
        $$ = createASTNode("PROGRAM", 1, $1);
        preorderPrint($$);
        }
    ;

declarations:
                                    { $$ = NULL; }
    | declarations declaration      { $$ = createASTNode("DECLARATIONS", 2, $1, $2); }
    ;

declaration:
      type_specifier IDENTIFIER SEMICOLON   {
        // insert into symbol table
        SymbolTableEntry* entry = createSymbolTableEntry($2->id, $1->id, $1->int_val, 0, 0, 0, 0, 0, 0, NULL);
        int res = insertSymbol(scopeStack[scopeStackTop-1], entry);
        if (res != 0) {
            yyerror("Redefinition of symbol %s.\n", $2->id);
        }

        $$ = createASTNode("DECLARATION", 3, $1, $2, $3);
      }
    | type_specifier array SEMICOLON    {
        // insert into symbol table
        SymbolTableEntry* entry = createSymbolTableEntry($2->id, $1->id, $2->int_val*$1->int_val, 0, 1, 0, 0, 0, 0, NULL);
        int res = insertSymbol(scopeStack[scopeStackTop-1], entry);
        if (res != 0) {
            yyerror("Redefinition of symbol %s.\n", $2->id);
        }

        $$ = createASTNode("DECLARATION", 3, $1, $2, $3);
    }
    | func_head SEMICOLON                                           {
        funcName = NULL; // this means we are not in the scope of this function
        $$ = createASTNode("DECLARATION", 2, $1, $2);
    }
    | func_head LBRACE enter_scope statements leave_scope RBRACE    { $$ = createASTNode("DECLARATION", 4, $1, $2, $4, $6); }
    ;

enter_scope:
    { scopeStack[scopeStackTop++] = createSymbolTable(); }
    ;

leave_scope:
    {
        // when leaving a local scope, the symbol table of it will be DELETED
        destroySymbolTable(scopeStack[--scopeStackTop]);
    }
    ;

type_specifier:
      CHAR      { $$ = createASTNode("CHAR", 1, $1); $$->int_val = 1; }
    | INT       { $$ = createASTNode("INT", 1, $1); $$->int_val = 4; }
    | SHORT     { $$ = createASTNode("SHORT", 1, $1); $$->int_val = 2; }
    | VOID      { $$ = createASTNode("VOID", 1, $1); }
    ;

func_head:
    type_specifier IDENTIFIER LPAREN param_list RPAREN          {
        FuncParam** params = NULL;
        if (paramNum > 0) {
            params = (FuncParam**)malloc(sizeof(FuncParam*) * paramNum);
            for (int i = 0; i < paramNum; ++i) {
                params[i] = paramsBuf[i];
            }
        }
        SymbolTableEntry* entry = createSymbolTableEntry($2->id, $1->id, 0, 0, 0, 1, 0, 0, paramNum, params);
        int res = insertSymbol(scopeStack[scopeStackTop-1], entry);
        if (res != 0) {
            yyerror("Redefinition of symbol %s.\n", $2->id);
        }
        // reset buffer
        paramNum = 0;
        // if in function definition, this will help check names of parameters
        funcName = $2->id;

        $$ = createASTNode("FUNC_HEAD", 5, $1, $2, $3, $4, $5);
    }
;

param_list:
    VOID                                            { $$ = NULL; }
    | params                                        { $$ = createASTNode("PARAM_LIST", 1, $1); }

params:
                                                    { $$ = NULL; }
    | params COMMA param                            { $$ = createASTNode("PARAMS", 3, $1, $2, $3); }
    | param                                         { $$ = createASTNode("PARAMS", 1, $1); }
    ;

param:
    type_specifier IDENTIFIER                       {
        if (paramNum > PARAM_BUF_MAX) {
            yyerror("Too many parameters in function.\n");
        }
        paramsBuf[paramNum++] = createFuncParam($1->id, $2->id, $1->int_val, 0);
        $$ = createASTNode("PARAM", 2, $1, $2);
    }        
    | type_specifier IDENTIFIER LBRACKET RBRACKET   {
        // note that as a param of the func, size of the array is unknown, so we store the size of its single element.
        paramsBuf[paramNum++] = createFuncParam($1->id, $2->id, $1->int_val, 1);
        $$ = createASTNode("PARAM", 2, $1, $2);
    }
    ;

array:
      IDENTIFIER LBRACKET INT_CONSTANT RBRACKET     { $$ = createASTNode("ARRAY", 4, $1, $2, $3, $4); $$->int_val=$3->int_val; }
    ;

func_call:
    IDENTIFIER LPAREN arg_list RPAREN               { $$ = createASTNode("FUNC_CALL", 4, $1, $2, $3, $4); }
    ;

arg_list:
                                    { $$ = NULL; }
    | arg_list COMMA expression     { $$ = createASTNode("ARG_LIST", 3, $1, $2, $3); }
    | expression                    { $$ = createASTNode("ARG_LIST", 1, $1); }
    ;

statements:
                                    { $$ = NULL; }
    | statements statement          { $$ = createASTNode("STATEMENTS", 2, $1, $2); }
    ;

statement:
      expression_stmt                                       { $$ = createASTNode("STATEMENT", 1, $1); }
    | LBRACE enter_scope statements leave_scope RBRACE      { $$ = createASTNode("STATEMENT", 3, $1, $3, $5); }
    | if_stmt                                               { $$ = createASTNode("STATEMENT", 1, $1); }
    | while_stmt                                            { $$ = createASTNode("STATEMENT", 1, $1); }
    | return_stmt                                           { $$ = createASTNode("STATEMENT", 1, $1); }
    | break_stmt                                            { $$ = createASTNode("STATEMENT", 1, $1); }
    | continue_stmt                                         { $$ = createASTNode("STATEMENT", 1, $1); }
    | for_stmt                                              { $$ = createASTNode("STATEMENT", 1, $1); }
    | declaration                                           { $$ = createASTNode("STATEMENT", 1, $1); }
    ;

expression_stmt:
    IDENTIFIER ASSIGN_OP expression SEMICOLON               { $$ = createASTNode("EXPR_STMT", 4, $1, $2, $3, $4); }
    | array ASSIGN_OP expression SEMICOLON                  { $$ = createASTNode("EXPR_STMT", 4, $1, $2, $3, $4); }
    | ADDR_OP expression ASSIGN_OP expression SEMICOLON     { $$ = createASTNode("EXPR_STMT", 5, $1, $2, $3, $4, $5); }
    | expression SEMICOLON                                  { $$ = createASTNode("EXPR_STMT", 2, $1, $2); }
    | SEMICOLON                                             { $$ = createASTNode("EXPR_STMT", 1, $1); }
    ;

if_stmt:
      IF LPAREN expression RPAREN statement %prec NO_ELSE   {
        $$ = createASTNode("IF_STMT", 5, $1, $2, $3, $4, $5);
      }
    | IF LPAREN expression RPAREN statement ELSE statement  {
        $$ = createASTNode("IF_STMT", 7, $1, $2, $3, $4, $5, $6, $7);
    }
    ;

while_stmt:
      WHILE LPAREN expression RPAREN statement  {
        $$ = createASTNode("WHILE_STMT", 5, $1, $2, $3, $4, $5);
      }
    ;

return_stmt:
      RETURN expression SEMICOLON       { $$ = createASTNode("RETURN_STMT", 3, $1, $2, $3); }
    | RETURN SEMICOLON                  { $$ = createASTNode("RETURN_STMT", 2, $1, $2); }
    ;

break_stmt:
      BREAK SEMICOLON                   { $$ = createASTNode("BREAK_STMT", 2, $1, $2); }
    ;

continue_stmt:
      CONTINUE SEMICOLON                { $$ = createASTNode("CONTINUE_STMT", 2, $1, $2); }
    ;

for_stmt:
      FOR LPAREN expression_stmt expression_stmt expression RPAREN statement {
        $$ = createASTNode("FOR_STMT", 7, $1, $2, $3, $4, $5, $6, $7);
      }
    ;

expression:
    ADD_OP expression %prec UPLUS           { $$ = createASTNode("EXPR", 2, $1, $2); }
    | SUB_OP expression %prec UMINUS        { $$ = createASTNode("EXPR", 2, $1, $2); }
    | INC_OP IDENTIFIER                     { $$ = createASTNode("EXPR", 2, $1, $2); }
    | IDENTIFIER INC_OP                     { $$ = createASTNode("EXPR", 2, $1, $2); }
    | DEC_OP IDENTIFIER                     { $$ = createASTNode("EXPR", 2, $1, $2); }
    | IDENTIFIER DEC_OP                     { $$ = createASTNode("EXPR", 2, $1, $2); }
    | INC_OP array                          { $$ = createASTNode("EXPR", 2, $1, $2); }
    | array INC_OP                          { $$ = createASTNode("EXPR", 2, $1, $2); }
    | DEC_OP array                          { $$ = createASTNode("EXPR", 2, $1, $2); }
    | array DEC_OP                          { $$ = createASTNode("EXPR", 2, $1, $2); }
    | NOT_OP expression                     { $$ = createASTNode("EXPR", 2, $1, $2); }
    | BITINV_OP expression                  { $$ = createASTNode("EXPR", 2, $1, $2); }
    | ADDR_OP expression                    { $$ = createASTNode("EXPR", 2, $1, $2); }
    | expression MUL_OP expression          { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression DIV_OP expression          { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression MOD_OP expression          { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression ADD_OP expression          { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression SUB_OP expression          { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | IDENTIFIER LEFT_OP expression         { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | IDENTIFIER RIGHT_OP expression        { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | array LEFT_OP expression              { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | array RIGHT_OP expression             { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression GT_OP expression           { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression LT_OP expression           { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression GE_OP expression           { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression LE_OP expression           { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression EQ_OP expression           { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression NE_OP expression           { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression BITAND_OP expression       { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression BITXOR_OP expression       { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression BITOR_OP expression        { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression AND_OP expression          { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | expression OR_OP expression           { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | LPAREN expression RPAREN              { $$ = createASTNode("EXPR", 3, $1, $2, $3); }
    | IDENTIFIER                            { $$ = createASTNode("EXPR", 1, $1); }
    | array                                 { $$ = createASTNode("EXPR", 1, $1); }
    | func_call                             { $$ = createASTNode("EXPR", 1, $1); }
    | INT_CONSTANT                          { $$ = createASTNode("EXPR", 1, $1); }
    | CHAR_CONSTANT                         { $$ = createASTNode("EXPR", 1, $1); }
    | STRING_LITERAL                        { $$ = createASTNode("EXPR", 1, $1); }
    ;
    

%%
void yyerror(const char *format, ...){
    extern int yylineno;
    fprintf(stderr, "Error at line %d: ", yylineno);

    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);

    exit(1);
}

int yywrap(){
    return 1;
}

/*
int main()
{
    yyparse();
    return 0;
}
*/
