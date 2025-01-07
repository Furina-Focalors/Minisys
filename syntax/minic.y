%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include "ast.h"
#include "symbol_table.h"
#include "semantic.h"
#include "tac.h"

int yylex(void);
void yyerror(const char *format, ...);

ASTNode* root = NULL;

// stores the params of function
#define PARAM_BUF_MAX 32
FuncParam* paramsBuf[PARAM_BUF_MAX];
int paramNum = 0;

// used to check function parameters
char* funcName = NULL;

// stores temp tac in functions
TAC* tempTAC = NULL;

// stores array element at initialization
#define ARRAY_BUF_MAX 1024
char* arrayBuf[ARRAY_BUF_MAX];
int arrElementNum = 0;

// stores the pointers to backpatching targets.
#define BACKPATCHING_BUF_MAX 64
TACList* bpBuf[BACKPATCHING_BUF_MAX];
int bpNum = 0;
int breakContinueCnt = 0;

// stores the num of break/continue statements in the current if-block.
#define IF_BREAK_CONTINUE_STACK_MAX 256
int ifBreakContinueNumStack[IF_BREAK_CONTINUE_STACK_MAX] = {0};
int curIfScope = -1;

// the increment part of for statement
TACList* forInc = NULL;

// whether the current statement is in a loop block(if, while, for)
int inLoop = 0;
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
%type <node> prefix enter_scope leave_scope var_assignment array_assignment array_element array_declaration add_label
%type <node> if_condition if_block_end while_condition condition_start for_condition for_inc_start for_inc_end

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

        // ALLOC/ALLOC_GLOBAL id(type, size);
        TAC* code = NULL;
        if (scopeStackTop == 1) {
            char* val = (char*)malloc(countDigits($1->int_val)*sizeof(char));
            itoa($1->int_val, val, 10);
            code = createTAC("alloc_global", $1->id, val, $2->id);
        } else {
            char* val = (char*)malloc(countDigits($1->int_val)*sizeof(char));
            itoa($1->int_val, val, 10);
            code = createTAC("alloc", $1->id, val, $2->id);
        }
        appendTAC(code);
        // add assignment stmt
        if ($3 != NULL) {
            // id = t1;
            TAC* code2 = createTAC("=", $3->symbol, NULL, $2->id);
            appendTAC(code2);
        }
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

        // ALLOC/ALLOC_GLOBAL id(type, size);
        TAC* code = NULL;
        if (scopeStackTop == 1) {
            char* val = (char*)malloc(countDigits($2->int_val)*sizeof(char));
            itoa($2->int_val, val, 10);
            code = createTAC("alloc_global", $2->id, val, $3->id);
        } else {
            char* val = (char*)malloc(countDigits($2->int_val)*sizeof(char));
            itoa($2->int_val, val, 10);
            code = createTAC("alloc", $2->id, val, $3->id);
        }
        appendTAC(code);
        // add assignment stmt
        if ($4 != NULL) {
            // id = t1;
            TAC* code2 = createTAC("=", $4->symbol, NULL, $3->id);
            appendTAC(code2);
        }
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

        // ALLOC/ALLOC_GLOBAL id(type, size);
        TAC* code = NULL;
        if (scopeStackTop == 1) {
            char* val = (char*)malloc(countDigits($1->int_val)*sizeof(char));
            itoa($1->int_val, val, 10);
            code = createTAC("alloc_global", $1->id, val, $2->id);
        } else {
            char* val = (char*)malloc(countDigits($1->int_val*$2->int_val)*sizeof(char));
            itoa($1->int_val*$2->int_val, val, 10);
            code = createTAC("alloc", $1->id, val, $2->id);
        }
        appendTAC(code);
        if ($3 != NULL) {
            for (int i=0;i<arrElementNum;++i) {
                // arr[i] = e;
                TAC* code2 = createTAC("=", arrayBuf[i], NULL, $2->id);
                appendTAC(code2);
            }
            // clear buffer
            arrElementNum = 0;
        }
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

        // ALLOC/ALLOC_GLOBAL id(type, size);
        TAC* code = NULL;
        if (scopeStackTop == 1) {
            char* val = (char*)malloc(countDigits($3->int_val*$2->int_val)*sizeof(char));
            itoa($3->int_val*$2->int_val, val, 10);
            code = createTAC("alloc_global", $2->id, val, $3->id);
        } else {
            char* val = (char*)malloc(countDigits($3->int_val*$2->int_val)*sizeof(char));
            itoa($3->int_val*$2->int_val, val, 10);
            code = createTAC("alloc", $2->id, val, $3->id);
        }
        appendTAC(code);
        if ($4 != NULL) {
            for (int i=0;i<arrElementNum;++i) {
                // arr[i] = e;
                TAC* code2 = createTAC("=", arrayBuf[i], NULL, $3->id);
                appendTAC(code2);
            }
            // clear buffer
            arrElementNum = 0;
        }
    }
    | func_head SEMICOLON                                           {
        funcName = NULL; // this means we are not in the scope of this function
        $$ = createASTNode("DECLARATION", 2, $1, $2);

        // delete temp label
        deleteTAC(tempTAC);
        tempTAC = NULL;
    }
    | func_head add_label LBRACE enter_scope statements leave_scope RBRACE    {
        $$ = createASTNode("DECLARATION", 4, $1, $2, $4, $6);
        // set isDefined
        SymbolTableEntry* entry = findSymbol($1->id);
        entry->isDefined = 1;
    }
    ;

