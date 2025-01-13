#include "asm.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "symbol_table.h"
#include "tac.h"

int indexAddrDesc = 0;
int indexStackFrameInfos = 0;
// 定义寄存器数组
const char* all_regs[] = {
    "x0", "x1", "x2", "x3", "x4", "x5", "x6", "x7",
    "x8", "x9", "x10", "x11", "x12", "x13", "x14", "x15",
    "x16", "x17", "x18", "x19", "x20", "x21", "x22", "x23",
    "x24", "x25", "x26", "x27", "x28", "x29", "x30", "x31"
};

const char* UsefulRegs[] = {
  "x5", "x6", "x7", "x28", "x29", "x30", "x31",
  "x8", "x9", "x18", "x19", "x20", "x21", "x22", "x23"
};

/* Set start */

Set* createSet() {
    Set* set = (Set*)malloc(sizeof(Set));
    set->elements = (char**)malloc(10 * sizeof(char*)); // 初始容量为10
    set->size = 0;
    set->capacity = 10;
    return set;
}

void setAdd(Set* set, char* element) {
    if (set->size >= set->capacity) {
        set->capacity *= 2;
        set->elements = (char**)realloc(set->elements, set->capacity * sizeof(char*));
    }
    set->elements[set->size++] = strdup(element);
}

int setHas(Set* set, char* element) {
    for (int i = 0; i < set->size; ++i) {
        if (strcmp(set->elements[i], element) == 0) {
            return 1;
        }
    }
    return 0;
}

void setClear(Set* set) {
    for (int i = 0; i < set->size; ++i) {
        free(set->elements[i]);
    }
    set->size = 0;
}

void setDelete(Set* set, char* element) {
    for (int i = 0; i < set->size; ++i) {
        if (strcmp(set->elements[i], element) == 0) {
            free(set->elements[i]);
            for (int j = i; j < set->size - 1; ++j) {
                set->elements[j] = set->elements[j + 1];
            }
            set->size--;
            return;
        }
    }
}

void setFree(Set* set) {
    setClear(set);
    free(set->elements);
    free(set);
}

/* Set end */

int mapRegDesc(char* key) {
    int index = -1;

    if (strcmp(key, "x5") == 0) {
        index = 0;
    } else if (strcmp(key, "x6") == 0) {
        index = 1;
    } else if (strcmp(key, "x7") == 0) {
        index = 2;
    } else if (strcmp(key, "x28") == 0) {
        index = 3;
    } else if (strcmp(key, "x29") == 0) {
        index = 4;
    } else if (strcmp(key, "x30") == 0) {
        index = 5;
    } else if (strcmp(key, "x31") == 0) {
        index = 6;
    } else if (strcmp(key, "x18") == 0) {
        index = 7;
    } else if (strcmp(key, "x19") == 0) {
        index = 8;
    } else if (strcmp(key, "x20") == 0) {
        index = 9;
    } else if (strcmp(key, "x21") == 0) {
        index = 10;
    } else if (strcmp(key, "x22") == 0) {
        index = 11;
    } else if (strcmp(key, "x23") == 0) {
        index = 12;
    } else if (strcmp(key, "x8") == 0) {
        index = 13;
    } else if (strcmp(key, "x9") == 0) {
        index = 14;
    } else {
        index = -1;
    }

    return index;
}
int mapAddrDesc(char* key) {
    int index = -1;
    for (int i = 0; i < indexAddrDesc; i++) {
        if (strcmp(addrDescPairs[i], key) == 0) {
            index = i;
        }
    }

    return index;
}
int mapStackInfo(char* key) {
    int index = -1;
    for (int i = 0; i < indexStackFrameInfos; i++) {
        // printf("func: %s\n key: %s\n", funcPairs[i], key);
        if (strcmp(funcPairs[i], key) == 0) {
            index = i;
        }
    }

    return index;
}

/**************************************************************************/
// 标记寄存器是否已分配
static int reg_allocated[32] = { 0 };

// 初始化寄存器描述符管理
void init_registers() {  
    for (int i = 0; i < MAX_REGISTERS; i++) {
        registerDescriptors[i].usable = true; // 默认可用
        registerDescriptors[i].variables = createSet();
        if (registerDescriptors[i].variables == NULL) {
            fprintf(stderr, "Failed to allocate memory for registers[%d].variables\n", i);
            exit(EXIT_FAILURE);
        }
        for (int j = 0; j < MAX_VARIABLES; j++) {
            setAdd(registerDescriptors[i].variables, NULL);  // 初始为空指针
        }
        reg_allocated[i] = 0;
    }
}

// 释放寄存器描述符
void free_registers() {
    for (int i = 0; i < MAX_REGISTERS; i++) {
        if (registerDescriptors[i].variables != NULL) {
            setFree(registerDescriptors[i].variables);
        }
    }
}

// 释放单个寄存器描述符
void release_register(int reg) {
    if (reg >= 0 && reg < 32) {
        reg_allocated[reg] = 0;
        // 清空寄存器中的变量
        setClear(registerDescriptors[reg].variables);
    }
}
/**************************************************************************/

// 初始化registers addressDescriptors stackFrameInfos
void initAsm() {
    // 初始化寄存器描述符
    init_registers();

    // 初始化地址描述符
    for (int i = 0; i < MAX_VARS; i++) {
        addressDescriptors[i].currentAddresses = createSet();  // 动态分配或默认空指针
        addressDescriptors[i].boundMemAddress = NULL;  // 暂时null
    }

    // 初始化栈帧信息
    for (int i = 0; i < MAX_FUNCTIONS; i++) {
        stackFrameInfos[i].isLeaf = true;  // 默认是叶函数
        stackFrameInfos[i].wordSize = WORD_LENGTH_BYTE;  // 默认字节大小
        stackFrameInfos[i].outgoingSlots = 0;  // 默认无出栈参数
        stackFrameInfos[i].localData = 0;  // 默认没有局部数据
        stackFrameInfos[i].numGPRs2Save = 0;  // 默认无需保存寄存器
        stackFrameInfos[i].numReturnAdd = 0;  // 默认没有返回地址
    }
}

void freeAsm() {
    // 释放寄存器描述符中的变量数组内存
    free_registers();

    // 释放地址描述符中的当前地址数组内存
    for (int i = 0; i < MAX_VARS; i++) {
        if (addressDescriptors[i].currentAddresses != NULL) {
            setFree(addressDescriptors[i].currentAddresses);
        }
    }

    // 释放栈帧信息中可能使用的动态内存（如果有）
    // 在目前的设计中，栈帧信息没有动态分配的内容，但如果未来需要，可以在这里释放
    // 例如，如果栈帧信息包含动态分配的字符串数组或其他结构体
}

// 初始化 AsmContainer
void initAsmContainer(AsmContainer* container) {
    container->asmLines = (char**)malloc(INITIAL_ASM_SIZE * sizeof(char*));
    if (container->asmLines == NULL) {
        // 检查 malloc 是否成功
        fprintf(stderr, "Failed to allocate memory for asmLines\n");
        exit(EXIT_FAILURE);
    }
    container->size = 0;
    container->capacity = INITIAL_ASM_SIZE;
}

// 释放 AsmContainer 内存
void freeAsmContainer(AsmContainer* container) {
    for (size_t i = 0; i < container->size; i++) {
        if (container->asmLines[i] != NULL) {  // 检查指针是否为 NULL
            free(container->asmLines[i]);  // 释放每一行的内存
            container->asmLines[i] = NULL;  // 防止双重释放
        }
    }
    free(container->asmLines);  // 释放数组本身
    container->asmLines = NULL;  // 防止双重释放
}

