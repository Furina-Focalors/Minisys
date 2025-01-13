#ifndef ASM_H
#define ASM_H

#include <stdbool.h> // For 'bool', 'true', 'false'
#include "tac.h" // For 'TAC'

/* Set start */
typedef struct Set {
    char** elements;
    int size;
    int capacity;
} Set;

Set* createSet();
void setAdd(Set* set, char* element);
int setHas(Set* set, char* element);
void setClear(Set* set);
void setDelete(Set* set, char* element);
void setFree(Set* set);

/* Set end */

// 定义常量
#define WORD_LENGTH_BIT 32
#define WORD_LENGTH_BYTE 4
#define RAM_SIZE 65536 // bytes
#define ROM_SIZE 65536 // bytes
#define IO_MAX_ADDR 0xffffffff


// 寄存器定义（根据提供的寄存器列表）
/*
    通用寄存器：
    x0 (zero)：总是为 0。
    x1 (ra)：返回地址。
    x2 (sp)：栈指针。
    x3 (gp)：全局指针。
    x4 (tp)：线程指针。
    x5-x7 (t0-t2)：临时寄存器。
    x8 (s0/fp)：保存寄存器/帧指针。
    x9 (s1)：保存寄存器。
    x10-x11 (a0-a1)：函数参数/返回值。
    x12-x17 (a2-a7)：函数参数。
    x18-x27 (s2-s11)：保存寄存器。
    x28-x31 (t3-t6)：临时寄存器。
 */
// #define REG_ZERO "x0"
// #define REG_RA "x1"
// #define REG_SP "x2"
// #define REG_GP "x3"
// #define REG_TP "x4"
// #define REG_T0 "x5"
// #define REG_T1 "x6"
// #define REG_T2 "x7"
// #define REG_S0 "x8"
// #define REG_S1 "x9"
// #define REG_A0 "x10"
// #define REG_A1 "x11"
// #define REG_A2 "x12"
// #define REG_A3 "x13"
// #define REG_A4 "x14"
// #define REG_A5 "x15"
// #define REG_A6 "x16"
// #define REG_A7 "x17"
// #define REG_S2 "x18"
// #define REG_S3 "x19"
// #define REG_S4 "x20"
// #define REG_S5 "x21"
// #define REG_S6 "x22"
// #define REG_S7 "x23"
// #define REG_S8 "x24"
// #define REG_S9 "x25"
// #define REG_S10 "x26"
// #define REG_S11 "x27"
// #define REG_T3 "x28"
// #define REG_T4 "x29"
// #define REG_T5 "x30"
// #define REG_T6 "x31"

// 寄存器数组
// extern const char* all_regs[];
// extern const char* useful_regs[];
// extern const char* saved_regs[];

// 寄存器描述符：描述寄存器的可用性和使用的变量
typedef struct {
    bool usable;          // 寄存器是否可用
    Set* variables;       // 当前寄存器使用的变量数组
} RegisterDescriptor;

// 地址描述符：描述内存地址以及绑定的内存地址
typedef struct {
    Set* currentAddresses;  // 变量当前存储的所有位置，可以是寄存器也可以是内存地址
    char* boundMemAddress;  // 绑定的内存地址（临时变量没有内存地址），例如0x10000000
} AddressDescriptor;

// 栈帧信息：描述函数的栈帧大小和结构
typedef struct {
    bool isLeaf;            // 是否为叶函数（不调用其他函数的函数）
    int wordSize;           // 每个数据的字节大小（例如 4 字节或 8 字节）
    int outgoingSlots;      // 出栈参数所占的栈空间
    int localData;          // 局部数据的栈空间
    int numGPRs2Save;       // 需要保存的通用寄存器数量
    int numReturnAdd;       // 返回地址的数量
} StackFrameInfo;

// 汇编代码容器
typedef struct {
    char** asmLines;  // 存储汇编代码的字符串数组
    unsigned int size;      // 当前数组中存储的行数
    unsigned int capacity;  // 数组的容量
} AsmContainer;

// 寄存器描述符的集合
#define MAX_REGISTERS 15
#define MAX_VARIABLES 10
RegisterDescriptor registerDescriptors[MAX_REGISTERS];

// 地址描述符的集合
#define MAX_VARS 128
char* addrDescPairs[MAX_VARS]; // 变量名和addressDescriptors里下标的映射
AddressDescriptor addressDescriptors[MAX_VARS];

// 桢栈信息定义集合
#define MAX_FUNCTIONS 10  // 假设最多有 10 个函数
char* funcPairs[MAX_FUNCTIONS]; // 函数名和stackFrameInfos里下标的映射
StackFrameInfo stackFrameInfos[MAX_FUNCTIONS]; // stackFrameInfos[0] 表示0号函数的栈帧信息

#define INITIAL_ASM_SIZE 100  // 初始数组大小，可以根据需求修改
#define MAX_LINE_LENGTH 256

void init_registers();
void free_registers();
void release_register(int reg);
void initAsm();
void freeAsm();
void initAsmContainer(AsmContainer* container); // 初始化 AsmContainer
void freeAsmContainer(AsmContainer* container); // 释放 AsmContainer 内存
void loadVar(const char* varId, const char* registerName, AsmContainer* asmContainer);
void storeVar(const char* varId, const char* registerName, AsmContainer* asmContainer);
char* toAssembly(AsmContainer* container); // 生成汇编代码的函数
void initializeGlobalVars(AsmContainer* container); // 生成声明全局变量代码
void newAsm(AsmContainer* container, const char* line); // 添加一行汇编代码
void calcFrameInfo(AsmContainer* container); // 计算函数的栈帧信息
void generateASM(AsmContainer *container); // 根据中间代码生成RISC-V汇编代码
void allocateProcMemory(AsmContainer* asmContainer, int index, char* funcName); // 为函数分配内存空间
void allocateGlobalMemory(AsmContainer* asmContainer); // 为全局变量分配内存空间
void deallocateProcMemory(AsmContainer* asmContainer); // 释放函数的内存空间
void manageResDescriptors(char* regX, char* res, AsmContainer* asmContainer); // 管理寄存器描述符

// 寄存器分配相关函数
char** getRegs(TAC* ir, int irIndex, AsmContainer* asmContainer); // 为一条四元式获取每个变量可用的寄存器
bool checkRegisterForVariable(const char* regName, const char* varId); // 辅助函数：检查寄存器中是否有指定变量
char* allocateReg(int irIndex, const char* thisArg, const char* otherArg, 
                 const char* res, AsmContainer* asmContainer);

// 调试相关函数
void printAsm(AsmContainer* container);

#endif // ASM_H