add_label:
    {
        // add tac for creating label to code
        appendTAC(tempTAC);
        tempTAC = NULL;
    }
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
        // parse symbol
        $$->symbol = $2->symbol;
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
        // parse all characters into buffer
        char* ptr = $2->id;
        while (*ptr != '\0') {
            arrayBuf[arrElementNum++] = charToString(*ptr);
            ptr++;
        }
    }
    // | ASSIGN_OP IDENTIFIER                      {
    //     // check if the identifier is defined
    //     SymbolTableEntry* entry = findSymbol($2->id);
    //     if (entry == NULL) {
    //         yyerror("Undefined identifier %s.\n", $2->id);
    //     }
    //     // array type check
    //     if (entry->isArray == 0) {
    //         yyerror("Cannot assign non-array variable to an array variable.\n");
    //     }
    //     $$ = createASTNode(entry->type, 2, $1, $2);
    //     if (entry->constType == NON_CONST) {
    //         $$->isConst = 0;
    //     } else {
    //         $$->isConst = 1;
    //     }
    // }
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

        // redefinition check
        SymbolTableEntry* entry1 = findSymbol($2->id);
        if (entry1 != NULL && entry1->isDefined == 1) {
            yyerror("Redefinition of function %s.\n", $2->id);
        }
        // if the function is already declared but not defined, skip insertion
        if (entry1 == NULL) {
            SymbolTableEntry* entry = createSymbolTableEntry($2->id, $1->id, 0, 0, 0, 1, 0, 0, paramNum, params);
            int res = insertSymbol(scopeStack[scopeStackTop-1], entry);
        }

        // reset buffer
        paramNum = 0;
        // if in function definition, this will help check names of parameters
        funcName = $2->id;

        $$ = createASTNode($2->id, 5, $1, $2, $3, $4, $5);

        // cache the tac. if in function definition, add to tac, otherwise delete itself
        tempTAC = createTAC("label", $2->id, NULL, NULL);
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
        // t1 = arr[expr]
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("=[]", $1->id, $3->symbol, res);
        appendTAC(code);
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
        // add to buffer
        // if const, parse the value
        if ($3->isConst == 1) {
            if (strcmp($3->id, "CHAR") == 0) {
                arrayBuf[arrElementNum++] = charToString($3->char_val);
            } else {
                char* val = (char*)malloc(countDigits($3->int_val)*sizeof(char));
                itoa($3->int_val, val, 10);
                arrayBuf[arrElementNum++] = val;
            }
        } else {
            // otherwise parse the symbol
            arrayBuf[arrElementNum++] = $3->symbol;
        }
    }
    | expression                        {
        // check if expression type is valid
        if (!isNum($1->id) && !isChar($1->id)) {
            yyerror("Unsupported type for array element.\n");
        }
        $$ = createASTNode($1->id, 1, $1);

        // add to buffer
        // if const, parse the value
        if ($1->isConst == 1) {
            if (strcmp($1->id, "CHAR") == 0) {
                arrayBuf[arrElementNum++] = charToString($1->char_val);
            } else {
                char* val = (char*)malloc(countDigits($1->int_val)*sizeof(char));
                itoa($1->int_val, val, 10);
                arrayBuf[arrElementNum++] = val;
            }
        } else {
            // otherwise parse the symbol
            arrayBuf[arrElementNum++] = $1->symbol;
        }
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
        // reset buffer
        paramNum = 0;
        // parse symbol
        $$->symbol = $1->symbol;
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
        // param id;
        TAC* code = createTAC("param", $3->id, NULL, NULL);
        appendTAC(code);
    }
    | expression                    {
        paramsBuf[paramNum++] = createFuncParam($1->id, NULL, 0, 0);
        $$ = createASTNode("ARG_LIST", 1, $1);
        // we currently consider all arguments non-const
        $$->isConst = 0;
        // param id;
        TAC* code = createTAC("param", $1->id, NULL, NULL);
        appendTAC(code);
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
        // id = expr(temp symbol);
        TAC* code = createTAC("=", $3->symbol, NULL, $1->id);
        appendTAC(code);
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
        // arr(temp symbol) = expr(temp symbol);
        TAC* code = createTAC("=", $3->symbol, NULL, $1->symbol);
        appendTAC(code);
    }
    | ADDR_OP expression ASSIGN_OP expression SEMICOLON     {
        // type check
        if (!isNum($2->id)) {
            yyerror("Address can only be integers.\n");
        }

        $$ = createASTNode("EXPR_STMT", 5, $1, $2, $3, $4, $5);
        // $expr1(temp symbol) = expr2(temp symbol)
        TAC* code = createTAC("$=", $2->symbol, NULL, $4->symbol);
        appendTAC(code);
    }
    | expression SEMICOLON                                  {
        $$ = createASTNode($1->id, 2, $1, $2);
        $$->isConst = $1->isConst;
        if ($$->isConst == 1) {
            if (strcmp($1->id, "CHAR") == 0) {
                $$->char_val = $1->char_val;
            } else {
                $$->int_val = $1->int_val;
            }
        }
        $$->symbol = $1->symbol;
    }
    | SEMICOLON                                             { $$ = createASTNode("EXPR_STMT", 1, $1); }
    ;