// 加载变量到寄存器
void loadVar(const char* varId, const char* registerName, AsmContainer* asmContainer) {
    // 查找变量的绑定内存地址
    char* varLoc = NULL;
    int indexAddrDesc = mapAddrDesc((char*)varId); // 寻找变量的地址描述符索引
    if (indexAddrDesc == -1) {
        fprintf(stderr, "Cannot find the address descriptor for this variable: %s\n", varId);
        return;
    }
    varLoc = addressDescriptors[indexAddrDesc].boundMemAddress;

    if (varLoc == NULL) {
        fprintf(stderr, "Cannot get the bound address for this variable: %s\n", varId);
        return;
    }

    // 生成 lw 指令
    char line[256];
    snprintf(line, sizeof(line), "lw %s, %s", registerName, varLoc);
    newAsm(asmContainer, line);

    // 更新寄存器描述符，清除原有变量，添加新变量
    for (int i = 0; i < MAX_REGISTERS; i++) {
        if (strcmp(registerName, UsefulRegs[i]) == 0) { // 找到变量所在的寄存器
            setClear(registerDescriptors[i].variables);
            setAdd(registerDescriptors[i].variables, (char*)varId);
            break;
        }
    }

    // 更新地址描述符，增加寄存器为当前地址
    setAdd(addressDescriptors[indexAddrDesc].currentAddresses, (char*)registerName);
}

// 回写寄存器内容到内存
void storeVar(const char* varId, const char* registerName, AsmContainer* asmContainer) {
    // 查找变量的绑定内存地址
    char* varLoc = NULL;
    int indexAddrDesc = mapAddrDesc((char*)varId); // 寻找变量的地址描述符索引
    if (indexAddrDesc == -1) {
        fprintf(stderr, "Cannot find the address descriptor for this variable: %s\n", varId);
        return;
    }
    varLoc = addressDescriptors[indexAddrDesc].boundMemAddress;

    // 如果未找到绑定地址，抛出错误
    assert(varLoc != NULL && "Cannot get the bound address for this variable");

    // 生成 sw 指令，将寄存器内容写入内存
    char line[256];
    snprintf(line, sizeof(line), "sw %s, %s", registerName, varLoc);
    newAsm(asmContainer, line);  // 将汇编指令添加到 asmContainer

    // 更新地址描述符，增加 varLoc 到 currentAddresses
    setAdd(addressDescriptors[indexAddrDesc].currentAddresses, (char*)varLoc);
}

// 将空格替换为制表符(\t)（可用可不用，目前不使用）
void replaceSpacesWithTabs(char* line) {
    for (size_t i = 0; line[i] != '\0'; i++) {
        if (line[i] == ' ') {
            line[i] = '\t';
        }
    }
}

// 生成汇编代码的函数
char* toAssembly(AsmContainer* container) {
    // 用于存储生成的汇编代码
    static char result[65536];  // 假设最大能容纳的汇编代码大小

    result[0] = '\0';  // 初始化为空字符串

    for (size_t i = 0; i < container->size; i++) {
        char* line = container->asmLines[i];

        // 检查行是否以 '.'开头 或 存在':'
        if (!(line[0] == '.' || strchr(line, ':') != NULL)) {
            // 如果不是以 . '.'开头 或 存在':'，给行前添加制表符
            char formattedLine[MAX_LINE_LENGTH];
            snprintf(formattedLine, sizeof(formattedLine), "\t%s", line);

            // 替换空格为制表符
            //replaceSpacesWithTabs(formattedLine);

            // 将格式化后的行添加到最终结果中
            strcat(result, formattedLine);
        }
        else {
            // 否则，直接将行添加到最终结果中
            strcat(result, line);
        }

        // 添加换行符
        strcat(result, "\n");

        //printf("%s", result);
    }

    return result;
}

// 添加一行汇编代码
void newAsm(AsmContainer* container, const char* line) {
    // 如果当前数组已满，扩展数组
    if (container->size >= container->capacity) {
        container->capacity *= 2;  // 扩展为原来的两倍
        container->asmLines = (char**)realloc(container->asmLines, container->capacity * sizeof(char*));
    }

    // 复制新行的汇编代码到数组
    container->asmLines[container->size] = _strdup(line);
    container->size++;
}

// 生成声明全局变量代码
void initializeGlobalVars(AsmContainer* container) {
    if (container == NULL) {
        fprintf(stderr, "AsmContainer is NULL.\n");
        return;
    }

    if (scopeStack[0] == NULL) {
        printf("Symbol table is empty.\n");
        return;
    }

    // printf("Initializing global variables...\n");

    for (int i = 0; i < SYMBOL_TABLE_SIZE; ++i) {
        if (scopeStack[0]->table[i] != NULL) {
            HashNode* temp = scopeStack[0]->table[i];
            while (temp != NULL) {
                SymbolTableEntry* entry = temp->entry;
                if (entry->isFunction == 0) {  // 检查是否是全局变量
                    if (entry->isArray == 1) {
                        // 声明数组
                        char line[256];
                        snprintf(line, sizeof(line), "%s: .space %d", entry->id, entry->size);
                        newAsm(container, line);
                    } else {
                        // 声明单个变量
                        char line[256];
                        snprintf(line, sizeof(line), "%s: .word 0", entry->id);
                        newAsm(container, line);
                    }
                }
                temp = temp->next;
            }
        }
    }
}

/*+++++++++++++++++++++++++++++++++++++++++++ 有问题*/

