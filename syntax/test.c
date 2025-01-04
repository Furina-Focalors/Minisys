#include <assert.h>
#include "symbol_table.h"

void testCreateAndDestroySymbolTable() {
    SymbolTable* symbolTable = createSymbolTable();
    assert(symbolTable != NULL);
    for (int i = 0; i < SYMBOL_TABLE_SIZE; ++i) {
        assert(symbolTable->table[i] == NULL);
    }
    destroySymbolTable(symbolTable);
}

void testInsertSymbol() {
    SymbolTable* symbolTable = createSymbolTable();
    scopeStack[scopeStackTop++] = symbolTable;

    char* type = "int";
    unsigned int size = sizeof(int);
    int isInitialized = 1;
    int isArray = 0;
    int isFunction = 0;
    int isDefined = 1;
    unsigned int stackFrameSize = 0;
    int paramNum = 0;
    char* paramsType[] = {};
    char* parameters[] = {};

    SymbolTableEntry* entry = createSymbolTableEntry("x", type, size, isInitialized, isArray, isFunction, isDefined, stackFrameSize, paramNum, paramsType, parameters);
    insertSymbol(symbolTable, entry);

    SymbolTableEntry* found = findSymbol("x");
    assert(found != NULL);
    assert(strcmp(found->type, "int") == 0);
    assert(found->size == sizeof(int));
    assert(found->isInitialized == 1);
    
    destroySymbolTable(symbolTable);
    scopeStackTop = 1;
}

void testRedefinitionCheck() {
    SymbolTable* symbolTable = createSymbolTable();
    scopeStack[scopeStackTop++] = symbolTable;
    
    char* type = "int";
    unsigned int size = sizeof(int);
    int isInitialized = 1;
    int isArray = 0;
    int isFunction = 0;
    int isDefined = 1;
    unsigned int stackFrameSize = 0;
    int paramNum = 0;
    char* paramsType[] = {};
    char* parameters[] = {};
    
    SymbolTableEntry* entry1 = createSymbolTableEntry("x", type, size, isInitialized, isArray, isFunction, isDefined, stackFrameSize, paramNum, paramsType, parameters);
    int res1 = insertSymbol(symbolTable, entry1);
    
    assert(res1 == 0);
    assert(isDeclared(symbolTable, "x") == 1);  // First declaration is valid.
    
    SymbolTableEntry* entry2 = createSymbolTableEntry("x", type, size, isInitialized, isArray, isFunction, isDefined, stackFrameSize, paramNum, paramsType, parameters);
    int res2 = insertSymbol(symbolTable, entry2);
    
    assert(res2 == -1);  // Second declaration should be detected as redefinition.
    
    destroySymbolTable(symbolTable);
    scopeStackTop = 1;
}

void testFindSymbol() {
    SymbolTable* symbolTable = createSymbolTable();
    scopeStack[scopeStackTop++] = symbolTable;
    
    char* type1 = "int";
    unsigned int size1 = sizeof(int);
    SymbolTableEntry* entry1 = createSymbolTableEntry("x", type1, size1, 1, 0, 0, 1, 0, 0, NULL, NULL);
    insertSymbol(symbolTable, entry1);
    
    char* type2 = "char";
    unsigned int size2 = sizeof(char);
    SymbolTableEntry* entry2 = createSymbolTableEntry("y", type2, size2, 1, 0, 0, 1, 0, 0, NULL, NULL);
    insertSymbol(symbolTable, entry2);
    
    SymbolTableEntry* foundX = findSymbol("x");
    assert(foundX != NULL && strcmp(foundX->type, "int") == 0);
    
    SymbolTableEntry* foundY = findSymbol("y");
    assert(foundY != NULL && strcmp(foundY->type, "char") == 0);
    
    destroySymbolTable(symbolTable);
    scopeStackTop = 1;
}

void testDeleteSymbol() {
    SymbolTable* symbolTable = createSymbolTable();
    scopeStack[scopeStackTop++] = symbolTable;
    
    char* type = "int";
    unsigned int size = sizeof(int);
    SymbolTableEntry* entry = createSymbolTableEntry("x", type, size, 1, 0, 0, 1, 0, 0, NULL, NULL);
    insertSymbol(symbolTable, entry);
    
    SymbolTableEntry* foundBeforeDelete = findSymbol("x");
    assert(foundBeforeDelete != NULL);
    
    deleteSymbol(symbolTable, "x");
    
    SymbolTableEntry* foundAfterDelete = findSymbol("x");
    assert(foundAfterDelete == NULL);  // The symbol should no longer exist.
    
    destroySymbolTable(symbolTable);
    scopeStackTop = 1;
}

void testScopeStack() {
    // global
    insertSymbol(scopeStack[0], createSymbolTableEntry("x", "int", sizeof(int), 1, 0, 0, 1, 0, 0, NULL, NULL));

    // Push a new scope
    scopeStack[scopeStackTop++] = createSymbolTable();
    insertSymbol(scopeStack[scopeStackTop-1], createSymbolTableEntry("x", "char", sizeof(char), 1, 0, 0, 1, 0, 0, NULL, NULL));

    // Find the symbol in the inner scope
    SymbolTableEntry* innerX = findSymbol("x");
    assert(innerX != NULL && strcmp(innerX->type, "char") == 0);

    // Pop the scope
    destroySymbolTable(scopeStack[--scopeStackTop]);
    scopeStack[scopeStackTop] = NULL;
    
    // Find the symbol in the global scope
    SymbolTableEntry* outerX = findSymbol("x");
    assert(outerX != NULL && strcmp(outerX->type, "int") == 0);
    scopeStackTop = 1;
}

void testCreateConstSymbol() {
    union ConstValue value;
    value.intVal = 5;
    
    SymbolTableEntry* constEntry = createConstTableEntry(CONST_INT, value);
    assert(constEntry != NULL);
    assert(constEntry->constType == CONST_INT);
    assert(constEntry->constValue.intVal == 5);
}

int main(){
    // initialize scopeStack
    scopeStack[0] = createSymbolTable();
    assert(scopeStack[0]!=NULL);
    for (int i=1;i<SYMBOL_TABLE_STACK_SIZE;++i) {
        scopeStack[i] = NULL;
    }
    printf("initialize finished.\n");

    // run all tests
    testCreateAndDestroySymbolTable();
    printf("create&Destroy table passed.\n");
    testInsertSymbol();
    printf("insert symbol passed.\n");
    testRedefinitionCheck();
    printf("redefinition check passed.\n");
    testFindSymbol();
    printf("find symbol passed.\n");
    testDeleteSymbol();
    printf("delete symbol passed.\n");
    testScopeStack();
    printf("scope stack test passed.\n");
    testCreateConstSymbol();
    printf("create const symbol passed.\n");

    printf("all test passed.\n");
}


