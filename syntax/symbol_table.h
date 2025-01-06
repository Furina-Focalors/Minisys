#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

enum ConstType {
        NON_CONST,
        CONST_INT,
        CONST_CHAR,
        CONST_STRING,
    };

union ConstValue {
    int intVal;
    char charVal;
    char* strVal;
};

// struct for parsing parameters to functions
typedef struct FuncParam {
    char* id;
    char* type;
    unsigned int size;
    int isArray;
} FuncParam;

typedef struct SymbolTableEntry {
    char* id;
    /* type supports INT, CHAR, SHORT and VOID.
     * for array variables, this is the type of its elements;
     * for functions, this is the type for its return value.
     */
    char* type;
    /*
     * for single and array variables, this is the bytes it takes up;
     * for functions, this is invalid
     */
    unsigned int size;
    enum ConstType constType;
    union ConstValue constValue; // store the value of constants
    int isInitialized; // =1 if initialized
    int isArray; // =1 if is array
    // function info
    int isFunction; // =1 if is function
    int isDefined;
    unsigned int stackFrameSize;
    int paramNum;
    FuncParam** params;
} SymbolTableEntry;

typedef struct HashNode {
    SymbolTableEntry* entry;
    struct HashNode* next;
} HashNode;

#define SYMBOL_TABLE_SIZE 64
typedef struct SymbolTable {
    HashNode* table[SYMBOL_TABLE_SIZE];
} SymbolTable;

unsigned int hash(char* str);

SymbolTable* createSymbolTable();

// note that constValue is not initialized in this function, and constType is set to NON_CONST in default
SymbolTableEntry* createSymbolTableEntry(char* id, char* type,
                                          unsigned int size, int isInitialized, int isArray,
                                          int isFunction, int isDefined, unsigned int stackFrameSize,
                                          int paramNum, FuncParam** params);

int insertSymbol(SymbolTable* symbolTable, SymbolTableEntry* entry);

// deprecated
int isDeclared(SymbolTable* symbolTable, char* id);

// this will find the identifier in itself and the symbol tables of the outer scopes
SymbolTableEntry* findSymbol(char* id);

void deleteSymbol(SymbolTable* symbolTable, char* id);

void destroySymbolTable(SymbolTable* symbolTable);

// deprecated
SymbolTableEntry* createConstTableEntry(enum ConstType type, union ConstValue value);

void printSymbolTableEntry(SymbolTableEntry* entry);

void printSymbolTable(SymbolTable* symbolTable);

void printScopeStack();

FuncParam* createFuncParam(char* type, char* id, unsigned int size, int isArray);

// the stack of symbol tables. when a new scope is entered, its symbol table will be pushed
// into this stack, and when leaving the scope, the table will be popped. the program will
// search the symbol tables from top to bottom to check whether a variable is declared.
// scopeStack[0] is the global symbol table and will be created before yyparse().
#define SYMBOL_TABLE_STACK_SIZE 256
SymbolTable *scopeStack[SYMBOL_TABLE_STACK_SIZE];
extern int scopeStackTop;
extern char* funcName;
#endif