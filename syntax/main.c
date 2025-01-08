#include <stdio.h>
#include <stdlib.h>
#include "symbol_table.h"
#include "tac.h"

extern FILE *yyin;
extern int yyparse();
extern struct TACList* tacHead;

void getFilename(const char* path, char* filename);

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <input_file>\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        perror("Error opening file.\n");
        return 1;
    }

    // initialize scopeStack
    scopeStack[0] = createSymbolTable();
    for (int i=1;i<SYMBOL_TABLE_STACK_SIZE;++i) {
        scopeStack[i] = NULL;
    }

    yyparse();

    fclose(yyin);

    // write to file
    char* filename = (char*)malloc((strlen(argv[1])+4)*sizeof(char));
    getFilename(argv[1], filename);
    strcat(filename, ".ir");
    FILE* icOutput = fopen(filename, "w");
    if (icOutput == NULL) {
        perror("Error opening file.\n");
        return 1;
    }

    fprintf(icOutput, "[FUNCTIONS]\n");
    for (int i=0;i<SYMBOL_TABLE_SIZE;++i) {
        if (scopeStack[0]->table[i] != NULL && scopeStack[0]->table[i]->entry->isFunction == 1) {
            fprintf(icOutput,"name: %s\n", scopeStack[0]->table[i]->entry->id);
            fprintf(icOutput,"returnType: %s\n", scopeStack[0]->table[i]->entry->type);
            fprintf(icOutput,"parameters: ");
            for (int j=0;j<scopeStack[0]->table[i]->entry->paramNum;++j) {
                if (scopeStack[0]->table[i]->entry->params[j]->isArray == 0) {
                    fprintf(icOutput,"%s(%s)", scopeStack[0]->table[i]->entry->params[j]->id, scopeStack[0]->table[i]->entry->params[j]->type);
                } else {
                    fprintf(icOutput,"%s(%s[])", scopeStack[0]->table[i]->entry->params[j]->id, scopeStack[0]->table[i]->entry->params[j]->type);
                }
                if (j<scopeStack[0]->table[i]->entry->paramNum-1) {
                    fprintf(icOutput, ",");
                }
            }
            fprintf(icOutput, "\n\n");
        }
    }

    fprintf(icOutput, "\n[GLOBAL_VARS]\n");
    for (int i=0;i<SYMBOL_TABLE_SIZE;++i) {
        if (scopeStack[0]->table[i] != NULL && scopeStack[0]->table[i]->entry->isFunction == 0) {
            fprintf(icOutput,"name: %s\n", scopeStack[0]->table[i]->entry->id);
            if (scopeStack[0]->table[i]->entry->isArray == 0) {
                fprintf(icOutput,"type: %s\n", scopeStack[0]->table[i]->entry->type);
            } else {
                fprintf(icOutput,"type: %s[]\n", scopeStack[0]->table[i]->entry->type);
            }
            fprintf(icOutput,"size: %d\n\n", scopeStack[0]->table[i]->entry->size);
        }
    }

    fprintf(icOutput, "\n[CODE]\n");
    TACList* temp = tacHead;
    while (temp) {
        fprintf(icOutput, "(%s,%s,%s,%s)\n",temp->tac->op, temp->tac->arg1, temp->tac->arg2, temp->tac->res);
        temp = temp->next;
    }

    fclose(icOutput);

    //printSymbolTable(scopeStack[0]);
    destroySymbolTable(scopeStack[0]);

    //printTAC();

    return 0;
}

void getFilename(const char* path, char* filename) {
    const char* lastSlash = strrchr(path, '\\');
    if (lastSlash == NULL) {
        lastSlash = path;
    } else {
        lastSlash++;
    }

    const char* lastDot = strrchr(lastSlash, '.');
    if (lastDot != NULL) {
        size_t len = lastDot - lastSlash;
        strncpy(filename, lastSlash, len);
        filename[len] = '\0';
    } else {
        strcpy(filename, lastSlash);
    }
}
