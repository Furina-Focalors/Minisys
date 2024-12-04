#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

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
                                          unsigned int size, int isInitialized,
                                          int isArray, int isFunction, int isDefined,
                                          unsigned int stackFrameSize, int paramNum, char** paramsType, char** parameters);

void insertSymbol(SymbolTable* symbolTable, SymbolTableEntry* entry);

SymbolTableEntry* findSymbol(SymbolTable* symbolTable, char* id);

void deleteSymbol(SymbolTable* symbolTable, char* id);

void destroySymbolTable(SymbolTable* symbolTable);

void printSymbolTableEntry(SymbolTableEntry* entry);

void printSymbolTable(SymbolTable* symbolTable);

#endif