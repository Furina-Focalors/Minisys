#include <stdio.h>
#include <string.h>
#include "semantic.h"

int isCompatible(char* type1, char* type2) {
    if (strcmp(type1, "MEM") == 0 || strcmp(type2, "MEM") == 0) return 1;
    return strcmp(type1, type2) == 0 || (strcmp(type1, "SHORT") == 0 && strcmp(type2, "INT") == 0) || (strcmp(type1, "INT") == 0 && strcmp(type2, "SHORT") == 0);
}

int isNum(char* type) {
    return strcmp(type, "INT") == 0 || strcmp(type, "SHORT") == 0 || strcmp(type, "MEM") == 0;
}

int isChar(char* type) {
    return strcmp(type, "CHAR") == 0 || strcmp(type, "MEM") == 0;
}