if_stmt:
    IF if_condition statement if_block_end %prec NO_ELSE   {
        $$ = createASTNode("IF_STMT", 3, $1, $2, $3);
      }
    | IF if_condition statement if_block_end ELSE statement  {
        $$ = createASTNode("IF_STMT", 5, $1, $2, $3, $5, $6);
    }
    ;

if_condition:
    LPAREN expression RPAREN    {
        $$ = createASTNode("IF_CONDITION", 3, $1, $2, $3);
        // generate the if statements
        char* label = generateLabel();
        TAC* code1 = createTAC("ifGoto", $2->symbol, NULL, label);
        TAC* code2 = createTAC("goto", NULL, NULL, NULL);
        TAC* code3 = createTAC("label", label, NULL, NULL);
        appendTAC(code1);
        appendTAC(code2);
        // store the pointers to buffer for backpatching
        bpBuf[bpNum++] = tacTail;
        appendTAC(code3);
        // enter scope
        ++curIfScope;
    }
    ;

if_block_end:
    {
        $$ = NULL;
        // backpatching
        char* label = generateLabel();
        TAC* code = createTAC("label", label, NULL, NULL);
        // current top: the goto stmt when condition is false
        // skip the break/continue stmts
        bpBuf[bpNum-1-ifBreakContinueNumStack[curIfScope]]->tac->res = label;
        appendTAC(code);
        // for(int i=0;i<bpNum;++i) {
        //     printf("%s, %s, %s, %s\n", bpBuf[i]->tac->op, bpBuf[i]->tac->arg1, bpBuf[i]->tac->arg2, bpBuf[i]->tac->res);
        // }
        // printf("------------------------------------------\n");
        // shift left to remove the goto stmt
        for (int i=bpNum-1-ifBreakContinueNumStack[curIfScope];i<bpNum;++i) {
            bpBuf[i] = bpBuf[i+1];
        }
        --bpNum;
        // if have nested if-block, add the cnt to the outer scope, otherwise add it to the global cnt
        if (curIfScope > 0) {
            ifBreakContinueNumStack[curIfScope-1] += ifBreakContinueNumStack[curIfScope];
        } else {
            breakContinueCnt += ifBreakContinueNumStack[curIfScope];
        }
        // leave scope
        ifBreakContinueNumStack[curIfScope] = 0;
        --curIfScope;

        // for(int i=0;i<bpNum;++i) {
        //     printf("%s, %s, %s, %s\n", bpBuf[i]->tac->op, bpBuf[i]->tac->arg1, bpBuf[i]->tac->arg2, bpBuf[i]->tac->res);
        // }
        // printf("==========================================\n");
    }
    ;

