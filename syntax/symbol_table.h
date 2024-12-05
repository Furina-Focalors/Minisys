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
    enum ConstType constType;
    union ConstValue constValue; // store the value of constants
    int isInitialized; // =1 if initialized
    int isArray; // =1 if is array
    // function info
    int isFunction; // =1 if is function
    int isDefined;
    unsigned int stackFrameSize;
    int paramNum;
    char** paramsType;
    char** parameters;
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

unsigned int hash(char* str);

SymbolTable* createSymbolTable(SymbolTable* parent);

SymbolTableEntry* createSymbolTableEntry(char* id, char* type, unsigned long long memloc,
                                          unsigned int size, int isInitialized, int isArray,
                                          int isFunction, int isDefined, unsigned int stackFrameSize,
                                          int paramNum, char** paramsType, char** parameters);

void insertSymbol(SymbolTable* symbolTable, SymbolTableEntry* entry);

// used to check redefinition
int isDeclared(SymbolTable* symbolTable, char* id);

// this will recursively find the identifier in itself and its parents
SymbolTableEntry* findSymbolRecur(SymbolTable* symbolTable, char* id);

void deleteSymbol(SymbolTable* symbolTable, char* id);

void destroySymbolTable(SymbolTable* symbolTable);

// we currently do not support 'const', so this is used to create an entry for constants but not const variables
SymbolTableEntry* createConstTableEntry(enum ConstType type, union ConstValue value);

void printSymbolTableEntry(SymbolTableEntry* entry);

void printSymbolTable(SymbolTable* symbolTable);

unsigned long long constPoolTop = 0; // address for constants, but it actually does nothing
unsigned long long symbolTableAddrTop = 0; // the first empty address for symbol table, actually does nothing
#endif