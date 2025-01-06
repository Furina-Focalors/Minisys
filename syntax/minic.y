%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include "ast.h"
#include "symbol_table.h"
#include "semantic.h"

int yylex(void);
void yyerror(const char *format, ...);

ASTNode* root = NULL;

// stores the params of function
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
%token <node> _COMMENT BREAK CONST CONTINUE ELSE FOR IF RETURN WHILE CHAR INT SHORT VOID
%token <node> ADD_OP SUB_OP MUL_OP DIV_OP MOD_OP INC_OP DEC_OP
%token <node> LE_OP GE_OP EQ_OP NE_OP LT_OP GT_OP
%token <node> AND_OP OR_OP NOT_OP ADDR_OP RIGHT_OP LEFT_OP
%token <node> SEMICOLON LBRACE RBRACE COMMA COLON ASSIGN_OP
%token <node> LPAREN RPAREN LBRACKET RBRACKET DOT BITAND_OP BITINV_OP BITXOR_OP BITOR_OP
%token _UNMATCH

%type <node> program declarations declaration type_specifier param_list params param array func_call arg_list func_head
%type <node> statements statement if_stmt for_stmt break_stmt while_stmt return_stmt continue_stmt expression_stmt expression
%type <node> prefix enter_scope leave_scope var_assignment array_assignment array_element array_declaration

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
        //preorderPrint($$);
        }
    ;

declarations:
                                    { $$ = NULL; }
    | declarations declaration      { $$ = createASTNode("DECLARATIONS", 2, $1, $2); }
    ;