while_stmt:
    WHILE while_condition statement  {
        $$ = createASTNode("WHILE_STMT", 3, $1, $2, $3);
        // backpatching
        char* label = generateLabel();
        // this label is AFTER the loop statement(goto condition)
        TAC* code2 = createTAC("label", label, NULL, NULL);

        // condition
        char* conditionLabel = bpBuf[bpNum-2-breakContinueCnt]->tac->arg1;
        // backpatch the break and continue statements
        for (int i=0;i<breakContinueCnt;++i) {
            TACList* code = bpBuf[--bpNum];
            if (strcmp(code->tac->arg1, "break") == 0) {
                code->tac->arg1 = NULL;
                code->tac->res = label;
            } else if (strcmp(code->tac->arg1, "continue") == 0) {
                code->tac->arg1 = NULL;
                code->tac->res = conditionLabel;
            }
        }

        // current top: the goto stmt when condition is false
        bpBuf[--bpNum]->tac->res = label;
        // current top: the label of the condition
        TAC* code1 = createTAC("goto", NULL, NULL, bpBuf[--bpNum]->tac->arg1);

        appendTAC(code1);
        appendTAC(code2);
        --inLoop;
        breakContinueCnt = 0;
    }
    ;

while_condition:
    LPAREN condition_start expression RPAREN {
        $$ = createASTNode("WHILE_CONDITION", 3, $1, $3, $4);
        // generate while statement
        char* label = generateLabel();
        TAC* code1 = createTAC("ifGoto", $3->symbol, NULL, label);
        TAC* code2 = createTAC("goto", NULL, NULL, NULL);
        TAC* code3 = createTAC("label", label, NULL, NULL);
        appendTAC(code1);
        appendTAC(code2);
        bpBuf[bpNum++] = tacTail;
        appendTAC(code3);
        ++inLoop;
    }
    ;

condition_start:
    {
        $$ = NULL;
        // record the start of condition expression.
        // in while/for statements, there will be a goto statement that returns to this label
        // after finishing the whole block.
        char* label = generateLabel();
        TAC* code = createTAC("label", label, NULL, NULL);
        appendTAC(code);
        bpBuf[bpNum++] = tacTail;
    }
    ;

return_stmt:
      RETURN expression SEMICOLON       {
        $$ = createASTNode("RETURN_STMT", 3, $1, $2, $3);
        // return expr(temp symbol);
        TAC *code = createTAC("return", NULL, NULL, $2->symbol);
        appendTAC(code);
    }
    | RETURN SEMICOLON                  {
        $$ = createASTNode("RETURN_STMT", 2, $1, $2);
        TAC *code = createTAC("return", NULL, NULL, NULL);
        appendTAC(code);
    }
    ;

break_stmt:
      BREAK SEMICOLON                   {
        // scope check
        if (inLoop == 0) {
            yyerror("break statements should be used inside while or for block.\n");
        }
        $$ = createASTNode("BREAK_STMT", 2, $1, $2);
        // goto 0; arg1 is used to distinguish the statement from continue
        TAC* code = createTAC("goto", "break", NULL, NULL);
        appendTAC(code);
        bpBuf[bpNum++] = tacTail;
        // in if blocks, add the count to buffer. otherwise, add to global cnt
        if (curIfScope >= 0) {
            ++ifBreakContinueNumStack[curIfScope];
        } else {
            ++breakContinueCnt;
        }
    }
    ;

