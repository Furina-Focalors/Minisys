# Mini C语法特性
## 数据类型
- 支持int, short, char三种数据类型
- 支持十六进制与十进制表达
- 标识符支持字母、数字和下划线，遵循C语言中的命名规则

## 运算
下表为Mini C支持的运算符及其优先级：

<table>
  <tr>
    <th>优先级</th>
    <th>运算符</th>
    <th>类型</th>
    <th>结合性</th>
    <th>含义</th>
  </tr>
  <tr>
    <td rowspan="2">1</td>
    <td>[]</td>
    <td>单目</td>
    <td>左结合</td>
    <td>数组下标</td>
  </tr>
  <tr>
    <td>()</td>
    <td>单目</td>
    <td>左结合</td>
    <td>括号</td>
  </tr>
  <tr>
    <td rowspan="7">2</td>
    <td>-</td>
    <td>单目</td>
    <td>右结合</td>
    <td>负号</td>
  </tr>
  <tr>
    <td>+</td>
    <td>单目</td>
    <td>右结合</td>
    <td>正号</td>
  </tr>
  <tr>
    <td>++</td>
    <td>单目</td>
    <td>右结合</td>
    <td>自增</td>
  </tr>
  <tr>
    <td>--</td>
    <td>单目</td>
    <td>右结合</td>
    <td>自减</td>
  </tr>
  <tr>
    <td>!</td>
    <td>单目</td>
    <td>右结合</td>
    <td>取反</td>
  </tr>
  <tr>
    <td>~</td>
    <td>单目</td>
    <td>右结合</td>
    <td>按位取反</td>
  </tr>
  <tr>
    <td>$</td>
    <td>单目</td>
    <td>右结合</td>
    <td>地址操作</td>
  </tr>
  <tr>
    <td rowspan="3">3</td>
    <td>*</td>
    <td>双目</td>
    <td>左结合</td>
    <td>乘</td>
  </tr>
  <tr>
    <td>/</td>
    <td>双目</td>
    <td>左结合</td>
    <td>除</td>
  </tr>
  <tr>
    <td>%</td>
    <td>双目</td>
    <td>左结合</td>
    <td>求模</td>
  </tr>
  <tr>
    <td rowspan="2">4</td>
    <td>+</td>
    <td>双目</td>
    <td>左结合</td>
    <td>加</td>
  </tr>
  <tr>
    <td>-</td>
    <td>双目</td>
    <td>左结合</td>
    <td>减</td>
  </tr>
  <tr>
    <td rowspan="2">5</td>
    <td>&lt;&lt;</td>
    <td>双目</td>
    <td>左结合</td>
    <td>左移</td>
  </tr>
  <tr>
    <td>&gt;&gt;</td>
    <td>双目</td>
    <td>左结合</td>
    <td>右移</td>
  </tr>
  <tr>
    <td rowspan="4">6</td>
    <td>&gt;=</td>
    <td>双目</td>
    <td>左结合</td>
    <td>大于等于</td>
  </tr>
  <tr>
    <td>&lt;=</td>
    <td>双目</td>
    <td>左结合</td>
    <td>小于等于</td>
  </tr>
  <tr>
    <td>&gt;</td>
    <td>双目</td>
    <td>左结合</td>
    <td>大于</td>
  </tr>
  <tr>
    <td>&lt;</td>
    <td>双目</td>
    <td>左结合</td>
    <td>小于</td>
  </tr>
  <tr>
    <td rowspan="2">7</td>
    <td>==</td>
    <td>双目</td>
    <td>左结合</td>
    <td>等于</td>
  </tr>
  <tr>
    <td>!=</td>
    <td>双目</td>
    <td>左结合</td>
    <td>不等于</td>
  </tr>
  <tr>
    <td>8</td>
    <td>&</td>
    <td>双目</td>
    <td>左结合</td>
    <td>按位与</td>
  </tr>
  <tr>
    <td>9</td>
    <td>^</td>
    <td>双目</td>
    <td>左结合</td>
    <td>按位异或</td>
  </tr>
  <tr>
    <td>10</td>
    <td>|</td>
    <td>双目</td>
    <td>左结合</td>
    <td>按位或</td>
  </tr>
  <tr>
    <td>11</td>
    <td>&&</td>
    <td>双目</td>
    <td>左结合</td>
    <td>逻辑与</td>
  </tr>
  <tr>
    <td>12</td>
    <td>||</td>
    <td>双目</td>
    <td>左结合</td>
    <td>逻辑或</td>
  </tr>
  <tr>
    <td>13</td>
    <td>=</td>
    <td>双目</td>
    <td>右结合</td>
    <td>赋值</td>
  </tr>
</table>

## 语句
### 注释
目前仅支持`//`开头的注释语句

### 变量声明
目前只支持形如

```c
int a;
```

的声明方式，暂不支持形如`int a,b,c;`声明多个变量，以及形如`int a = 1013;`的声明时直接赋值的语句。请使用

```c
int a;
a = 1013;
```

### 函数声明
函数声明必须包含**返回值类型**、**函数名**和**参数列表**。参数列表可以为空，如果有多个参数，使用逗号`,`隔开。函数名的命名规则与变量名相同。以下是一个函数声明的例子：

```c
int sampleFunction(char MyChar, int MyInt);
```
和C语言相同，如果直接在函数头后跟上`{函数体}`，可以作为函数的定义。

### 表达式
可以使用上一节中支持的所有运算符组合成表达式。需要注意，`++、--、<<、>>、=`在构成表达式时，左边的项必须是一个**左值**。

### 判断语句
支持使用`if`语句进行条件判断，格式如下：

```c
if (condition1) statement;
if (condition2) {
  stmt1;
  stmt2;
  // ...
}
if (condition3) {
  // ...
} else {
  // ...
}
```

if语句支持嵌套使用。

### 循环语句
支持使用`while`和`for`语句执行循环，格式如下：

```c
while(condition1) stmt;
while(condition2) {
  stmt1;
  stmt2;
  // ...
}
```

```c
for(expr;expr;expr) stmt;
for(expr;expr;expr) {
  stmt1;
  stmt2;
  // ...
}
```

while和for语句均支持嵌套使用。在循环语句块内，支持使用`continue;`直接跳转至下一轮循环；支持使用`break;`语句直接跳出循环。

### 返回值
可以使用`return;`或`return expr;`语句实现函数返回值，返回值类型需与函数声明时的返回值类型。不允许对void类型的函数返回任何值，也不允许在返回值类型不为void的函数中使用`return;`。

### 数组
目前仅支持一维数组使用，形式为`ArrName[Index]`，其中ArrName是数组名，是一个标识符；Index是一个整型常量。

### 内存操作
可以使用`$expr`直接操作地址为expr的内存空间。


