#include <stdio.h>
#include <stdlib.h>
#include "symbol_table.h"
#include "tac.h"
#include "asm.h"

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

    generateIndex();
    // printTAC();

    // generate assembly code
    AsmContainer* container = (AsmContainer*)malloc(sizeof(AsmContainer));
    initAsmContainer(container);
    initAsm();
    calcFrameInfo(container);
    newAsm(container, ".data");
    initializeGlobalVars(container);
    newAsm(container, ".text");
    generateASM(container);
    char* assembly = toAssembly(container);
    // printAsm(container);

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

    // printSymbolTable(scopeStack[0]);
    destroySymbolTable(scopeStack[0]);

    // generate assembly code
    char* asmFilename = (char*)malloc((strlen(argv[1])+4)*sizeof(char));
    getFilename(argv[1], asmFilename);
    strcat(asmFilename, ".asm");
    FILE* asmOutput = fopen(asmFilename, "w");
    if (asmOutput == NULL) {
        perror("Error opening file.\n");
        return 1;
    }

    fprintf(asmOutput, "%s\n", assembly);

    fclose(asmOutput);





    // char* assembly = "main:\n\taddi	ra, ra, 0\n\tadd     t2, t0, t1   # t2 = t0 + t1\n\tadd     t3, t2, t1   # t3 = t2 + t1\n\tadd     t4, t3, t2   # t4 = t3 + t2\n\tadd     t5, t4, t3   # t5 = t4 + t3\n\tadd     t6, t5, t4   # t6 = t5 + t4\n\taddi	t0, t5, 0\n\taddi	t1, t6, 0\n\tjalr x0, ra,0\n";
    // char* showAssembly = "a:\n"
    //             "        .zero   4\n"
    //             "Fei_Bo:\n"
    //             "        addi    sp,sp,-48\n"
    //             "        sw      ra,44(sp)\n"
    //             "        sw      s0,40(sp)\n"
    //             "        addi    s0,sp,48\n"
    //             "        sw      a0,-36(s0)\n"
    //             "        addi    a5,a5,1\n"
    //             "        sw      a5,-20(s0)\n"
    //             "        addi    a5,a5,1\n"
    //             "        sw      a5,-24(s0)\n"
    //             "        addi    a5,a5,1\n"
    //             "        sw      a5,-28(s0)\n"
    //             "        lw      a4,-36(s0)\n"
    //             "        addi    a5,a5,2\n"
    //             "        ble     a4,a5,label2\n"
    //             "        sw      zero,-32(s0)\n"
    //             "        sw      zero,-32(s0)\n"
    //             "        jal     label3\n"
    //             "label4:\n"
    //             "        lw      a4,-20(s0)\n"
    //             "        lw      a5,-24(s0)\n"
    //             "        add     a5,a4,a5\n"
    //             "        sw      a5,-28(s0)\n"
    //             "        lw      a5,-24(s0)\n"
    //             "        sw      a5,-20(s0)\n"
    //             "        lw      a5,-28(s0)\n"
    //             "        sw      a5,-24(s0)\n"
    //             "        lw      a5,-32(s0)\n"
    //             "        addi    a5,a5,1\n"
    //             "        sw      a5,-32(s0)\n"
    //             "label3:\n"
    //             "        lw      a5,-36(s0)\n"
    //             "        addi    a5,a5,-2\n"
    //             "        lw      a4,-32(s0)\n"
    //             "        blt     a4,a5,label4\n"
    //             "        lw      a5,-28(s0)\n"
    //             "        j       label5\n"
    //             "label2:\n"
    //             "        lw      a5,-28(s0)\n"
    //             "label5:\n"
    //             "        mv      a0,a5\n"
    //             "        lw      ra,44(sp)\n"
    //             "        lw      s0,40(sp)\n"
    //             "        addi    sp,sp,48\n"
    //             "        jr      ra\n"
    //             "main:\n"
    //             "        addi    sp,sp,-32\n"
    //             "        sw      ra,28(sp)\n"
    //             "        sw      s0,24(sp)\n"
    //             "        addi    s0,sp,32\n"
    //             "        sw      zero,-20(s0)\n"
    //             "        lw      a0,-20(s0)\n"
    //             "        call    Fei_Bo\n"
    //             "        sw      a0,-24(s0)\n"
    //             "        addi    a5,a5,0\n"
    //             "        mv      a0,a5\n"
    //             "        lw      ra,28(sp)\n"
    //             "        lw      s0,24(sp)\n"
    //             "        addi    sp,sp,32\n"
    //             "        jr      ra\n";

    // char* asmFilename = (char*)malloc((strlen(argv[1])+4)*sizeof(char));
    // getFilename(argv[1], asmFilename);
    // strcat(asmFilename, ".asm");
    // FILE* asmOutput = fopen(asmFilename, "w");
    // if (asmOutput == NULL) {
    //     perror("Error opening file.\n");
    //     return 1;
    // }

    // fprintf(asmOutput, "%s", assembly);

    // fclose(asmOutput);


    // char* asmShow = (char*)malloc((strlen(argv[1])+4)*sizeof(char));
    // getFilename(argv[1], asmShow);
    // strcat(asmShow, "_.asm");
    // FILE* asmShowOutput = fopen(asmShow, "w");
    // if (asmShowOutput == NULL) {
    //     perror("Error opening file.\n");
    //     return 1;
    // }

    // fprintf(asmShowOutput, "%s", showAssembly);

    // fclose(asmShowOutput);


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