continue_stmt:
      CONTINUE SEMICOLON                {
        // scope check
        if (inLoop == 0) {
            yyerror("continue statements should be used inside while or for block.\n");
        }
        $$ = createASTNode("CONTINUE_STMT", 2, $1, $2);
        // goto 0;
        TAC* code = createTAC("goto", "continue", NULL, NULL);
        appendTAC(code);
        bpBuf[bpNum++] = tacTail;
        // in if blocks, add the count to buffer. otherwise, add to global cnt
        if (curIfScope >= 0) {
            ++ifBreakContinueNumStack[curIfScope];
        } else {
            ++breakContinueCnt;
        }
    }
    ;

for_stmt:
      FOR for_condition statement {
        $$ = createASTNode("FOR_STMT", 3, $1, $2, $3);
        // insert inc part
        tacTail->next = forInc;
        while (tacTail != NULL && tacTail->next != NULL) {
            tacTail = tacTail->next;
        }
        // backpatching
        char* label = generateLabel();
        // this label is AFTER the loop statement(goto condition)
        TAC* code2 = createTAC("label", label, NULL, NULL);

        // condition
        char* conditionLabel = bpBuf[bpNum-2-breakContinueCnt]->tac->arg1;
        // backpatch the break and continue statements
        for (int i=0;i<breakContinueCnt;++i) {
            TACList* code = bpBuf[--bpNum];
            if (strcmp(code->tac->arg1, "break") == 0) {
                code->tac->arg1 = NULL;
                code->tac->res = label;
            } else if (strcmp(code->tac->arg1, "continue") == 0) {
                code->tac->arg1 = NULL;
                code->tac->res = conditionLabel;
            }
        }
        // current top: the goto stmt when condition is false
        bpBuf[--bpNum]->tac->res = label;
        // current top: the label of the condition
        TAC* code1 = createTAC("goto", NULL, NULL, bpBuf[--bpNum]->tac->arg1);

        appendTAC(code1);
        appendTAC(code2);
        --inLoop;
        breakContinueCnt = 0;
      }
    ;

for_condition:
    LPAREN expression_stmt condition_start expression_stmt for_inc_start expression for_inc_end RPAREN    {
        $$ = createASTNode("FOR_STMT", 5, $1, $2, $4, $6, $8);
        // generate for statement
        char* label = generateLabel();
        TAC* code1 = createTAC("ifGoto", $4->symbol, NULL, label);
        TAC* code2 = createTAC("goto", NULL, NULL, NULL);
        TAC* code3 = createTAC("label", label, NULL, NULL);
        appendTAC(code1);
        appendTAC(code2);
        bpBuf[bpNum++] = tacTail;
        appendTAC(code3);
        ++inLoop;
    }
    ;

for_inc_start:
    {
        $$ = NULL;
        // record the start of increment. this part should not exist before the for block,
        // so we will delete it from code at for_inc_end, and put it at the end of for block.
        // note that forInc is now the statement BEFORE increment
        forInc = tacTail;
    }
    ;