// 计算函数的栈帧信息（未测试，有问题，局部变量相关上层还在调试）
void calcFrameInfo(AsmContainer* container) {
    int funcPoolCount = 0; // for 循环计算函数个数
    char* funcName[MAX_FUNCTIONS]; 
    for (int i = 0; i < SYMBOL_TABLE_SIZE; ++i) {
        if (scopeStack[0]->table[i] != NULL) {
            HashNode* temp = scopeStack[0]->table[i];
            while (temp != NULL) {
                SymbolTableEntry* entry = temp->entry;
                if (entry->isFunction == 1) {  // 检查是否是函数
                    funcName[funcPoolCount++] = entry->id;
                }
                temp = temp->next;
            }
        }
    }
    // printf("funcPoolCount: %d\n", funcPoolCount);


    for (int funcIdx = 0; funcIdx < funcPoolCount; funcIdx++) {
        // 计算函数的栈帧大小
        int isLeaf = true; // outer->childFuncsCount == 0，我们不做子函数相关的，默认是叶函数
        int maxArgs = 0;
        // for (int innerIdx = 0; innerIdx < funcPoolCount; innerIdx++) {
        //     SymbolTableEntry* inner = funcPool[innerIdx];
        //     for (int childIdx = 0; childIdx < outer->childFuncsCount; childIdx++) {
        //         if (!strcmp(inner->id, outer->childFuncs[childIdx]->funcName)) {
        //             maxArgs = inner->paramNum > maxArgs ? inner->paramNum : maxArgs;
        //         }
        //     }
        // }
        int outgoingSlots = isLeaf ? 0 : maxArgs > 4 ? maxArgs : 4;
        int localData = 4;
        
        // for (int localVarIdx = 0; localVarIdx < scopeStack[0]->table[funcIdx]->entry->paramNum; localVarIdx++) { // 不能遍利paramnum，应该是遍利所有局部变量而非参数
        //     FuncParam* localVar = scopeStack[0]->table[funcIdx]->entry->params[localVarIdx];
        //     if (!strcmp(localVar->type, "int")) {
        //         int isParam = 0;
        //         for (int paramIdx = 0; paramIdx < scopeStack[0]->table[funcIdx]->entry->paramNum; paramIdx++) {
        //             if (strcmp(localVar->id, scopeStack[0]->table[funcIdx]->entry->params[paramIdx]->id) == 0) {
        //                 isParam = 1;
        //                 break;
        //             }
        //         }
        //         if (!isParam) localData++;
        //     } else {
        //         printf("Error: localVar is not an instance of IRVar\n");
        //     }
        // }
        int numGPRs2Save = !strcmp(funcName[funcIdx], "main") ? 0 : localData > 10 ? (localData > 18 ? 8 : localData - 8) : 0;
        // printf("%d", numGPRs2Save);
        
        int wordSize = (isLeaf ? 0 : 1) + localData + numGPRs2Save + outgoingSlots + numGPRs2Save;
        if (wordSize % 2 != 0) wordSize++; // padding
        stackFrameInfos[indexStackFrameInfos].isLeaf = isLeaf;
        stackFrameInfos[indexStackFrameInfos].wordSize = wordSize;  // 默认字节大小
        stackFrameInfos[indexStackFrameInfos].outgoingSlots = outgoingSlots;  
        stackFrameInfos[indexStackFrameInfos].localData = localData;  
        stackFrameInfos[indexStackFrameInfos].numGPRs2Save = numGPRs2Save;  
        stackFrameInfos[indexStackFrameInfos].numReturnAdd = isLeaf ? 0 : 1;
        funcPairs[indexStackFrameInfos] = funcName[funcIdx];
        indexStackFrameInfos++;
        // printf("funcName: %s, isLeaf: %d, wordSize: %d, outgoingSlots: %d, localData: %d, numGPRs2Save: %d, numReturnAdd: %d\n", funcPairs[indexStackFrameInfos-1], stackFrameInfos[indexStackFrameInfos-1].isLeaf, stackFrameInfos[indexStackFrameInfos-1].wordSize, stackFrameInfos[indexStackFrameInfos-1].outgoingSlots, stackFrameInfos[indexStackFrameInfos-1].localData, stackFrameInfos[indexStackFrameInfos-1].numGPRs2Save, stackFrameInfos[indexStackFrameInfos-1].numReturnAdd);
    }
    // printf("funcPairs:\n%s", funcPairs[1]);

    // printf("stackFrameInfos:\n");
    // for (int i = 0; i < indexStackFrameInfos; i++) {
    //     printf("funcName: %s, isLeaf: %d, wordSize: %d, outgoingSlots: %d, localData: %d, numGPRs2Save: %d, numReturnAdd: %d\n", funcPairs[i], stackFrameInfos[i].isLeaf, stackFrameInfos[i].wordSize, stackFrameInfos[i].outgoingSlots, stackFrameInfos[i].localData, stackFrameInfos[i].numGPRs2Save, stackFrameInfos[i].numReturnAdd);
    // }

    // for (int i = 0; i < SYMBOL_TABLE_SIZE; ++i) { 
    //     if (scopeStack[0]->table[i] != NULL) {
    //         HashNode* temp = scopeStack[0]->table[i];
    //         while (temp != NULL) {
    //             SymbolTableEntry* entry = temp->entry;
    //             if (entry->isFunction == 1) {  // 检查是否是函数
    //                 // 固态分配大小
    //                 stackFrameInfos[indexStackFrameInfos].isLeaf = true;  // 默认是叶函数
    //                 stackFrameInfos[indexStackFrameInfos].wordSize = wordSize;  // 默认字节大小
    //                 stackFrameInfos[indexStackFrameInfos].outgoingSlots = 0;  // 默认无出栈参数
    //                 stackFrameInfos[indexStackFrameInfos].localData = 4;  // 默认4个局部数据
    //                 stackFrameInfos[indexStackFrameInfos].numGPRs2Save = 0;  // 默认无需保存寄存器
    //                 stackFrameInfos[indexStackFrameInfos].numReturnAdd = 0;  // 默认没有返回地址
    //                 indexStackFrameInfos++;
    //             }
    //             temp = temp->next;
    //         }
    //     }
    // }
}

// 辅助函数，检查寄存器中是否有指定变量
bool checkRegisterForVariable(const char* regName, const char* varId) {
    bool flag = false;
    for (int i = 0; i < MAX_REGISTERS; i++) {
        if (strcmp(UsefulRegs[i], regName) == 0) {
            flag = setHas(registerDescriptors[i].variables, (char*)varId);
        }
    }
    return flag == 1;
}

// 为一条四元式获取每个变量可用的寄存器（龙书8.6.3）
char** getRegs(TAC* ir, int irIndex, AsmContainer* asmContainer) {
    char* op = ir->op;
    char* arg1 = ir->arg1;
    char* arg2 = ir->arg2;
    char* res = ir->res;

    int binaryOp = (arg1 != NULL && *arg1 != '\0') && (arg2 != NULL && *arg2 != '\0');
    int unaryOp = (arg1 != NULL && *arg1 != '\0') ^ (arg2 != NULL && *arg2 != '\0');

    char** regs = (char**)malloc(3 * sizeof(char*));
    if (regs == NULL) {
        fprintf(stderr, "Failed to allocate memory for regs\n");
        exit(EXIT_FAILURE);
    }

    for (int i = 0; i < 3; i++) {
        regs[i] = "";
    }

    if (strcmp(op, "=$") == 0 || strcmp(op, "call") == 0 || strcmp(op, "ifFalseGoto") == 0 || strcmp(op, "=") == 0 || strcmp(op, "[]=") == 0 || strcmp(op, "=[]") == 0) {
        if (strcmp(op, "=$") == 0) { // 赋值操作
            char* regY = allocateReg(irIndex, arg1, arg2, res, asmContainer);
            if (regY != NULL && !checkRegisterForVariable(regY, arg1)) {
                loadVar(arg1, regY, asmContainer);
            }
            char* regZ = allocateReg(irIndex, arg2, arg1, res, asmContainer);
            if (regZ != NULL && !checkRegisterForVariable(regZ, arg2)) {
                loadVar(arg2, regZ, asmContainer);
            }
            regs[0] = regY;
            regs[1] = regZ;
        } else if (strcmp(op, "call") == 0) {
            char* regX = allocateReg(irIndex, res, arg1, arg2, asmContainer);
            regs[0] = regX;
        } else if (strcmp(op, "ifFalseGoto") == 0) {
            char* regY = allocateReg(irIndex, arg1, arg2, res, asmContainer);
            if (regY != NULL && !checkRegisterForVariable(regY, arg1)) {
                loadVar(arg1, regY, asmContainer);
            }
            // 生成 beqz 指令
            char line[256];
            snprintf(line, sizeof(line), "beq %s, %s, 0", regY, res);
            newAsm(asmContainer, line);
            regs[0] = regY;
        } else if (strcmp(op, "=") == 0) {
            char* regY = allocateReg(irIndex, arg1, arg2, res, asmContainer);
            // if (regY != NULL) {
            //     printf("Warning: %s is assigned to %s, but it is not used later.\n", arg1, res);
            // }
            if (regY != NULL && !checkRegisterForVariable(regY, arg1)) {
                loadVar(arg1, regY, asmContainer);
            }
            char* regX = regY;  // always choose RegX = RegY
            regs[0] = regY;
            regs[1] = regX;
        } else if (strcmp(op, "[]=") == 0) { // 数组赋值
            char* regY = allocateReg(irIndex, arg1, arg2, res, asmContainer);
            if (regY != NULL && !checkRegisterForVariable(regY, arg1)) {
                loadVar(arg1, regY, asmContainer);
            }
            char* regZ = allocateReg(irIndex, arg2, arg1, res, asmContainer);
            if (regZ != NULL && !checkRegisterForVariable(regZ, arg2)) {
                loadVar(arg2, regZ, asmContainer);
            }
            regs[0] = regY;
            regs[1] = regZ;
        } else if (strcmp(op, "=[]") == 0) { // 数组取值
            char* regZ = allocateReg(irIndex, arg2, arg1, res, asmContainer);
            if (regZ != NULL && !checkRegisterForVariable(regZ, arg2)) {
                loadVar(arg2, regZ, asmContainer);
            }
            char* regX = allocateReg(irIndex, res, arg1, arg2, asmContainer);
            regs[0] = regZ;
            regs[1] = regX;
        }
    } else if (binaryOp) {
        char* regY = allocateReg(irIndex, arg1, arg2, res, asmContainer);
        // if (regY != NULL) {printf(regY);}
        if (regY != NULL && !checkRegisterForVariable(regY, arg1)) {
            loadVar(arg1, regY, asmContainer);
        }
        char* regZ = allocateReg(irIndex, arg2, arg1, res, asmContainer);
        if (regZ != NULL && !checkRegisterForVariable(regZ, arg2)) {
            loadVar(arg2, regZ, asmContainer);
        }

        // if res is either of arg1 or arg2, then simply use the same register
        char* regX = "";
        if (res != NULL && strcmp(res, arg1) == 0) {
            regX = regY;
        } else if (res != NULL && strcmp(res, arg2) == 0) {
            regX = regZ;
        } else {
            regX = allocateReg(irIndex, res, arg1, arg2, asmContainer);
        }
        regs[0] = regY;
        regs[1] = regZ;
        regs[2] = regX;
    } else if (unaryOp) {
        char* regY = allocateReg(irIndex, arg1, arg2, res, asmContainer);
        if (regY != NULL && !checkRegisterForVariable(regY, arg1)) {
            loadVar(arg1, regY, asmContainer);
        }

        char* regX = res != NULL && strcmp(res, arg1) == 0 ? regY : allocateReg(irIndex, res, arg1, arg2, asmContainer);
        regs[0] = regY;
        regs[1] = regX;
    } else {
        assert(false && "Illegal op.");
    }

    return regs;
}