declaration:
    type_specifier IDENTIFIER var_assignment SEMICOLON              {
        // type check 1. void type is not allowed for variables
        if (strcmp($1->id, "VOID") == 0) {
            yyerror("Cannot declare variable as 'void' type.\n");
        }

        int isInitialized = 0;
        if ($3 != NULL) {
            isInitialized = 1;
            // type check 2 for type consistency of lvalue and rvalue
            if (!isCompatible($1->id, $3->id)) {
                yyerror("Incompatible type for variable %s.\n", $2->id);
            }
        }
        // insert into symbol table
        SymbolTableEntry* entry = createSymbolTableEntry($2->id, $1->id, $1->int_val, isInitialized, 0, 0, 0, 0, 0, NULL);
        int res = insertSymbol(scopeStack[scopeStackTop-1], entry);
        // redefinition check
        if (res != 0) {
            yyerror("Redefinition of symbol %s.\n", $2->id);
        }

        $$ = createASTNode("DECLARATION", 4, $1, $2, $3, $4);
    }
    | prefix type_specifier IDENTIFIER var_assignment SEMICOLON     {
        // type check 1. void type is not allowed for variables
        if (strcmp($2->id, "VOID") == 0) {
            yyerror("Cannot declare variable as 'void' type.\n");
        }

        int isInitialized = 0;
        if ($4 != NULL) {
            isInitialized = 1;
            // type check 2 for type consistency of lvalue and rvalue
            if (!isCompatible($2->id, $4->id)) {
                yyerror("Incompatible type for variable %s.\n", $3->id);
            }
        }
        // insert into symbol table
        SymbolTableEntry* entry = createSymbolTableEntry($3->id, $2->id, $2->int_val, isInitialized, 0, 0, 0, 0, 0, NULL);
        // set const types
        if ($1 != NULL && $1->id == "CONST") {
            // const check
            if ($4->isConst == 0) {
                yyerror("Value of const variables should be const expression.\n");
            }
            if (strcmp($2->id, "CHAR") == 0) {
                entry->constType = CONST_CHAR;
                entry->constValue.charVal = $4->char_val;
            } else if (strcmp($2->id, "SHORT") == 0 || strcmp($2->id, "INT") == 0) {
                entry->constType = CONST_INT;
                entry->constValue.intVal = $4->int_val;
            } else {
                yyerror("Unknown error when resolving const.\n");
            }
        }
        int res = insertSymbol(scopeStack[scopeStackTop-1], entry);
        // redefinition check
        if (res != 0) {
            yyerror("Redefinition of symbol %s.\n", $3->id);
        }

        $$ = createASTNode("DECLARATION", 5, $1, $2, $3, $4, $5);
      }
    | type_specifier array_declaration array_assignment SEMICOLON           {
        // type check. void type is not allowed for variables
        if (strcmp($1->id, "VOID") == 0) {
            yyerror("Cannot declare variable as 'void' type.\n");
        }
        
        int isInitialized = 0;
        if ($3 != NULL) {
            isInitialized = 1;
            // type check 2 for type consistency of lvalue and rvalue
            if (!isCompatible($1->id, $3->id)) {
                yyerror("Incompatible type for variable %s.\n", $2->id);
            }
        }

        SymbolTableEntry* entry = createSymbolTableEntry($2->id, $1->id, $1->int_val*$2->int_val, isInitialized, 1, 0, 0, 0, 0, NULL);
        int res = insertSymbol(scopeStack[scopeStackTop-1], entry);
        // redefinition check
        if (res != 0) {
            yyerror("Redefinition of symbol %s.\n", $2->id);
        }

        $$ = createASTNode("DECLARATION", 4, $1, $2, $3, $4);
    }
    | prefix type_specifier array_declaration array_assignment SEMICOLON    {
        // type check. void type is not allowed for variables
        if (strcmp($2->id, "VOID") == 0) {
            yyerror("Cannot declare variable as 'void' type.\n");
        }
        
        int isInitialized = 0;
        if ($4 != NULL) {
            isInitialized = 1;
            // type check 2 for type consistency of lvalue and rvalue
            if (!isCompatible($2->id, $4->id)) {
                yyerror("Incompatible type for variable %s.\n", $3->id);
            }
        }

        SymbolTableEntry* entry = createSymbolTableEntry($3->id, $2->id, $3->int_val*$2->int_val, isInitialized, 1, 0, 0, 0, 0, NULL);
        
        // set const types
        if ($1->id == "CONST") {
            // const check
            if ($4->isConst == 0) {
                yyerror("Value of const variables should be const expression.\n");
            }
            if (strcmp($2->id, "CHAR") == 0) {
                entry->constType = CONST_CHAR;
                entry->constValue.charVal = $4->char_val;
            } else if (strcmp($2->id, "SHORT") == 0 || strcmp($2->id, "INT") == 0) {
                entry->constType = CONST_INT;
                entry->constValue.intVal = $4->int_val;
            } else {
                yyerror("Unknown error when resolving const.\n");
            }
        }
        // insert into symbol table
        int res = insertSymbol(scopeStack[scopeStackTop-1], entry);
        // redefinition check
        if (res != 0) {
            yyerror("Redefinition of symbol %s.\n", $3->id);
        }

        $$ = createASTNode("DECLARATION", 5, $1, $2, $3, $4, $5);
    }
    | func_head SEMICOLON                                           {
        funcName = NULL; // this means we are not in the scope of this function
        $$ = createASTNode("DECLARATION", 2, $1, $2);
    }
    | func_head LBRACE enter_scope statements leave_scope RBRACE    { $$ = createASTNode("DECLARATION", 4, $1, $2, $4, $6); }
    ;

prefix:
    CONST         { $$ = createASTNode("CONST", 1, $1); }
    ;

var_assignment:
                                                { $$ = NULL; }
    | ASSIGN_OP expression                      {
        // expr type
        $$ = createASTNode($2->id, 2, $1, $2);
        $$->isConst = $2->isConst;
        // parse value if isConst
        if ($2->isConst == 1) {
            if (strcmp($2->id, "CHAR") == 0) {
                $$->char_val = $2->char_val;
            } else {
                $$->int_val = $2->int_val;
            }
        }
    }
    ;

