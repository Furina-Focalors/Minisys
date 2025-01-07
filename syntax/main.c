#include <stdio.h>
#include <stdlib.h>
#include "symbol_table.h"
#include "tac.h"

extern FILE *yyin;
extern int yyparse();
extern struct TACList* tacHead;

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <input_file>\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror("Error opening file");
        return 1;
    }

    // initialize scopeStack
    scopeStack[0] = createSymbolTable();
    for (int i=1;i<SYMBOL_TABLE_STACK_SIZE;++i) {
        scopeStack[i] = NULL;
    }

    yyparse();

    //printSymbolTable(scopeStack[0]);
    destroySymbolTable(scopeStack[0]);

    printTAC();

    fclose(yyin);
    return 0;
}