// 寄存器分配函数（龙书8.6.3）
char* allocateReg(int irIndex, const char* thisArg, const char* otherArg, const char* res, AsmContainer* asmContainer) {
    // 如果已经在寄存器里，则直接返回
    for (int i = 0; i < MAX_REGISTERS; i++) {
        if (setHas(registerDescriptors[i].variables, (char*)thisArg)) {
            return (char*)UsefulRegs[i];
        }
    }

    // 如果没在寄存器里，则先寻找空闲的寄存器
    for (int i = 0; i < MAX_REGISTERS; i++) {
        if (registerDescriptors[i].usable && registerDescriptors[i].variables->size == 0) { // 寻找第一个空闲的寄存器
            // registerDescriptors[i].usable = 1; 
            setAdd(registerDescriptors[i].variables, (char*)thisArg);
            return (char*)UsefulRegs[i];
        }
    }

    // 如果没有空闲寄存器，选择一个寄存器进行替换
    int minScore = 256;
    char* minKey = NULL; // 记录最小得分的寄存器
    int scores[MAX_REGISTERS] = {0}; // 记录index号寄存器的得分
    for (int i = 0; i < MAX_REGISTERS; i++) {
        if (!registerDescriptors[i].usable) {
            scores[i] = 256; // 对于不可用的寄存器，得分设为256
            continue;
        }

        int scoreValue = 0;
        Set* currentVariables = registerDescriptors[i].variables;
        for (int j = 0; j < currentVariables->size; j++) {
            const char* currentVar = registerDescriptors[i].variables->elements[j]; // 当前寄存器里的变量

            // 它是结果操作数，而不是另一个参数操作数，可以替换，因为这个值永远不会再使用
            if (res != NULL && strcmp(currentVar, res) == 0 && strcmp(currentVar, otherArg) != 0) {
                continue;
            }

            // 查找当前变量是否在后续指令中使用
            bool reused = false;
            int tempIndex = irIndex + 1;  // 从下一个指令开始检查
            bool procedureEnd = false;
            TACList* tempTAC = tacHead;
            while (tempTAC != NULL) { // 先定位到当前指令
                if (tempIndex == tempTAC->tac->index) {
                    break;
                }
                tempTAC = tempTAC->next;
            }
            while (!procedureEnd && !reused) {
                if (strcmp(currentVar, tempTAC->tac->arg1) == 0 || strcmp(currentVar, tempTAC->tac->arg2) == 0 || strcmp(currentVar, tempTAC->tac->res) == 0) {
                    reused = true;
                    break;
                }
                if (tempTAC->tac->op == "return") procedureEnd = true;
            }

            if (!reused) { // 此变量将永远不会再用作该过程后续指令中的参数
                continue;
            } else {
                int index = mapAddrDesc((char*)currentVar);
                if (addressDescriptors[index].boundMemAddress != NULL) {
                    Set *currAddresses = addressDescriptors[index].currentAddresses;
                    if (currAddresses != NULL && currAddresses->size > 1) {
                        // 它有另一个当前地址，可以直接替换此地址而不生成存储指令
                        continue;
                    } else {
                        // 可以替换，但需要额外的存储指令
                        scoreValue += 1;
                    }
                } else {
                    // 这临时变量，没有内存地址，因此无法替换
                    scoreValue = 256;
                }
            }
            scores[i] = scoreValue;
        }

        if (scoreValue < minScore) {
            minScore = scoreValue;
            minKey = (char*)UsefulRegs[i];
        }
    }

    // assert(minScore != 256 && "Cannot find a register to replace.");

    char* finalReg = minKey;
    if (minScore > 0) {
        // 需要生成store指令
        int indexRegDesc = mapRegDesc(finalReg);
        Set* currentVariables = registerDescriptors[indexRegDesc].variables;
        for (int j = 0; j < currentVariables->size; j++) {
            char* currentVar = currentVariables->elements[j]; // 当前寄存器里的变量
            int indexAddrDesc = mapAddrDesc(currentVar);
            char* boundMemAddress = addressDescriptors[indexAddrDesc].boundMemAddress;
            if (!setHas(addressDescriptors[indexAddrDesc].currentAddresses, boundMemAddress)) {
                storeVar(currentVar, finalReg, asmContainer);
                setDelete(registerDescriptors[indexRegDesc].variables, currentVar);
                setDelete(addressDescriptors[indexAddrDesc].currentAddresses, finalReg);
            }
        }
    }

    return finalReg;
}

void allocateProcMemory(AsmContainer* asmContainer, int index, char* funcName) {
    StackFrameInfo frameInfo = stackFrameInfos[index];

    // Save args passed by register to memory
    for (int idx = 0; idx < findSymbol(funcName)->paramNum; idx++) { // 固态分
        char memLoc[32];
        snprintf(memLoc, sizeof(memLoc), "%d(sp)", WORD_LENGTH_BYTE * (frameInfo.wordSize + idx));
        if (idx < 4) {
            char asmLine[32];
            snprintf(asmLine, sizeof(asmLine), "sw x%d, %s", idx, memLoc);
            newAsm(asmContainer, asmLine);
        }
        
        addressDescriptors[indexAddrDesc].boundMemAddress = memLoc;
        setAdd(addressDescriptors[indexAddrDesc].currentAddresses, memLoc);
        addrDescPairs[indexAddrDesc] = findSymbol(funcName)->params[idx]->id;
        indexAddrDesc++;
    }
    
    /***************没有办法拿到局部变量，没法给局部变量分配内存，和地址描述符 */
    int remainingLVSlots = frameInfo.localData;
    char memLoc[32];
    int offset = WORD_LENGTH_BYTE * (frameInfo.wordSize - (frameInfo.isLeaf ? 0 : 1) - frameInfo.numGPRs2Save - remainingLVSlots);
    snprintf(memLoc, sizeof(memLoc), "%d(sp)", offset);
    remainingLVSlots--;

    addressDescriptors[indexAddrDesc].boundMemAddress = memLoc;
    setAdd(addressDescriptors[indexAddrDesc].currentAddresses, memLoc);
    addrDescPairs[indexAddrDesc] = "a";
    indexAddrDesc++;
    /***************没有办法拿到局部变量，没法给局部变量分配内存 */

    // Allocate s2 ~ s11
    int availableRSs = strcmp(funcName, "main") == 0 ? 8 : frameInfo.numGPRs2Save;
    for (int index = 2; index < 12; index++) {
        registerDescriptors[index].usable = index < availableRSs;
        setAdd(registerDescriptors[index].variables, (char*)"");
    }

    // printf("%d", findSymbol(funcName)->paramNum);
    allocateGlobalMemory(asmContainer);
}