array_assignment:
                                                { $$ = NULL; }
    | ASSIGN_OP LBRACE array_element RBRACE     {
        $$ = createASTNode($3->id, 4, $1, $2, $3, $4);
    }
    | ASSIGN_OP STRING_LITERAL                  {
        $$ = createASTNode("CHAR", 2, $1, $2);
        $$->str_val = $2->str_val;
    }
    | ASSIGN_OP IDENTIFIER                      {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($2->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $2->id);
        }
        // array type check
        if (entry->isArray == 0) {
            yyerror("Cannot assign non-array variable to an array variable.\n");
        }
        $$ = createASTNode(entry->type, 2, $1, $2);
        if (entry->constType == NON_CONST) {
            $$->isConst = 0;
        } else {
            $$->isConst = 1;
        }
    }
    ;

enter_scope:
    { scopeStack[scopeStackTop++] = createSymbolTable(); }
    ;

leave_scope:
    {
        //printSymbolTable(scopeStack[scopeStackTop-1]);
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
        // redefinition check
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
    ;

params:
                                                    { $$ = NULL; }
    | params COMMA param                            { $$ = createASTNode("PARAMS", 3, $1, $2, $3); }
    | param                                         { $$ = createASTNode("PARAMS", 1, $1); }
    ;

param:
    type_specifier IDENTIFIER                               {
        if (paramNum > PARAM_BUF_MAX) {
            yyerror("Too many parameters in function.\n");
        }
        paramsBuf[paramNum++] = createFuncParam($1->id, $2->id, $1->int_val, 0);
        $$ = createASTNode("PARAM", 2, $1, $2);
        $$->isConst = 0;
    }        
    | type_specifier IDENTIFIER LBRACKET RBRACKET           {
        if (paramNum > PARAM_BUF_MAX) {
            yyerror("Too many parameters in function.\n");
        }
        // note that as a param of the func, size of the array is unknown, so we store the size of its single element.
        paramsBuf[paramNum++] = createFuncParam($1->id, $2->id, $1->int_val, 1);
        $$ = createASTNode("PARAM", 2, $1, $2);
        $$->isConst = 0;
    }
    ;

array_declaration:
    IDENTIFIER LBRACKET expression RBRACKET     {
        // index type check
        if (!isNum($3->id)) {
            yyerror("Invalid index for variable %s.\n", $1->id);
        }
        // const check
        if ($3->isConst == 0) {
            yyerror("Array size should be non-const.\n");
        }
        $$ = createASTNode($1->id, 4, $1, $2, $3, $4);
        // during declaration, this will be the size of an array.
        $$->int_val = $3->int_val;
    }
    ;

array:
    IDENTIFIER LBRACKET expression RBRACKET     {
        // index type check
        if (!isNum($3->id)) {
            yyerror("Invalid index for variable %s.\n", $1);
        }
        $$ = createASTNode($1->id, 4, $1, $2, $3, $4);
        // we currently do not do optimization for array elements even if it is const
        $$->isConst = 0;
    }
    ;

array_element:
                                        { $$ = NULL; }
    | array_element COMMA expression    {
        // check if all of the elements have the same type
        if (strcmp($1->id, $3->id) != 0) {
            yyerror("Element type should be consistent.\n");
        }
        // set type of array element
        $$ = createASTNode($3->id, 3, $1, $2, $3);
    }
    | expression                        {
        // check if expression type is valid
        if (!isNum($1->id) && !isChar($1->id)) {
            yyerror("Unsupported type for array element.\n");
        }
        $$ = createASTNode($1->id, 1, $1);
    }
    ;

func_call:
    IDENTIFIER LPAREN arg_list RPAREN               {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // check the type of params
        for (int i=0;i<paramNum;++i) {
            if (!isCompatible(paramsBuf[i]->type, entry->params[i]->type)) {
                yyerror("Incompatible parameter type. Expects %s, but received %s.\n", entry->params[i]->type, paramsBuf[i]->type);
            }
        }
        $$ = createASTNode(entry->type, 4, $1, $2, $3, $4);
        // func call is never const
        $$->isConst = 0;
    }
    ;

arg_list:
                                    { $$ = NULL; }
    | arg_list COMMA expression     {
        if (paramNum > PARAM_BUF_MAX) {
            yyerror("Too many parameters in function.\n");
        }
        // save type of the params for type check
        paramsBuf[paramNum++] = createFuncParam($3->id, NULL, 0, 0);
        $$ = createASTNode("ARG_LIST", 3, $1, $2, $3);
        // we currently consider all arguments non-const
        $$->isConst = 0;
    }
    | expression                    {
        paramsBuf[paramNum++] = createFuncParam($1->id, NULL, 0, 0);
        $$ = createASTNode("ARG_LIST", 1, $1);
        // we currently consider all arguments non-const
        $$->isConst = 0;
    }
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
    IDENTIFIER ASSIGN_OP expression SEMICOLON               {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // type check 2 for type consistency of lvalue and rvalue
        if (!isCompatible(entry->type, $3->id)) {
            yyerror("Incompatible type for variable %s.\n", $1->id);
        }
        // parse value if isConst
        if (entry->constType != NON_CONST && $3->isConst == 1) {
            if (strcmp($3->id, "CHAR") == 0) {
                entry->constValue.charVal = $3->char_val;
            } else {
                entry->constValue.intVal = $3->int_val;
            }
        }

        $$ = createASTNode("EXPR_STMT", 4, $1, $2, $3, $4);
    }
    | array ASSIGN_OP expression SEMICOLON                  {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // type check 2 for type consistency of lvalue and rvalue
        if (!isCompatible(entry->type, $3->id)) {
            yyerror("Incompatible type for variable %s.\n", $1->id);
        }
        // parse value if isConst
        if (entry->constType != NON_CONST && $3->isConst == 1) {
            if (strcmp($3->id, "CHAR") == 0) {
                entry->constValue.charVal = $3->char_val;
            } else {
                entry->constValue.intVal = $3->int_val;
            }
        }

        $$ = createASTNode("EXPR_STMT", 4, $1, $2, $3, $4);
    }
    | ADDR_OP expression ASSIGN_OP expression SEMICOLON     {
        // type check
        if (!isNum($2->id)) {
            yyerror("Address can only be integers.\n");
        }

        $$ = createASTNode("EXPR_STMT", 5, $1, $2, $3, $4, $5);
    }
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
    ADD_OP expression %prec UPLUS           {
        // type check
        if (!isNum($2->id)) {
            yyerror("Incompatible type for plus operator.\n");
        }
        $$ = createASTNode($2->id, 2, $1, $2);
        $$->isConst = $2->isConst;
        if ($2->isConst == 1) {
            $$->int_val = $$->int_val;
        }
    }
    | SUB_OP expression %prec UMINUS        {
        // type check
        if (!isNum($2->id)) {
            yyerror("Incompatible type for minus operator.\n");
        }
        $$ = createASTNode($2->id, 2, $1, $2);
        $$->isConst = $2->isConst;
        if ($2->isConst == 1) {
            $$->int_val = -$$->int_val;
        }
    }
    | INC_OP IDENTIFIER                     {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($2->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $2->id);
        }
        // const check
        if (entry->constType != NON_CONST) {
            yyerror("Expression should be non-const left value.\n");
        }
        // type check
        if (!isNum(entry->type)) {
            yyerror("Incompatible type for increment operator.\n");
        }
        $$ = createASTNode(entry->type, 2, $1, $2);
        $$->isConst = 0;
    }
    | IDENTIFIER INC_OP                     {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // const check
        if (entry->constType != NON_CONST) {
            yyerror("Expression should be non-const left value.\n");
        }
        // type check
        if (!isNum(entry->type)) {
            yyerror("Incompatible type for increment operator.\n");
        }
        $$ = createASTNode(entry->type, 2, $1, $2);
        $$->isConst = 0;
    }
    | DEC_OP IDENTIFIER                     {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($2->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $2->id);
        }
        // const check
        if (entry->constType != NON_CONST) {
            yyerror("Expression should be non-const left value.\n");
        }
        // type check
        if (!isNum(entry->type)) {
            yyerror("Incompatible type for decrement operator.\n");
        }
        $$ = createASTNode(entry->type, 2, $1, $2);
        $$->isConst = 0;
    }
    | IDENTIFIER DEC_OP                     {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // const check
        if (entry->constType != NON_CONST) {
            yyerror("Expression should be non-const left value.\n");
        }
        // type check
        if (!isNum(entry->type)) {
            yyerror("Incompatible type for decrement operator.\n");
        }
        $$ = createASTNode(entry->type, 2, $1, $2);
        $$->isConst = 0;
    }
    | INC_OP array                          {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($2->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $2->id);
        }
        // const check
        if (entry->constType != NON_CONST) {
            yyerror("Expression should be non-const left value.\n");
        }
        // type check
        if (!isNum(entry->type)) {
            yyerror("Incompatible type for increment operator.\n");
        }
        $$ = createASTNode(entry->type, 2, $1, $2);
        $$->isConst = 0;
    }
    | array INC_OP                          {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // const check
        if (entry->constType != NON_CONST) {
            yyerror("Expression should be non-const left value.\n");
        }
        // type check
        if (!isNum(entry->type)) {
            yyerror("Incompatible type for increment operator.\n");
        }
        $$ = createASTNode(entry->type, 2, $1, $2);
        $$->isConst = 0;
    }
    | DEC_OP array                          {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($2->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $2->id);
        }
        // const check
        if (entry->constType != NON_CONST) {
            yyerror("Expression should be non-const left value.\n");
        }
        // type check
        if (!isNum(entry->type)) {
            yyerror("Incompatible type for decrement operator.\n");
        }
        $$ = createASTNode(entry->type, 2, $1, $2);
        $$->isConst = 0;
    }
    | array DEC_OP                          {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // const check
        if (entry->constType != NON_CONST) {
            yyerror("Expression should be non-const left value.\n");
        }
        // type check
        if (!isNum(entry->type)) {
            yyerror("Incompatible type for decrement operator.\n");
        }
        $$ = createASTNode(entry->type, 2, $1, $2);
        $$->isConst = 0;
    }
    | NOT_OP expression                     {
        // type check
        if (!isNum($2->id)) {
            yyerror("Incompatible type for not operator.\n");
        }
        $$ = createASTNode($2->id, 2, $1, $2);
        $$->isConst = $2->isConst;
        // parse value if isConst
        if ($2->isConst == 1) {
            int val = 1;
            if ($2->int_val != 0) {
                val = 0;
            }
            $$->int_val = val;
        }
    }
    | BITINV_OP expression                  {
        // type check
        if (!isNum($2->id) && !isChar($2->id)) {
            yyerror("Incompatible type for not operator.\n");
        }
        $$ = createASTNode($2->id, 2, $1, $2);
        $$->isConst = $2->isConst;
        // parse value if isConst
        if ($2->isConst == 1) {
            if (strcmp($2->id, "CHAR") == 0) {
                $$->char_val = ~($2->char_val);
            } else {
                $$->int_val = ~($2->int_val);
            }
        }
    }
    | ADDR_OP expression                    {
        // type check
        if (!isNum($2->id)) {
            yyerror("Incompatible type for not operator.\n");
        }
        // addr operation is never considered const and have 'MEM' type.
        // the compiler will NOT perform any type check for MEM.
        $$ = createASTNode("MEM", 2, $1, $2);
        $$->isConst = 0;
    }
    | expression MUL_OP expression          {
        // type check
        if (!isNum($1->id) || !isNum($3->id)) {
            yyerror("Incompatible type for multiply operator.\n");
        }
        $$ = createASTNode($1->id, 3, $1, $2, $3);
        $$->isConst = $1->isConst && $2->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val * $3->int_val;
        }
    }
    | expression DIV_OP expression          {
        // type check
        if (!isNum($1->id) || !isNum($3->id)) {
            yyerror("Incompatible type for divide operator.\n");
        }
        $$ = createASTNode($1->id, 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val / $3->int_val;
        }
    }
    | expression MOD_OP expression          {
        // type check
        if (!isNum($1->id) || !isNum($3->id)) {
            yyerror("Incompatible type for modulo operator.\n");
        }
        $$ = createASTNode($1->id, 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val % $3->int_val;
        }
    }
    | expression ADD_OP expression          {
        // type check
        if (!isNum($1->id) || !isNum($3->id)) {
            yyerror("Incompatible type for add operator.\n");
        }
        $$ = createASTNode($1->id, 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val + $3->int_val;
        }
    }
    | expression SUB_OP expression          {
        // type check
        if (!isNum($1->id) || !isNum($3->id)) {
            yyerror("Incompatible type for sub operator.\n");
        }
        $$ = createASTNode($1->id, 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val - $3->int_val;
        }
    }
    | IDENTIFIER LEFT_OP expression         {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // type check
        if (!isNum(entry->type) || !isNum($3->id)) {
            yyerror("Incompatible type for left operator.\n");
        }
        $$ = createASTNode(entry->type, 3, $1, $2, $3);
        $$->isConst = entry->constType && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val << $3->int_val;
        }
    }
    | IDENTIFIER RIGHT_OP expression        {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // type check
        if (!isNum(entry->type) || !isNum($3->id)) {
            yyerror("Incompatible type for right operator.\n");
        }
        $$ = createASTNode(entry->type, 3, $1, $2, $3);
        $$->isConst = entry->constType && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val >> $3->int_val;
        }
    }
    | array LEFT_OP expression              {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // type check
        if (!isNum(entry->type) || !isNum($3->id)) {
            yyerror("Incompatible type for left operator.\n");
        }
        $$ = createASTNode(entry->type, 3, $1, $2, $3);
        $$->isConst = entry->constType && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val << $3->int_val;
        }
    }
    | array RIGHT_OP expression             {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // type check
        if (!isNum(entry->type) || !isNum($3->id)) {
            yyerror("Incompatible type for right operator.\n");
        }
        $$ = createASTNode(entry->type, 3, $1, $2, $3);
        $$->isConst = entry->constType && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val >> $3->int_val;
        }
    }
    | expression GT_OP expression           {
        // type check
        if (!isCompatible($1->id, $3->id)) {
            yyerror("Incompatible type for > operator.\n");
        }
        $$ = createASTNode("INT", 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val > $3->int_val;
        }
    }
    | expression LT_OP expression           {
        // type check
        if (!isCompatible($1->id, $3->id)) {
            yyerror("Incompatible type for < operator.\n");
        }
        $$ = createASTNode("INT", 3, $1, $2, $3);
        $$->isConst = $1->isConst && $2->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val < $3->int_val;
        }
    }
    | expression GE_OP expression           {
        // type check
        if (!isCompatible($1->id, $3->id)) {
            yyerror("Incompatible type for >= operator.\n");
        }
        $$ = createASTNode("INT", 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val >= $3->int_val;
        }
    }
    | expression LE_OP expression           {
        // type check
        if (!isCompatible($1->id, $3->id)) {
            yyerror("Incompatible type for <= operator.\n");
        }
        $$ = createASTNode("INT", 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val <= $3->int_val;
        }
    }
    | expression EQ_OP expression           {
        // type check
        if (!isCompatible($1->id, $3->id)) {
            yyerror("Incompatible type for == operator.\n");
        }
        $$ = createASTNode("INT", 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val == $3->int_val;
        }
    }
    | expression NE_OP expression           {
        // type check
        if (!isCompatible($1->id, $3->id)) {
            yyerror("Incompatible type for != operator.\n");
        }
        $$ = createASTNode("INT", 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val != $3->int_val;
        }
    }
    | expression BITAND_OP expression       {
        // type check
        if (!isCompatible($1->id, $3->id)) {
            yyerror("Incompatible type for & operator.\n");
        }
        $$ = createASTNode($1->id, 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            if (strcmp($1->id, "CHAR") == 0) {
                $$->char_val = $1->char_val & $3->char_val;
            } else {
                $$->int_val = $1->int_val & $3->int_val;
            }
        }
    }
    | expression BITXOR_OP expression       {
        // type check
        if (!isCompatible($1->id, $3->id)) {
            yyerror("Incompatible type for ^ operator.\n");
        }
        $$ = createASTNode($1->id, 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            if (strcmp($1->id, "CHAR") == 0) {
                $$->char_val = $1->char_val ^ $3->char_val;
            } else {
                $$->int_val = $1->int_val ^ $3->int_val;
            }
        }
    }
    | expression BITOR_OP expression        {
        // type check
        if (!isCompatible($1->id, $3->id)) {
            yyerror("Incompatible type for | operator.\n");
        }
        $$ = createASTNode($1->id, 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            if (strcmp($1->id, "CHAR") == 0) {
                $$->char_val = $1->char_val | $3->char_val;
            } else {
                $$->int_val = $1->int_val | $3->int_val;
            }
        }
    }
    | expression AND_OP expression          {
        // type check
        if (!isCompatible($1->id, $3->id)) {
            yyerror("Incompatible type for && operator.\n");
        }
        $$ = createASTNode("INT", 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val && $3->int_val;
        }
    }
    | expression OR_OP expression           {
        // type check
        if (!isCompatible($1->id, $3->id)) {
            yyerror("Incompatible type for || operator.\n");
        }
        $$ = createASTNode("INT", 3, $1, $2, $3);
        $$->isConst = $1->isConst && $3->isConst;
        // parse value if isConst
        if ($$->isConst == 1) {
            $$->int_val = $1->int_val || $3->int_val;
        }
    }
    | LPAREN expression RPAREN              {
        $$ = createASTNode($2->id, 3, $1, $2, $3);
        $$->isConst = $2->isConst;
        if ($$->isConst == 1) {
            if (strcmp($1->id, "CHAR") == 0) {
                $$->char_val = $1->char_val;
            } else {
                $$->int_val = $1->int_val;
            }
        }
    }
    | IDENTIFIER                            {
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // set expression type
        $$ = createASTNode(entry->type, 1, $1);
        // set expression value
        switch (entry->constType) {
            case NON_CONST:
                $$->isConst = 0;
                break;
            case CONST_CHAR:
                $$->char_val = entry->constValue.charVal;
                break;
            case CONST_INT:
                $$->int_val = entry->constValue.intVal;
                break;
            case CONST_STRING:
                $$->str_val = entry->constValue.strVal;
                break;
            default:
                break;
        }
    }
    | array                                 {
        // in fact, this is ONE ELEMENT of the array
        // check if the identifier is defined
        SymbolTableEntry* entry = findSymbol($1->id);
        if (entry == NULL) {
            yyerror("Undefined identifier %s.\n", $1->id);
        }
        // set expression type
        $$ = createASTNode(entry->type, 1, $1);
        // we currently do not do optimization for array elements even if it is const
        $$->isConst = 0;
    }
    | func_call                             {
        $$ = createASTNode($1->id, 1, $1);
        $$->isConst = 0;
    }
    | INT_CONSTANT                          {
        $$ = createASTNode("INT", 1, $1);
        $$->int_val = $1->int_val;
    }
    | CHAR_CONSTANT                         {
        $$ = createASTNode("CHAR", 1, $1);
        $$->char_val = $1->char_val;
    }
    | STRING_LITERAL                        {
        $$ = createASTNode("STRING", 1, $1);
        $$->str_val = $1->str_val;
    }
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
