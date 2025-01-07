#ifndef TAC_H
#define TAC_H

#include <stdio.h>
#include <stdlib.h>

typedef struct TAC {
    char* op;
    char* arg1;
    char* arg2;
    char* res;
} TAC;

typedef struct TACList {
    TAC* tac;
    struct TACList* next;
} TACList;

char* generateTemp();

TAC* createTAC(char* op, char* arg1, char* arg2, char* res);

void deleteTAC(TAC* tac);

void appendTAC(TAC* tac);

void printTAC();

char* charToString(char c);

char* generateLabel();

int countDigits(int num);

extern int tempCnt;
extern int labelCnt;
extern struct TACList* tacHead;
extern struct TACList* tacTail;

#endif