void allocateGlobalMemory(AsmContainer* asmContainer) {
    for (int i = 0; i < SYMBOL_TABLE_SIZE; ++i) {
        if (scopeStack[0]->table[i] != NULL) {
            HashNode* temp = scopeStack[0]->table[i];
            while (temp != NULL) {
                SymbolTableEntry* entry = temp->entry;
                if (entry->isFunction == 0) {  // 检查是否是全局变量
                    if (entry->isArray == 1) {
                        int index = mapAddrDesc(entry->id);
                        addressDescriptors[index].boundMemAddress = entry->id;
                        setAdd(addressDescriptors[index].currentAddresses, entry->id);
                    } else {
                        int index = mapAddrDesc(entry->id);
                        addressDescriptors[index].boundMemAddress = entry->id;
                        char buffer[100];
                        snprintf(buffer, sizeof(buffer), "%s(zero)", entry->id);
                        setAdd(addressDescriptors[index].currentAddresses, buffer);
                    }
                }
                temp = temp->next;
            }
        }
    }
}

void deallocateProcMemory(AsmContainer* asmContainer) {
    for (int i = 0; i < indexAddrDesc; i++) {
        char* boundMemAddress = addressDescriptors[i].boundMemAddress;
        Set* currentAddresses = addressDescriptors[i].currentAddresses;
        if (boundMemAddress != NULL && !setHas(currentAddresses, boundMemAddress)) {
            // need to write this back to its bound memory location
            if (currentAddresses->size > 0) {
                for (int j = 0; j < currentAddresses->size; j++) {
                    char* addr = currentAddresses->elements[j];
                    if (strcmp(addr, "x") == 0) {
                        storeVar(addrDescPairs[i], boundMemAddress, asmContainer);
                        break;
                    }
                }
            } else {
                printf("Warning: Attempted to store a ghost variable.\n");
            }
        }
    }

    for (int i = 0; i < indexAddrDesc; i++) {
        addrDescPairs[i] = NULL;
        addressDescriptors[i].boundMemAddress = NULL;
        setClear(addressDescriptors[i].currentAddresses);
    }
    indexAddrDesc = 0;
    for (int i = 0; i < MAX_REGISTERS; i++) {
        setClear(registerDescriptors[i].variables);
    }
    
}

void manageResDescriptors(char* regX, char* res, AsmContainer* asmContainer) {
    // 将寄存器 regX 的寄存器描述符更改为仅保存 res 
    int indexRegDesc = mapRegDesc(regX);
    setClear(registerDescriptors[indexRegDesc].variables);
    setAdd(registerDescriptors[indexRegDesc].variables, res);

    int index = mapAddrDesc(res);
    if (index != -1) {
        // 从除 res 以外的任何变量的地址描述符中移除 regX
        for (int i = 0; i < indexAddrDesc; i++) {
            if(setHas(addressDescriptors[i].currentAddresses, regX)) {
                setDelete(addressDescriptors[i].currentAddresses, regX);
            }
        }
        // 更改 res 的地址描述符，使其唯一的存储位置为 regX
        // 注意 res 的内存位置现在不在 res 的地址描述符中！
        setClear(addressDescriptors[index].currentAddresses);
        setAdd(addressDescriptors[index].currentAddresses, regX);
    } else {
        // 说明res是局部变量，需要分配内存
        addressDescriptors[indexAddrDesc].boundMemAddress = res;
        addressDescriptors[indexAddrDesc].currentAddresses = createSet();
        setAdd(addressDescriptors[indexAddrDesc].currentAddresses, res);
        addrDescPairs[indexAddrDesc] = res;
        indexAddrDesc++;
    }
}

void removePrefix(const char* input, char** labelType, char** funcName) {
    // 查找第一个 '_' 字符
    char* underscorePos = strchr(input, '_');
    
    if (underscorePos != NULL) {
        // 计算前缀长度
        size_t labelLength = underscorePos - input;
        
        // 为前缀分配内存并复制前缀部分
        *labelType = (char*)malloc(labelLength + 1);  // +1 for null terminator
        strncpy(*labelType, input, labelLength);
        (*labelType)[labelLength] = '\0';  // 确保以 null 结尾
        
        // 将剩余部分作为 funcName
        *funcName = strdup(underscorePos + 1);  // 复制下划线之后的部分
    } else {
        // 如果没有找到下划线，则 labelType 为 NULL，整个输入就是 funcName
        *labelType = "";
        *funcName = strdup(input);  // 复制整个字符串
    }
}

