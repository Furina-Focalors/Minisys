#include "ast.h"

ASTNode* createASTNode(char* id, int childNum, ...) {
    ASTNode* cur = (ASTNode*)malloc(sizeof(ASTNode));
    if (cur == NULL) {
        perror("create ast node failed.");
        exit(1);
    }

    cur->id = id;
    cur->childNum = childNum;
    cur->isConst = 1;
    for (int i=0;i<MAX_CHILD_NUM;++i) {
        cur->children[i] = NULL;
    }

    if (childNum > 0) {
        // get children list. method from stdarg.h
        va_list children;
        va_start(children, childNum);
        for (int i=0;i<childNum;++i) {
            cur->children[i] = va_arg(children, ASTNode*);
        }
        va_end(children);
    }

    return cur;
}

ASTNode* createASTNodeForInt(int val) {
    ASTNode* cur = (ASTNode*)malloc(sizeof(ASTNode));
    if (cur == NULL) {
        perror("create ast node failed.");
        exit(1);
    }

    cur->id = "INT_CONSTANT";
    cur->int_val = val;
    cur->isConst = 1;
    cur->childNum = 0;
    for (int i=0;i<MAX_CHILD_NUM;++i) {
        cur->children[i] = NULL;
    }

    return cur;
}

ASTNode* createASTNodeForChar(char val) {
    ASTNode* cur = (ASTNode*)malloc(sizeof(ASTNode));
    if (cur == NULL) {
        perror("create ast node failed.");
        exit(1);
    }

    cur->id = "CHAR_CONSTANT";
    cur->char_val = val;
    cur->isConst = 1;
    cur->childNum = 0;
    for (int i=0;i<MAX_CHILD_NUM;++i) {
        cur->children[i] = NULL;
    }

    return cur;
}

ASTNode* createASTNodeForStr(char* val) {
    ASTNode* cur = (ASTNode*)malloc(sizeof(ASTNode));
    if (cur == NULL) {
        perror("create ast node failed.");
        exit(1);
    }

    cur->id = "STRING_LITERAL";
    cur->str_val = strdup(val);
    cur->isConst = 1;
    cur->childNum = 0;
    for (int i=0;i<MAX_CHILD_NUM;++i) {
        cur->children[i] = NULL;
    }

    return cur;
}

void preorderPrint(ASTNode* root) {
    if (root == NULL) return;
    printf("%s ", root->id);
    for (int i=0;i<root->childNum;++i) {
        preorderPrint(root->children[i]);
    }
}


// int main() {
//     ASTNode* node1 = createASTNodeForInt(1013);
//     ASTNode* node2 = createASTNode("ID", 0);
//     ASTNode* node3 = createASTNode("+", 0);
//     ASTNode* expr1 = createASTNode("EXPR", 3, node2, node3, node1);

//     ASTNode* node4 = createASTNodeForStr("mylove");
//     ASTNode* node5 = createASTNode("ID", 0);
//     ASTNode* node6 = createASTNode("ASSIGN_OP", 0);
//     ASTNode* expr2 = createASTNode("EXPR", 3, node5, node6, node4);

//     ASTNode* node7 = createASTNode("-", 0);
//     ASTNode* root = createASTNode("EXPR", 3, expr1, node7, expr2);

//     // 打印 AST
//     printf("AST Structure (Preorder Traversal):\n");
//     preorderPrint(root);

//     return 0;
// }
