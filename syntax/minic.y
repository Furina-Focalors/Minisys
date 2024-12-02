%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct SymbolTableEntry {
    char* id;
    /* type supports int, char, short and void.
     * for array variables, this is the type of its elements;
     * for functions, this is the type for its return value.
     */
    char* type;
    unsigned long long memloc;
    /*
     * for single and array variables, this is the bytes it takes up;
     * for functions, this is invalid
     */
    unsigned int size;
    int isInitialized; // =1 if initialized
    int isArray; // =1 if is array
    // function info
    int isFunction; // =1 if is function
    int isDefined;
    unsigned int stackFrameSize;
    int paramNum;
    char** parameters; // type of each of its parameters
} SymbolTableEntry;

typedef struct HashNode {
    SymbolTableEntry* entry;
    struct HashNode* next;
} HashNode;

#define SYMBOL_TABLE_SIZE 64
typedef struct SymbolTable {
    HashNode* table[SYMBOL_TABLE_SIZE];
    // parent points to the outer scope for this table
    struct SymbolTable* parent;
} SymbolTable;

unsigned int hash(char* str) {
    unsigned int hash = 0;
    while (*str) {
        hash = (hash << 5) + *str;
        str++;
    }
    return hash % SYMBOL_TABLE_SIZE;
}

SymbolTable* createSymbolTable(SymbolTable* parent) {
    SymbolTable* symbolTable = (SymbolTable*)malloc(sizeof(SymbolTable));
    if (!symbolTable) {
        fprintf(stderr, "Failed to allocate memory for symbol table.\n");
        return NULL;
    }
    for (int i = 0; i < SYMBOL_TABLE_SIZE; i++) {
        symbolTable->table[i] = NULL;
    }
    symbolTable->parent = parent;
    return symbolTable;
}

SymbolTableEntry* createSymbolTableEntry(char* id, char* type, unsigned long long memloc,
                                          unsigned int size, int isInitialized,
                                          int isArray, int isFunction, int isDefined,
                                          unsigned int stackFrameSize, int paramNum, char** parameters) {
    SymbolTableEntry* entry = (SymbolTableEntry*)malloc(sizeof(SymbolTableEntry));
    if (!entry) {
        fprintf(stderr, "Failed to allocate memory for symbol table entry.\n");
        return NULL;
    }
    entry->id = strdup(id);
    entry->type = strdup(type);
    entry->memloc = memloc;
    entry->size = size;
    entry->isInitialized = isInitialized;
    entry->isArray = isArray;
    entry->isFunction = isFunction;
    entry->isDefined = isDefined;
    entry->stackFrameSize = stackFrameSize;
    entry->paramNum = paramNum;
    entry->parameters = parameters;
    return entry;
}

void insertSymbol(SymbolTable* symbolTable, SymbolTableEntry* entry) {
    unsigned int index = hash(entry->id);
    HashNode* newNode = (HashNode*)malloc(sizeof(HashNode));
    if (!newNode) {
        fprintf(stderr, "Failed to allocate memory for hash node.\n");
        return;
    }
    newNode->entry = entry;
    newNode->next = symbolTable->table[index]; // this is for conflict handling
    symbolTable->table[index] = newNode;
}

SymbolTableEntry* findSymbol(SymbolTable* symbolTable, char* id) {
    unsigned int index = hash(id);
    HashNode* node = symbolTable->table[index];
    while (node) {
        if (strcmp(node->entry->id, id) == 0) {
            return node->entry;
        }
        node = node->next;
    }
    // recursively find symbol in outer scopes
    if (symbolTable->parent != NULL) {
        return findSymbol(symbolTable->parent, id);
    }

    return NULL;
}

void deleteSymbol(SymbolTable* symbolTable, char* id) {
    unsigned int index = hash(id);
    HashNode* node = symbolTable->table[index];
    HashNode* prev = NULL;
    while (node) {
        if (strcmp(node->entry->id, id) == 0) {
            if (prev) {
                prev->next = node->next;
            } else {
                symbolTable->table[index] = node->next;
            }
            free(node->entry->id);
            free(node->entry->type);
            free(node->entry);
            free(node);
            return;
        }
        prev = node;
        node = node->next;
    }
}

void destroySymbolTable(SymbolTable* symbolTable) {
    for (int i = 0; i < SYMBOL_TABLE_SIZE; i++) {
        HashNode* node = symbolTable->table[i];
        while (node) {
            HashNode* temp = node;
            node = node->next;
            free(temp->entry->id);
            free(temp->entry->type);
            free(temp->entry);
            free(temp);
        }
    }
    free(symbolTable);
}



