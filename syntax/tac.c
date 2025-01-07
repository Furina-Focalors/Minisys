#include "tac.h"

int tempCnt = 0;
int labelCnt = 0;
struct TACList* tacHead = NULL;
struct TACList* tacTail = NULL;

char* generateTemp() {
    char* tempVar = (char*)malloc(6 * sizeof(char));
    sprintf(tempVar, "t%d", tempCnt++);
    return tempVar;
}

TAC* createTAC(char* op, char* arg1, char* arg2, char* res) {
    TAC* tac = (TAC*)malloc(sizeof(TAC));
    tac->op = op;
    tac->arg1 = arg1;
    tac->arg2 = arg2;
    tac->res = res;
    return tac;
}

void deleteTAC(TAC* tac) {
    free(tac);
}

void appendTAC(TAC* tac) {
    TACList* newNode = (TACList*)malloc(sizeof(TACList));
    newNode->tac = tac;
    newNode->next = NULL;
    
    if (!tacHead) {
        tacHead = newNode;
    } else {
        tacTail->next = newNode;
    }
    tacTail = newNode;
}

void printTAC() {
    TACList* temp = tacHead;
    while (temp) {
        printf("(%s,%s,%s,%s)\n",temp->tac->op, temp->tac->arg1, temp->tac->arg2, temp->tac->res);
        //printf("%s = %s %s %s\n", temp->tac->res, temp->tac->arg1, temp->tac->op, temp->tac->arg2);
        temp = temp->next;
    }
}

char* charToString(char c) {
    char* res = (char*)malloc(2*sizeof(char));
    res[0] = c;
    res[1] = '\0';
    return res;
}

char* generateLabel() {
    char* tempLabel = (char*)malloc(10 * sizeof(char));
    sprintf(tempLabel, "label%d", labelCnt++);
    return tempLabel;
}

int countDigits(int num) {
    if (num == 0) {
        return 1;
    }

    int count = 0;
    if (num < 0) {
        ++count;
        num = -num;
    }
    while (num > 0) {
        num /= 10;
        ++count;
    }
    return count;
}
