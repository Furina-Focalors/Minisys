#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include "symbol_table.h"

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
                                          unsigned int stackFrameSize, int paramNum, char** paramsType, char** parameters) {
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
    entry->paramsType = paramsType;
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
        printf("Memory Location: %" PRIu64 "\n", entry->memloc);
        printf("Size: %u\n", entry->size);
        printf("Is Initialized: %d\n", entry->isInitialized);
        printf("Is Array: %d\n", entry->isArray);
        printf("Is Function: %d\n", entry->isFunction);
        printf("Is Defined: %d\n", entry->isDefined);
        printf("Stack Frame Size: %u\n", entry->stackFrameSize);
        printf("Param Num: %d\n", entry->paramNum);
        if (entry->parameters && entry->paramsType) {
            printf("Parameters: ");
            for (int i = 0; i < entry->paramNum; ++i) {
                printf("%s %s, ", entry->paramsType[i], entry->parameters[i]);
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


int main() {
    SymbolTable* symbolTable = createSymbolTable(NULL);
    if (!symbolTable) {
        return 1;
    }

    char* paramsType1[] = {"int", "char"};
    char* params1[] = {"a", "b"};
    SymbolTableEntry* varEntry = createSymbolTableEntry("x", "int", 0x1000, 4, 1, 0, 0, 0, 0, 0, NULL, NULL);
    insertSymbol(symbolTable, varEntry);

    SymbolTableEntry* funcEntry = createSymbolTableEntry("foo", "void", 0x2000, 0, 1, 0, 1, 1, 32, 2, paramsType1, params1);
    insertSymbol(symbolTable, funcEntry);


    printf("Searching for 'x':\n");
    SymbolTableEntry* foundVar = findSymbol(symbolTable, "x");
    printSymbolTableEntry(foundVar);


    printf("\nSearching for 'foo':\n");
    SymbolTableEntry* foundFunc = findSymbol(symbolTable, "foo");
    printSymbolTableEntry(foundFunc);


    printf("creating local scopes...\n");
    SymbolTable* subScope1 = createSymbolTable(symbolTable);
    if (!subScope1) return 1;
    SymbolTableEntry* subVar1 = createSymbolTableEntry("y", "short", 0x3000, 2, 1, 0, 0, 0, 0, 0, NULL, NULL);
    insertSymbol(subScope1, subVar1);

    SymbolTable* subScope2 = createSymbolTable(symbolTable);
    if (!subScope2) return 1;
    SymbolTableEntry* subVar2 = createSymbolTableEntry("z", "char", 0x4000, 1, 1, 0, 0, 0, 0, 0, NULL, NULL);
    insertSymbol(subScope2, subVar2);


    printf("check scope:\n");
    printf("search for 'x' in subScope1:\n");
    SymbolTableEntry* test1 = findSymbol(subScope1, "x");
    printSymbolTableEntry(test1);

    printf("search for 'y' in subScope1:\n");
    SymbolTableEntry* test2 = findSymbol(subScope1, "y");
    printSymbolTableEntry(test2);

    printf("search for 'z' in subScope1:\n");
    SymbolTableEntry* test3 = findSymbol(subScope1, "z");
    printSymbolTableEntry(test3);

    printf("content of the tables:\n");
    printSymbolTable(symbolTable);
    printSymbolTable(subScope1);
    printSymbolTable(subScope2);


    // printf("\nDeleting 'x'...\n");
    // deleteSymbol(symbolTable, "x");

    // printf("\nSearching for 'x' after deletion:\n");
    // SymbolTableEntry* deletedVar = findSymbol(symbolTable, "x");
    // if (deletedVar) {
    //     printSymbolTableEntry(deletedVar);
    // } else {
    //     printf("Symbol 'x' not found.\n");
    // }


    // printf("\nDeleting 'foo'...\n");
    // deleteSymbol(symbolTable, "foo");

    // printf("\nSearching for 'foo' after deletion:\n");
    // SymbolTableEntry* deletedFunc = findSymbol(symbolTable, "foo");
    // if (deletedFunc) {
    //     printSymbolTableEntry(deletedFunc);
    // } else {
    //     printf("Symbol 'foo' not found.\n");
    // }


    // printf("\nDestroying symbol table...\n");
    // destroySymbolTable(symbolTable);

    return 0;
}