// 根据中间代码生成RISC-V汇编代码
void generateASM(AsmContainer *asmContainer) {
    TACList* temp = tacHead;
    while (temp) {
        char* op = temp->tac->op;
        char* arg1 = temp->tac->arg1;
        char* arg2 = temp->tac->arg2;
        char* res = temp->tac->res;

        int binaryOp = (arg1 != NULL && *arg1 != '\0') && (arg2 != NULL && *arg2 != '\0');
        int unaryOp = (arg1 != NULL && *arg1 != '\0') ^ (arg2 != NULL && *arg2 != '\0');

        int irIndex = temp->tac->index;
        // printf("IR%d: %s %s, %s, %s\n", irIndex, op, arg1, arg2, res);
        if (strcmp(op, "call") == 0) {
            // 分析函数名
            char* funcName = arg1;
            int funcIndex = mapStackInfo(funcName);
            // printf("Calling function %s\n", funcName);
            int paramNum = findSymbol(funcName)->paramNum;

            for (int argNum = 0; argNum < paramNum; argNum++) {
                char* actualArg = findSymbol(funcName)->params[argNum]->id;
                AddressDescriptor ad = addressDescriptors[mapAddrDesc(actualArg)];
                if (ad.currentAddresses == NULL || ad.currentAddresses->size == 0) {
                    assert("Actual argument does not have current address");
                } else {
                    char* regLoc = NULL;
                    char* memLoc = NULL;
                    for (int i = 0; i < ad.currentAddresses->size; i++) {
                        char* addr = ad.currentAddresses->elements[i];
                        if (*addr == 'x') {
                            // register has higher priority
                            regLoc = strdup(addr);
                            break;
                        } else {
                            memLoc = strdup(addr);
                        }
                    }

                    if (regLoc != NULL) {
                        if (argNum < 4) {
                            char buffer[100];
                            snprintf(buffer, sizeof(buffer), "mv a%d, %s", argNum, regLoc);
                            newAsm(asmContainer, buffer);
                        } else {
                            char buffer[100];
                            snprintf(buffer, sizeof(buffer), "sw %s, %d(sp)", regLoc, 4 * argNum);
                            newAsm(asmContainer, buffer);
                        }
                        free(regLoc);
                    } else {
                        if (argNum < 4) {
                            char buffer[100];
                            snprintf(buffer, sizeof(buffer), "lw a%d, %s", argNum, memLoc);
                            newAsm(asmContainer, buffer);
                            newAsm(asmContainer, "nop");
                            newAsm(asmContainer, "nop");
                        } else {
                            char buffer[100];
                            snprintf(buffer, sizeof(buffer), "lw a1, %s", memLoc);
                            newAsm(asmContainer, buffer);
                            newAsm(asmContainer, "nop");
                            newAsm(asmContainer, "nop");
                            snprintf(buffer, sizeof(buffer), "sw a1, %d(sp)", 4 * argNum);
                            newAsm(asmContainer, buffer);
                        }
                        free(memLoc);
                    }
                }
            }

            for (int i = 0; i < indexAddrDesc; i++) {
                char* key = addrDescPairs[i];
                AddressDescriptor ad = addressDescriptors[i];
                char* boundMemAddress = ad.boundMemAddress;
                Set* currentAddresses = ad.currentAddresses;
                if (boundMemAddress != NULL && !setHas(currentAddresses, boundMemAddress)) {
                    // need to write this back to its bound memory location
                    if (currentAddresses->size > 0) {
                        for (int j = 0; j < currentAddresses->size; j++) {
                            char* addr = currentAddresses->elements[j];
                            if (*addr == 'x') {
                                char buffer[100];
                                snprintf(buffer, sizeof(buffer), "sw %s, %s", addr, boundMemAddress);
                                newAsm(asmContainer, buffer);
                                break;
                            }
                        }
                    } else {
                        assert("Attempted to store a ghost variable");
                    }
                }
            }

            char buffer[100];
            snprintf(buffer, sizeof(buffer), "jal %s", arg1);
            newAsm(asmContainer, buffer);
            newAsm(asmContainer, "nop");

            // 清除临时变量
            for (int i = 0; i < indexAddrDesc; i++) {
                char* key = addrDescPairs[i];
                AddressDescriptor ad = addressDescriptors[i];
                for (int j = 0; j < ad.currentAddresses->size; j++) {
                    char* addr = ad.currentAddresses->elements[j];
                    if (*addr == 'x') {
                        setDelete(ad.currentAddresses, addr);
                        RegisterDescriptor rd = registerDescriptors[mapRegDesc(addr)];
                        if (rd.variables != NULL) {
                            setDelete(rd.variables, key);
                        }
                    }
                }
            }

            if (res != NULL && *res != '\0') {
                char* regX;
                char** regs = getRegs(temp->tac, irIndex, asmContainer);
                regX = regs[0];
                sprintf(buffer, "mv %s, a0", regX);
                newAsm(asmContainer, buffer);
                manageResDescriptors(regX, res, asmContainer);
                free(regX);
            }
        } else if (binaryOp) {
            if (strcmp(op, "=[]") == 0) {
                char* regY, *regZ;
                char** regs = getRegs(temp->tac, irIndex, asmContainer);
                regY = regs[0];
                regZ = regs[1];
                char buffer[100];
                sprintf(buffer, "move a1, %s", regY);
                newAsm(asmContainer, buffer);
                newAsm(asmContainer, "sll a1, a1, 2");
                int index = mapAddrDesc(arg1);
                char* baseAddr = addressDescriptors[index].boundMemAddress;
                char buffer2[100];
                snprintf(buffer, sizeof(buffer2), "sw %s, %s(a1)", regZ, baseAddr);
                newAsm(asmContainer, buffer2);
                free(regY);
                free(regZ);
            } else if (strcmp(op, "[]=") == 0) {
                char* regZ, *regX;
                char buffer[100];
                char** regs = getRegs(temp->tac, irIndex, asmContainer);
                regZ = regs[0];
                regX = regs[1];
                newAsm(asmContainer, "move $v1, regZ");
                newAsm(asmContainer, "sll $v1, $v1, 2");
                int index = mapAddrDesc(arg1);
                char* baseAddr = addressDescriptors[index].boundMemAddress;
                snprintf(buffer, sizeof(buffer), "lw %s, %s($v1)", regX, baseAddr);
                newAsm(asmContainer, buffer);
                newAsm(asmContainer, "nop");
                newAsm(asmContainer, "nop");
                manageResDescriptors(regX, res, asmContainer);
                free(regZ);
                free(regX);
            } else if (strcmp(op, "=$") == 0) {
                char* regY, *regZ;
                char buffer[100];
                char** regs = getRegs(temp->tac, irIndex, asmContainer);
                regs[0] = regY;
                regs[1] = regZ;
                snprintf(buffer, sizeof(buffer), "sw %s, 0(%s)", regZ, regY);
                newAsm(asmContainer, buffer);
                free(regY);
                free(regZ);
            } else if (strcmp(op, "$=") == 0) {
                char* regY;
                char** regs = getRegs(temp->tac, irIndex, asmContainer);
                char buffer[100];
                regY = regs[0];
                // Add res to the register descriptor for regY
                int index = mapRegDesc(regY);
                if (registerDescriptors[index].variables != NULL) {
                    setAdd(registerDescriptors[index].variables, res);
                }

                // Change the address descriptor for res so that its only location is regY
                int index2 = mapAddrDesc(res);
                if (addressDescriptors[index2].currentAddresses->size != 0) {
                    setClear(addressDescriptors[index2].currentAddresses);
                    setAdd(addressDescriptors[index2].currentAddresses, regY);
                } else {
                    // temporary variable
                    addressDescriptors[indexAddrDesc].boundMemAddress = NULL;
                    addressDescriptors[indexAddrDesc].currentAddresses = createSet();
                    setAdd(addressDescriptors[indexAddrDesc].currentAddresses, regY);
                    addrDescPairs[indexAddrDesc] = res;
                    indexAddrDesc++;
                }
                free(regY);
            } else if (strcmp(op, "alloc_global") == 0) {
                // printf("Warning: alloc_global is not implemented.\n");
            } else if (strcmp(op, "alloc") == 0) {
                char* regX;
                char** regs = getRegs(temp->tac, irIndex, asmContainer);
                regX = regs[0];
                char buffer[100];
                
                // 从 arg1 解析出变量类型大小
                int size = atoi(arg1);  // 获取变量大小，单位字节
                int numWords = (size + WORD_LENGTH_BYTE - 1) / WORD_LENGTH_BYTE;  // 计算需要的字数
                
                // 计算栈空间偏移量
                int offset = WORD_LENGTH_BYTE * 1;
                
                // 生成 RISC-V 汇编代码：调整栈指针并为局部变量分配内存
                snprintf(buffer, sizeof(buffer), "addi %s, sp, %d", regX, offset);
                
                // 将生成的汇编代码存储到适当的位置
                newAsm(asmContainer, buffer);
            } else {
                char* regY, *regZ, *regX;
                char** regs = getRegs(temp->tac, irIndex, asmContainer);
                regY = regs[0];
                regZ = regs[1];
                regX = regs[2];
                if (strcmp(op, "or") == 0 || strcmp(op, "and") == 0 || strcmp(op, "<") == 0 ||
                    strcmp(op, "+") == 0 || strcmp(op, "-") == 0 || strcmp(op, "&") == 0 ||
                    strcmp(op, "|") == 0 || strcmp(op, "^") == 0 || strcmp(op, "<<") == 0 ||
                    strcmp(op, ">>") == 0 || strcmp(op, "==") == 0 || strcmp(op, "!=") == 0 ||
                    strcmp(op, ">") == 0 || strcmp(op, ">=") == 0 || strcmp(op, "<=") == 0 ||
                    strcmp(op, "*") == 0 || strcmp(op, "/") == 0 || strcmp(op, "%%") == 0) {
                    char buffer[100];
                    if (strcmp(op, "|") == 0 || strcmp(op, "or") == 0) {
                        snprintf(buffer, sizeof(buffer), "or %s, %s, %s", regX, regY, regZ);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, "&") == 0 || strcmp(op, "and") == 0) {
                        snprintf(buffer, sizeof(buffer), "and %s, %s, %s", regX, regY, regZ);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, "^") == 0) {
                        snprintf(buffer, sizeof(buffer), "xor %s, %s, %s", regX, regY, regZ);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, "+") == 0) {
                        snprintf(buffer, sizeof(buffer), "add %s, %s, %s", regX, regY, regZ);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, "-") == 0) {
                        snprintf(buffer, sizeof(buffer), "sub %s, %s, %s", regX, regY, regZ);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, "<<") == 0) {
                        snprintf(buffer, sizeof(buffer), "sllv %s, %s, %s", regX, regY, regZ);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, ">>") == 0) {
                        snprintf(buffer, sizeof(buffer), "srlv %s, %s, %s", regX, regY, regZ);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, "==") == 0) {
                        snprintf(buffer, sizeof(buffer), "sub %s, %s, %s", regX, regY, regZ);
                        newAsm(asmContainer, buffer);
                        snprintf(buffer, sizeof(buffer), "sltu %s, $zero, %s", regX, regX);
                        newAsm(asmContainer, buffer);
                        snprintf(buffer, sizeof(buffer), "xori %s, %s, 1", regX, regX);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, "!=") == 0) {
                        snprintf(buffer, sizeof(buffer), "sub %s, %s, %s", regX, regY, regZ);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, "<") == 0) {
                        snprintf(buffer, sizeof(buffer), "slt %s, %s, %s", regX, regY, regZ);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, ">") == 0) {
                        // if (regY != NULL) {printf("Error: regX is NULL in > operation.\n");}
                        snprintf(buffer, sizeof(buffer), "slt %s, %s, %s", regX, regZ, regY);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, ">=") == 0) {
                        snprintf(buffer, sizeof(buffer), "slt %s, %s, %s", regX, regY, regZ);
                        newAsm(asmContainer, buffer);
                        snprintf(buffer, sizeof(buffer), "xori %s, %s, 1", regX, regX);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, "<=") == 0) {
                        snprintf(buffer, sizeof(buffer), "slt %s, %s, %s", regX, regZ, regY);
                        newAsm(asmContainer, buffer);
                        snprintf(buffer, sizeof(buffer), "xori %s, %s, 1", regX, regX);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, "*") == 0) {
                        snprintf(buffer, sizeof(buffer), "mult %s, %s", regY, regZ);
                        newAsm(asmContainer, buffer);
                        snprintf(buffer, sizeof(buffer), "mflo %s", regX);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, "/") == 0) {
                        snprintf(buffer, sizeof(buffer), "div %s, %s", regY, regZ);
                        newAsm(asmContainer, buffer);
                        snprintf(buffer, sizeof(buffer), "mflo %s", regX);
                        newAsm(asmContainer, buffer);
                    } else if (strcmp(op, "%%") == 0) {
                        snprintf(buffer, sizeof(buffer), "div %s, %s", regY, regZ);
                        newAsm(asmContainer, buffer);
                        snprintf(buffer, sizeof(buffer), "mfhi %s", regX);
                        newAsm(asmContainer, buffer);
                    }
                    manageResDescriptors(regX, res, asmContainer);
                    free(regY);
                    free(regZ);
                    free(regX);
                }
            }
        } else if (unaryOp) {
            if (strcmp(op, "ifFalseGoto") == 0) {
                char* regY;
                char** regs = getRegs(temp->tac, irIndex, asmContainer);
                regY = regs[0];
                char buffer[100];
                deallocateProcMemory(asmContainer);
                snprintf(buffer, sizeof(buffer), "beq %s, zero, %s", regY, res);
                newAsm(asmContainer, buffer);
                newAsm(asmContainer, "nop"); // delay-slot
                free(regY);
            } else if (strcmp(op, "ifGoto") == 0) {
                char* regY;
                char** regs = getRegs(temp->tac, irIndex, asmContainer);
                regY = regs[0];
                char buffer[100];
                deallocateProcMemory(asmContainer);
                snprintf(buffer, sizeof(buffer), "bne %s, zero, %s", regY, res);
                newAsm(asmContainer, buffer);
                newAsm(asmContainer, "nop"); // delay-slot
                free(regY);
            } else if (strcmp(op, "=") == 0) {
                // printf("111");
                char* regX;
                char** regs = getRegs(temp->tac, irIndex, asmContainer);
                regX = regs[0];
                char buffer[100];
                int immediateNum = atoi(arg1);
                if (immediateNum <= 32767 && immediateNum >= -32768) {
                    snprintf(buffer, sizeof(buffer), "addi %s, zero, %d", regX, immediateNum);
                    newAsm(asmContainer, buffer);
                } else {
                    int lowerHalf = immediateNum & 0x0000ffff;
                    int higherHalf = immediateNum >> 16;
                    snprintf(buffer, sizeof(buffer), "lui %s, %d", regX, higherHalf);
                    newAsm(asmContainer, buffer);
                    snprintf(buffer, sizeof(buffer), "ori %s, %s, %d", regX, regX, lowerHalf);
                    newAsm(asmContainer, buffer);
                }
                manageResDescriptors(regX, res, asmContainer);
                free(regX);
            } else if (strcmp(op, "label") == 0) {
                char buffer[100];
                // parse the label to identify type
                char* labelType = NULL; // func_{funcName} or end_func
                char* funcName = NULL; // funcName
                removePrefix(arg1, &labelType, &funcName);
                int index = mapStackInfo(funcName);
                // printf("labeltype: %s, funcName: %s, index: %d\n", labelType, funcName, index);
                if (strcmp(labelType, "func") == 0) {
                    StackFrameInfo currFrameInfo = stackFrameInfos[index];
                    snprintf(buffer, sizeof(buffer), "%s:", funcName);
                    newAsm(asmContainer, buffer);
                    snprintf(buffer, sizeof(buffer), "addi sp, sp, -%d", 4 * currFrameInfo.wordSize);
                    newAsm(asmContainer, buffer);

                    if (!currFrameInfo.isLeaf) {
                        newAsm(asmContainer, "sw ra, -4(sp)");
                    }

                    for (int index = 0; index < currFrameInfo.numGPRs2Save; index++) {
                        snprintf(buffer, sizeof(buffer), "sw s%d, %d(sp)", index, 4 * (currFrameInfo.wordSize - currFrameInfo.numGPRs2Save + index));
                        newAsm(asmContainer, buffer);
                    }

                    allocateProcMemory(asmContainer, index, funcName);
                } else if (strcmp(labelType, "end") == 0) {
                    deallocateProcMemory(asmContainer);
                } else {
                    char buffer[100];
                    snprintf(buffer, sizeof(buffer), "%s:", arg1);
                    newAsm(asmContainer, buffer);
                }
            } else if (strcmp(op, "param") == 0) { // 还没写
                // char* regX;
                // char** regs = getRegs(temp->tac, irIndex, asmContainer);
                // regX = regs[0];
                // char buffer[100];
                // int index = mapRegDesc(regX);
                // if (regX != NULL && !setHas(registerDescriptors[index].variables, arg1)) {
                //     loadVar(arg1, regX, asmContainer);
                // }
                // manageResDescriptors(regX, res, asmContainer);
                // free(regX);
            } else if (strcmp(op, "~") == 0 || strcmp(op, "-") == 0 || strcmp(op, "+") == 0) {
                char* regY, *regX;
                char** regs = getRegs(temp->tac, irIndex, asmContainer);
                regY = regs[0];
                regX = regs[1];
                char buffer[100];
                int index = mapRegDesc(regY);
                if (regY != NULL && !setHas(registerDescriptors[index].variables, arg1)) {
                    loadVar(arg1, regY, asmContainer);
                }

                if (strcmp(op, "NOT_OP") == 0) {
                    snprintf(buffer, sizeof(buffer), "xor %s, $zero, %s", regX, regY);
                    newAsm(asmContainer, buffer);
                } else if (strcmp(op, "MINUS") == 0) {
                    snprintf(buffer, sizeof(buffer), "sub %s, $zero, %s", regX, regY);
                    newAsm(asmContainer, buffer);
                } else if (strcmp(op, "PLUS") == 0) {
                    snprintf(buffer, sizeof(buffer), "move %s, %s", regX, regY);
                    newAsm(asmContainer, buffer);
                } else if (strcmp(op, "BITINV_OP") == 0) {
                    snprintf(buffer, sizeof(buffer), "nor %s, %s, %s", regX, regY, regY);
                    newAsm(asmContainer, buffer);
                }

                manageResDescriptors(regX, res, asmContainer);
                free(regY);
                free(regX);
            }       
        } else {
            if (strcmp(op, "return") == 0) {  
                if (res != NULL) { // 存疑
                    int index2 = mapAddrDesc(res);
                    addressDescriptors[index2].boundMemAddress = NULL;
                    if (addressDescriptors[index2].currentAddresses == NULL || addressDescriptors[index2].currentAddresses->size == 0) {
                        assert("Return value does not have current address");
                    } else {
                        char* regLoc = NULL;
                        char* memLoc = NULL;
                        for (int i = 0; i < addressDescriptors[index2].currentAddresses->size; i++) {
                            char* addr = addressDescriptors[index2].currentAddresses->elements[i];
                            if (addr[0] == 'x') {
                                // register has higher priority
                                regLoc = strdup(addr);
                                break;
                            } else {
                                memLoc = strdup(addr);
                            }
                        }

                        char buffer[100];
                        if (regLoc != NULL) {
                            snprintf(buffer, sizeof(buffer), "mv a0, %s", regLoc);
                            newAsm(asmContainer, buffer);
                            free(regLoc);
                        } else {
                            snprintf(buffer, sizeof(buffer), "lw a0, %s", memLoc);
                            newAsm(asmContainer, buffer);
                            newAsm(asmContainer, "nop");
                            newAsm(asmContainer, "nop");
                            free(memLoc);
                        }
                    }

                    deallocateProcMemory(asmContainer);

                    char buffer[100];
                    // assert(currentFrameInfo != NULL, "Undefined frame info");
                    for (int index = 0; index < stackFrameInfos[indexStackFrameInfos].numGPRs2Save; index++) {
                        snprintf(buffer, sizeof(buffer), "lw s%d, %d(sp)", index, 4 * (stackFrameInfos[indexStackFrameInfos].wordSize - stackFrameInfos[indexStackFrameInfos].numGPRs2Save + index));
                        newAsm(asmContainer, buffer);
                        newAsm(asmContainer, "nop");
                        newAsm(asmContainer, "nop");
                    }

                    if (!stackFrameInfos[indexStackFrameInfos].isLeaf) {
                        newAsm(asmContainer, "lw ra, -4(sp)");
                        newAsm(asmContainer, "nop");
                        newAsm(asmContainer, "nop");
                    }

                    snprintf(buffer, sizeof(buffer), "addi sp, sp, %d", 4 * stackFrameInfos[indexStackFrameInfos].wordSize);
                    newAsm(asmContainer, buffer);
                    newAsm(asmContainer, "jr ra");
                    newAsm(asmContainer, "nop");
                } else {
                    for (int index = 0; index < stackFrameInfos[indexStackFrameInfos].numGPRs2Save; index++) {
                        char buffer[100];
                        snprintf(buffer, sizeof(buffer), "lw s%d, %d(sp)", index, 4 * (stackFrameInfos[indexStackFrameInfos].wordSize - stackFrameInfos[indexStackFrameInfos].numGPRs2Save + index));
                        newAsm(asmContainer, buffer);
                        newAsm(asmContainer, "nop");
                        newAsm(asmContainer, "nop");
                    }

                    if (!stackFrameInfos[indexStackFrameInfos].isLeaf) {
                        char buffer[100];
                        snprintf(buffer, sizeof(buffer), "lw ra, %d(sp)", 4 * (stackFrameInfos[indexStackFrameInfos].wordSize - 1));
                        newAsm(asmContainer, "nop");
                        newAsm(asmContainer, "nop");
                    }
                    char buffer[100];
                    snprintf(buffer, sizeof(buffer), "addi sp, sp, %d", 4 * stackFrameInfos[indexStackFrameInfos].wordSize);
                    newAsm(asmContainer, buffer);
                    newAsm(asmContainer, "jr ra");
                    newAsm(asmContainer, "nop");
                }

            } else if (strcmp(op, "goto") == 0) {
                deallocateProcMemory(asmContainer);
                char buffer[100];
                snprintf(buffer, sizeof(buffer), "jal %s", res);
                newAsm(asmContainer, buffer);
                newAsm(asmContainer, "nop"); // delay-slot
            }
        }

        if (strcmp(op, "label") != 0 && strcmp(op, "goto") != 0 && strcmp(op, "ifFalseGoto") != 0) {
            deallocateProcMemory(asmContainer);
        }

        // printf("111");
        temp = temp->next;
    }
}