for_inc_end:
    {
        $$ = NULL;
        // cut off and cache the increment statements. They will be inserted at the end of for block
        TACList* temp = forInc;
        forInc = forInc->next;
        temp->next = NULL;
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
        // directly parse x, do not generate code
        $$->symbol = $2->symbol;
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
        // res = 0 - x;
        char* res = generateTemp();
        TAC* code = createTAC("-", 0, $2->symbol, res);
        appendTAC(code);
        $$->symbol = res;
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
        // x = x + 1;
        // t1 = x;
        char* res = generateTemp();
        TAC* code1 = createTAC("+", $2->id, "1", $2->id);
        TAC* code2 = createTAC("=", $2->id, NULL, res);
        appendTAC(code1);
        appendTAC(code2);
        $$->symbol = res;
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
        // t1 = x;
        // x = x + 1;
        char* res = generateTemp();
        TAC* code1 = createTAC("=", $1->id, NULL, res);
        TAC* code2 = createTAC("+", $1->id, "1", $1->id);
        appendTAC(code1);
        appendTAC(code2);
        $$->symbol = res;
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
        // x = x - 1;
        // t1 = x;
        char* res = generateTemp();
        TAC* code1 = createTAC("-", $2->id, "1", $2->id);
        TAC* code2 = createTAC("=", $2->id, NULL, res);
        appendTAC(code1);
        appendTAC(code2);
        $$->symbol = res;
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
        // t1 = x;
        // x = x - 1;
        char* res = generateTemp();
        TAC* code1 = createTAC("=", $1->id, NULL, res);
        TAC* code2 = createTAC("-", $1->id, "1", $1->id);
        appendTAC(code1);
        appendTAC(code2);
        $$->symbol = res;
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
        // x = x + 1;
        // t1 = x;
        char* res = generateTemp();
        TAC* code1 = createTAC("+", $2->id, "1", $2->id);
        TAC* code2 = createTAC("=", $2->id, NULL, res);
        appendTAC(code1);
        appendTAC(code2);
        $$->symbol = res;
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
        // t1 = x;
        // x = x + 1;
        char* res = generateTemp();
        TAC* code1 = createTAC("=", $1->id, NULL, res);
        TAC* code2 = createTAC("+", $1->id, "1", $1->id);
        appendTAC(code1);
        appendTAC(code2);
        $$->symbol = res;
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
        // x = x - 1;
        // t1 = x;
        char* res = generateTemp();
        TAC* code1 = createTAC("-", $2->id, "1", $2->id);
        TAC* code2 = createTAC("=", $2->id, NULL, res);
        appendTAC(code1);
        appendTAC(code2);
        $$->symbol = res;
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
        // t1 = x;
        // x = x - 1;
        char* res = generateTemp();
        TAC* code1 = createTAC("=", $1->id, NULL, res);
        TAC* code2 = createTAC("-", $1->id, "1", $1->id);
        appendTAC(code1);
        appendTAC(code2);
        $$->symbol = res;
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
        // t1 = !x;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("!", $2->symbol, NULL, res);
        appendTAC(code);
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
        // t1 = ~x;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("~", $2->symbol, NULL, res);
        appendTAC(code);
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
        // t1 = $x;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("=$", $2->symbol, NULL, res);
        appendTAC(code);
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
        // t1 = x1 * x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("*", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 / x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("/", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 % x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("%", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 + x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("+", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 - x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("-", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 << x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("<<", $1->id, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 >> x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC(">>", $1->id, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 << x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("<<", $1->id, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 >> x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC(">>", $1->id, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 > x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC(">", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 < x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("<", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 >= x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC(">=", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 <= x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("<=", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 == x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("==", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 != x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("!=", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 & x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("&", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 ^ x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("^", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 | x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("|", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 && x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("&&", $1->symbol, $3->symbol, res);
        appendTAC(code);
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
        // t1 = x1 || x2;
        char* res = generateTemp();
        $$->symbol = res;
        TAC* code = createTAC("||", $1->symbol, $3->symbol, res);
        appendTAC(code);
    }
    | LPAREN expression RPAREN              {
        $$ = createASTNode($2->id, 3, $1, $2, $3);
        $$->isConst = $2->isConst;
        if ($$->isConst == 1) {
            if (strcmp($2->id, "CHAR") == 0) {
                $$->char_val = $2->char_val;
            } else {
                $$->int_val = $2->int_val;
            }
        }
        $$->symbol = $2->symbol;
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
        $$->symbol = $1->id;
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

        $$->symbol = $1->symbol;
    }
    | func_call                             {
        $$ = createASTNode($1->id, 1, $1);
        $$->isConst = 0;

        if ($1->id == "VOID") {
            // call func;
            TAC* code = createTAC("call", $1->symbol, NULL, NULL);
            appendTAC(code);
        } else {
            // t1 = call func;
            char* res = generateTemp();
            $$->symbol = res;
            TAC* code = createTAC("call", $1->symbol, NULL, res);
            appendTAC(code);
        }
    }
    | INT_CONSTANT                          {
        $$ = createASTNode("INT", 1, $1);
        $$->int_val = $1->int_val;
        // parse value as symbol name
        $$->symbol = (char*)malloc(countDigits($$->int_val)*sizeof(char));
        itoa($$->int_val, $$->symbol, 10);
    }
    | CHAR_CONSTANT                         {
        $$ = createASTNode("CHAR", 1, $1);
        $$->char_val = $1->char_val;
        $$->symbol = charToString($1->char_val);
    }
    | STRING_LITERAL                        {
        $$ = createASTNode("STRING", 1, $1);
        $$->str_val = $1->str_val;
        $$->symbol = $$->str_val;
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
