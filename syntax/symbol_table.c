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
                                          int paramNum, FuncParam** params) {
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
    entry->params = params;
    entry->constType = NON_CONST;
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
        //perror("attempting to redefine symbol.\n");
        return -1;
    }
    unsigned int index = hash(entry->id);
    HashNode* newNode = (HashNode*)malloc(sizeof(HashNode));
    if (!newNode) {
        fprintf(stderr, "Failed to allocate memory for hash node.\n");
        exit(1);
    }
    newNode->entry = entry;
    newNode->next = symbolTable->table[index]; // this is for conflict handling
    symbolTable->table[index] = newNode;
    return 0;
}

SymbolTableEntry* findSymbol(char* id) {
    unsigned int index = hash(id);
    unsigned int funcIndex = 0;
    if (funcName != NULL) {
        funcIndex = hash(funcName);
    }
    for (int i = scopeStackTop - 1;i >= 0;--i) {
        // find var in the table
        HashNode* node = scopeStack[i]->table[index];
        while (node) {
            if (strcmp(node->entry->id, id) == 0) {
                return node->entry;
            }
            node = node->next;
        }

        if (funcName != NULL) {
            // find var in func params
            HashNode* funcNode = scopeStack[i]->table[funcIndex];
            while (funcNode) {
                if (strcmp(funcNode->entry->id, funcName) == 0) {
                    for (int i=0;i<funcNode->entry->paramNum;++i) {
                        if (strcmp(funcNode->entry->params[i]->id, id) == 0) {
                            return createSymbolTableEntry(
                                funcNode->entry->params[i]->id, funcNode->entry->params[i]->type, 
                                funcNode->entry->params[i]->size, 0, 
                                funcNode->entry->params[i]->isArray, 0, 0, 0, 0, NULL
                                );
                        }
                    }
                }
                funcNode = funcNode->next;
            }
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
    entry->params = NULL;

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
        if (entry->params) {
            printf("Parameters: ");
            for (int i = 0; i < entry->paramNum; ++i) {
                if (entry->params[i]->isArray) {
                    printf("%s[] %s, ", entry->params[i]->type, entry->params[i]->id);
                } else {
                    printf("%s %s, ", entry->params[i]->type, entry->params[i]->id);
                }
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

void printScopeStack() {
    for (int i=scopeStackTop-1;i>=0;--i) {
        printSymbolTable(scopeStack[i]);
    }
}

FuncParam* createFuncParam(char* type, char* id, unsigned int size, int isArray) {
    FuncParam* param = (FuncParam*)malloc(sizeof(FuncParam));
    param->id = strdup(id);
    param->type = strdup(type);
    param->size = size;
    param->isArray = isArray;
    return param;
}

// ArrayElement* createIdElement(char* id) {
//     ArrayElement* element = (ArrayElement*)malloc(sizeof(ArrayElement));
//     element->elementType = ID;
//     element->id = id;
//     return element;
// }

// ArrayElement* createCharElement(char c) {
//     ArrayElement* element = (ArrayElement*)malloc(sizeof(ArrayElement));
//     element->elementType = CHARVAL;
//     element->charVal = c;
//     return element;
// }
// ArrayElement* createIntElement(int i) {
//     ArrayElement* element = (ArrayElement*)malloc(sizeof(ArrayElement));
//     element->elementType = INTVAL;
//     element->intVal = i;
//     return element;
// }
