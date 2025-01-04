#include "symbol_table.h"

int scopeStackTop = 1;

unsigned int hash(char* str) {
    unsigned int hash = 0;
    while (*str) {
        hash = (hash << 5) + *str;
        str++;
    }
    return hash % SYMBOL_TABLE_SIZE;
}

SymbolTable* createSymbolTable() {
    SymbolTable* symbolTable = (SymbolTable*)malloc(sizeof(SymbolTable));
    if (!symbolTable) {
        fprintf(stderr, "Failed to allocate memory for symbol table.\n");
        return NULL;
    }
    for (int i = 0; i < SYMBOL_TABLE_SIZE; i++) {
        symbolTable->table[i] = NULL;
    }
    return symbolTable;
}

SymbolTableEntry* createSymbolTableEntry(char* id, char* type,
                                          unsigned int size, int isInitialized, int isArray,
                                          int isFunction, int isDefined, unsigned int stackFrameSize,
                                          int paramNum, char** paramsType, char** parameters) {
    SymbolTableEntry* entry = (SymbolTableEntry*)malloc(sizeof(SymbolTableEntry));
    if (!entry) {
        fprintf(stderr, "Failed to allocate memory for symbol table entry.\n");
        return NULL;
    }
    entry->id = strdup(id);
    entry->type = strdup(type);
    entry->size = size;
    entry->constType = NON_CONST;
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

int isDeclared(SymbolTable* symbolTable, char* id) {
    unsigned int index = hash(id);
    HashNode* node = symbolTable->table[index];
    while (node) {
        if (strcmp(node->entry->id, id) == 0) {
            return 1;
        }
        node = node->next;
    }
    return 0;
}

int insertSymbol(SymbolTable* symbolTable, SymbolTableEntry* entry) {
    if (isDeclared(symbolTable, entry->id) == 1) {
        perror("attempting to redefine symbol.\n");
        return -1;
    }
    unsigned int index = hash(entry->id);
    HashNode* newNode = (HashNode*)malloc(sizeof(HashNode));
    if (!newNode) {
        fprintf(stderr, "Failed to allocate memory for hash node.\n");
        return -1;
    }
    newNode->entry = entry;
    newNode->next = symbolTable->table[index]; // this is for conflict handling
    symbolTable->table[index] = newNode;
    return 0;
}

SymbolTableEntry* findSymbol(char* id) {
    unsigned int index = hash(id);
    for (int i = scopeStackTop - 1;i >= 0;--i) {
        HashNode* node = scopeStack[i]->table[index];
        while (node) {
            if (strcmp(node->entry->id, id) == 0) {
                return node->entry;
            }
            node = node->next;
        }
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

char* formatString(const char* format, ...) {
    va_list args;
    va_start(args, format);

    size_t size = 128;
    char* str = malloc(size);
    if (!str) {
        va_end(args);
        return NULL;
    }

    // formatted value assign to str
    int len = vsnprintf(str, size, format, args);
    if (len < 0) {
        free(str);
        va_end(args);
        return NULL;
    }

    // realloc to fit the size

    size = len + 1;
    str = realloc(str, size);
    if (!str) {
        va_end(args);
        return NULL;
    }
    vsnprintf(str, size, format, args);

    va_end(args);
    return str;
}

SymbolTableEntry* createConstTableEntry(enum ConstType type, union ConstValue value) {
    SymbolTableEntry* entry = (SymbolTableEntry*)malloc(sizeof(SymbolTableEntry));
    if (!entry) {
        fprintf(stderr, "Failed to allocate memory for symbol table entry.\n");
        return NULL;
    }

    char* id;
    switch (type) {
        case CONST_INT:
            id = formatString("%d", value.intVal);
            if (id == NULL) {
                perror("create constant symbol entry failed.\n");
                exit(1);
            }
            entry->id = id;
            entry->type = "INT";
            entry->size = 4;
            break;
        case CONST_CHAR:
            id = formatString("'%c'", value.charVal);
            if (id == NULL) {
                perror("create constant symbol entry failed.\n");
                exit(1);
            }
            entry->id = id;
            entry->type = "CHAR";
            entry->size = 1;
            break;
        case CONST_STRING:
            id = formatString("\"%s\"", value.strVal);
            if (id == NULL) {
                perror("create constant symbol entry failed.\n");
                exit(1);
            }
            entry->id = id;
            entry->type = "STRING_LITERAL";
            entry->size = sizeof(value.strVal);
            break;
        default:
            break;
    }
    entry->constType = type;
    entry->constValue = value;
    entry->isInitialized = 1;
    entry->isArray = 0;
    entry->isFunction = 0;
    entry->isDefined = 0;
    entry->stackFrameSize = 0;
    entry->paramNum = 0;
    entry->paramsType = NULL;
    entry->parameters = NULL;

    return entry;
}

void printSymbolTableEntry(SymbolTableEntry* entry) {
    if (entry) {
        printf("ID: %s\n", entry->id);
        printf("Type: %s\n", entry->type);
        printf("Size: %u\n", entry->size);
        switch(entry->constType) {
            case NON_CONST:
                printf("Non const\n");
                break;
            case CONST_INT:
                printf("const int, value=%d\n", entry->constValue.intVal);
                break;
            case CONST_CHAR:
                printf("const char, value=%c\n", entry->constValue.charVal);
                break;
            case CONST_STRING:
                printf("const string, value=%s\n", entry->constValue.strVal);
                break;
            default:
                break;
        }
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


// int main() {
//     SymbolTable* symbolTable = createSymbolTable(NULL);
//     if (!symbolTable) {
//         return 1;
//     }
//     scopeStack[scopeStackTop++] = symbolTable;

//     // union ConstValue val1,val2,val3;
//     // val1.intVal = 1013;
//     // val2.charVal = 'f';
//     // val3.strVal = "iloveyou";

//     // printf("creating entries...\n");
//     // SymbolTableEntry* test1 = createConstTableEntry(CONST_INT, val1);
//     // SymbolTableEntry* test2 = createConstTableEntry(CONST_CHAR, val2);
//     // SymbolTableEntry* test3 = createConstTableEntry(CONST_STRING, val3);
//     // printSymbolTableEntry(test1);
//     // printSymbolTableEntry(test2);
//     // printSymbolTableEntry(test3);

//     // printf("inserting entries...\n");
//     // insertSymbol(symbolTable, test1);
//     // insertSymbol(symbolTable, test2);
//     // insertSymbol(symbolTable, test3);
//     // // try to insert test3 again
//     // insertSymbol(symbolTable, test3);

//     // printf("table content:\n");
//     // printSymbolTable(symbolTable);

//     char* paramsType1[] = {"int", "char"};
//     char* params1[] = {"a", "b"};
//     SymbolTableEntry* varEntry = createSymbolTableEntry("x", "int", 4, 1, 0, 0, 0, 0, 0, NULL, NULL);
//     insertSymbol(symbolTable, varEntry);

//     SymbolTableEntry* funcEntry = createSymbolTableEntry("foo", "void", 0, 1, 0, 1, 1, 32, 2, paramsType1, params1);
//     insertSymbol(symbolTable, funcEntry);


//     printf("Searching for 'x':\n");
//     SymbolTableEntry* foundVar = findSymbol("x");
//     printSymbolTableEntry(foundVar);


//     printf("\nSearching for 'foo':\n");
//     SymbolTableEntry* foundFunc = findSymbol("foo");
//     printSymbolTableEntry(foundFunc);


//     printf("creating local scopes...\n");
//     SymbolTable* subScope1 = createSymbolTable(symbolTable);
//     if (!subScope1) return 1;
//     SymbolTableEntry* subVar1 = createSymbolTableEntry("y", "short", 2, 1, 0, 0, 0, 0, 0, NULL, NULL);
//     insertSymbol(subScope1, subVar1);

//     SymbolTable* subScope2 = createSymbolTable(symbolTable);
//     if (!subScope2) return 1;
//     SymbolTableEntry* subVar2 = createSymbolTableEntry("z", "char", 1, 1, 0, 0, 0, 0, 0, NULL, NULL);
//     insertSymbol(subScope2, subVar2);


//     printf("check scope:\n");
//     printf("search for 'x' in subScope1:\n");
//     SymbolTableEntry* test1 = findSymbol("x");
//     printSymbolTableEntry(test1);

//     printf("search for 'y' in subScope1:\n");
//     SymbolTableEntry* test2 = findSymbol("y");
//     printSymbolTableEntry(test2);

//     printf("search for 'z' in subScope1:\n");
//     SymbolTableEntry* test3 = findSymbol("z");
//     printSymbolTableEntry(test3);

//     printf("content of the tables:\n");
//     printSymbolTable(symbolTable);
//     printSymbolTable(subScope1);
//     printSymbolTable(subScope2);


//     printf("\nDeleting 'x'...\n");
//     deleteSymbol(symbolTable, "x");

//     printf("\nSearching for 'x' after deletion:\n");
//     SymbolTableEntry* deletedVar = findSymbol("x");
//     if (deletedVar) {
//         printSymbolTableEntry(deletedVar);
//     } else {
//         printf("Symbol 'x' not found.\n");
//     }


//     printf("\nDeleting 'foo'...\n");
//     deleteSymbol(symbolTable, "foo");

//     printf("\nSearching for 'foo' after deletion:\n");
//     SymbolTableEntry* deletedFunc = findSymbol("foo");
//     if (deletedFunc) {
//         printSymbolTableEntry(deletedFunc);
//     } else {
//         printf("Symbol 'foo' not found.\n");
//     }


//     printf("\nDestroying symbol table...\n");
//     destroySymbolTable(symbolTable);
//     printf("Complete.\n");

//     return 0;
// }