/*+++++++++++++++++++++++++++++++++++++++++++*/

// 打印所有汇编代码
void printAsm(AsmContainer* container) {
    for (size_t i = 0; i < container->size; i++) {
        printf("%s\n", container->asmLines[i]);
    }
}

// int main() {
//     // 初始化 ASM 存储容器
//     AsmContainer asmContainer;
//     initAsmContainer(&asmContainer);
//     //newAsm(&asmContainer, ".data");
//     //newAsm(&asmContainer, "var1: .word 100");
//     //newAsm(&asmContainer, "add x1, x2, x3");
//     //char* asmCode = toAssembly(&asmContainer);
//     //initAsm();
//
//     // 假设我们已有的寄存器和地址描述符数据
//     // 为寄存器的 variables 数组分配内存
//     //for (int i = 0; i < MAX_REGISTERS; i++) {
//     //    registers[i].variables = (char**)malloc(10 * sizeof(char*));  // 为每个寄存器分配一个指针数组
//     //    for (int j = 0; j < 10; j++) {
//     //        registers[i].variables[j] = (char*)malloc(10 * sizeof(char));  // 为每个指针分配内存
//     //    }
//     //    registers[i].numVariables = 0;  // 初始化变量数量
//     //}
//     //strcpy_s(registers[0].variables[0], 256, "x0");
//     //registers[0].numVariables = 1;

//     //addressDescriptors[0].boundMemAddress = "0x1000";
//     //addressDescriptors[0].numAddresses = 0;

//     // 加载变量到寄存器
//     //loadVar("var1", "x0", &asmContainer);

//     // 打印生成的汇编代码
//     printSymbolTable(scopeStack[0]);
//     // printAsm(&asmContainer);

//     // 清理资源
//     //for (int i = 0; i < MAX_REGISTERS; i++) {
//     //    for (int j = 0; j < 10; j++) {
//     //        free(registers[i].variables[j]);  // 释放每个变量的内存
//     //    }
//     //    free(registers[i].variables);  // 释放指向指针数组的内存
//     //}
//     //freeAsm();
//     freeAsmContainer(&asmContainer);

//     return 0;
// }