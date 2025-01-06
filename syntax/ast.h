#ifndef AST_H
#define AST_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

// max children number of our syntax in minic.y
#define MAX_CHILD_NUM 8
typedef struct ASTNode {
    // during semantic analysis, we may check the attributes of children;
    // for example, when we have expr := expr1 + expr2, we will check
    // whether expr1.type == expr2.type. so we use an array to store pointers to children
    struct ASTNode* children[MAX_CHILD_NUM];
    int childNum;
    char* id;
    union {
        int int_val;    // size of a certain type will also be stored here
        char char_val;
        char* str_val;
    }; // the value of CONSTANTS
    int isConst; // default = 1
} ASTNode;

/* create an AST node for identifiers or keywords.
 * @param id: identifier of the node
 * @param childNum: corresponds to the num of symbols on the right side of the production.
 * @param ...: pointers to the children.
 */
ASTNode* createASTNode(char* id, int childNum, ...);

ASTNode* createASTNodeForInt(int val);

ASTNode* createASTNodeForChar(char val);

ASTNode* createASTNodeForStr(char* val);

void preorderPrint(ASTNode* root);

#endif