void printSymbolTableEntry(SymbolTableEntry* entry) {
    if (entry) {
        printf("ID: %s\n", entry->id);
        printf("Type: %s\n", entry->type);
        printf("Memory Location: %llu\n", entry->memloc);
        printf("Size: %u\n", entry->size);
        printf("Is Initialized: %d\n", entry->isInitialized);
        printf("Is Array: %d\n", entry->isArray);
        printf("Is Function: %d\n", entry->isFunction);
        printf("Is Defined: %d\n", entry->isDefined);
        printf("Stack Frame Size: %u\n", entry->stackFrameSize);
        printf("Param Num: %d\n", entry->paramNum);
        if (entry->parameters) {
            printf("Parameters: ");
            for (int i = 0; i < entry->paramNum; ++i) {
                printf("%s ", entry->parameters[i]);
            }
            printf("\n");
        }
    } else {
        printf("entry is NULL.\n");
    }
}

void printSymbolTable(SymbolTable* symbolTable) {
    printf("Table content:\n");
    printf("======================================\n");
    if (symbolTable->parent == NULL) {
        printf("parent is NULL,\n");
    } else {
        printf("parent at %p.\n", (void*)(symbolTable->parent));
    }
    printf("------------------------------------------\n");
    for (int i=0;i<SYMBOL_TABLE_SIZE;++i) {
        if (symbolTable->table[i] == NULL) continue;
        HashNode* temp = symbolTable->table[i];
        while (temp != NULL) {
            printSymbolTableEntry(temp->entry);
            printf("------------------------------------------\n");
            temp = temp->next;
        }
    }
    printf("======================================\n");
}


SymbolTable* currentScope;

int yylex(void);
void yyerror(char *);

// Declare tokens from Lex
%}

%union {
    int int_val;
    char* str_val;
    struct {
        char* id;
        char* type;
        unsigned int offset;
    } arr_val;
    struct {
        char* type;
        unsigned int size;
    } type_spec_val;
}

%token <int_val> CONSTANT
%token <str_val> IDENTIFIER STRING_LITERAL
%token _COMMENT BREAK CONTINUE ELSE FOR IF RETURN WHILE CHAR INT SHORT VOID
%token ADD_OP SUB_OP MUL_OP DIV_OP MOD_OP INC_OP DEC_OP
%token LE_OP GE_OP EQ_OP NE_OP LT_OP GT_OP
%token AND_OP OR_OP NOT_OP ADDR_OP RIGHT_OP LEFT_OP
%token SEMICOLON LBRACE RBRACE COMMA COLON ASSIGN_OP
%token LPAREN RPAREN LBRACKET RBRACKET DOT BITAND_OP BITINV_OP BITXOR_OP BITOR_OP
%token _UNMATCH

%type <type_spec_val> type_specifier
%type <arr_val> array

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
      type_specifier IDENTIFIER SEMICOLON           {
                                                        if (findSymbol(currentScope, $2) != NULL) {
                                                            yyerror("redefinition of identifier.");
                                                            YYERROR;
                                                        }
                                                        SymbolTableEntry* temp = createSymbolTableEntry($2,$1.type,1013,$1.size,0,0,0,0,0,0,NULL);
                                                        insertSymbol(currentScope,temp); printSymbolTable(currentScope);
                                                    }
    | type_specifier array SEMICOLON                {
                                                        if (findSymbol(currentScope, $2.id) != NULL) {
                                                            yyerror("redefinition of identifier.");
                                                            YYERROR;
                                                        }
                                                        SymbolTableEntry* temp = createSymbolTableEntry($2.id,$1.type,1014,$1.size*$2.offset,0,1,0,0,0,0,NULL);
                                                        insertSymbol(currentScope,temp); printSymbolTable(currentScope);
                                                    }
    | type_specifier IDENTIFIER LPAREN param_list RPAREN SEMICOLON
    | type_specifier IDENTIFIER LPAREN param_list RPAREN LBRACE statements RBRACE
    | type_specifier IDENTIFIER LPAREN VOID RPAREN SEMICOLON
    | type_specifier IDENTIFIER LPAREN VOID RPAREN LBRACE statements RBRACE
    ;

type_specifier:
      CHAR      { $$.type = strdup("char"); $$.size = 1; }
    | INT       { $$.type = strdup("int"); $$.size = 4; }
    | SHORT     { $$.type = strdup("short"); $$.size = 2; }
    | VOID      { $$.type = strdup("void"); $$.size = 0; }
    ;

param_list:
    | param_list COMMA type_specifier IDENTIFIER
    | type_specifier IDENTIFIER
    ;

array:
      IDENTIFIER LBRACKET CONSTANT RBRACKET       { strcpy($$.id, $1); $$.offset = $3; }
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
    currentScope = createSymbolTable(NULL); // global symbols
    yyparse();
}
