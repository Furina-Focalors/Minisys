## 四元式约定
|op|arg1|arg2|res|备注
|-|-|-|-|-
|LE_OP GE_OP EQ_OP NE_OP LT_OP GT_OP RIGHT_OP LEFT_OP ADD_OP SUB_OP MUL_OP DIV_OP MOD_OP AND_OP OR_OP BITAND_OP BITXOR_OP BITOR_OP|op1|op2|res|res = op1 OPERATOR op2
|NOT_OP BITINV_OP ADD_OP SUB_OP|op||res|res = OPERATOR op
|ASSIGN_OP|op||res|res = op
|\$=|val||addr|$addr = val; 在内存地址addr处写val
|=\$|addr||res|res = $addr; 从内存addr处读取值，赋给res
|ifGoto|logical_var||label|if (logical_var) goto label;
|ifFalseGoto|logical_var||label|if (!logical_var) goto label;
|goto|||label|goto label;
|[]=|index|val|arr|arr[index] = val;
|=[]|arr|index|res|res = arr[index];
|param|var|||仅在函数调用时，将变量var作为参数入栈
|call|func||ret|调用函数func，读取栈顶变量作为参数传入，并将返回值存入ret（如果ret为空表示没有返回值）
|return|val||label|将val作为返回值返回给label处，如果val为空，不返回任何值。

## 中间代码和高级语言的转化关系样例
|C code|Intermediate Code(TAC form)|IC(Quaternary form)
|-|-|-
|arr[index] = val;|arr[index] = val;|([]=, index, val, arr);
|var = arr[index];|t1 = arr[index];<br>var = t1;|(=[],arr,index,t1);<br>(=,t1, ,var);
|y = a + b;|t1 = a + b;<br> y = t1;|(+,a,b,t1);<br>(=,t1, ,y);
|y = x++;|y = x;<br> x = x + 1;|(=,x, ,y);<br> (+,x,1,x);
|y = ++x;|x = x + 1;<br> y = x;|(+,x,1,x);<br> (=,x, ,y)
|y = a + b - c;|t1 = a + b;<br> t2 = t1 - c;<br> y = t2;|(+,a,b,t1);<br>(-,t1,c,t2);<br>(=,t2, ,y);
|y = a \* b;|t1 = a \* b; <br>y = t1;|(\*,a,b,t1);<br>(=,t1, ,y);
|func(a, b, c);|param a; <br>param b; <br>param c; <br>call func;|(param,a, , );<br>(param,b, , );<br>(param,c, , );<br>(call,func, , );
|if (x == y) {a = b;...}|100: t1 = x==y;<br>101: if (t1) goto 0;<br>102: goto 0;<br>103: a = b;|(==,x,y,t1);<br>(ifGoto,t1, ,0);<br>(goto, , ,0);<br>(=,b, ,a);
|while (x == y) {a = b;...}|100: t1 = x==y;<br>101: if (t1) goto 0;<br>102: goto 0;<br>103: a = b;<br>...<br>n: goto 100;|(==,x,y,t1);<br>(ifGoto,t1, ,0);<br>(goto, , ,0);<br>(=,b, ,a);<br>...<br>(goto, , ,100);
|for (i=0;i<2;++i) {a = b;...}|100: i = 0;<br>101: t1 = i<2<br>102: if (t1) goto 0;<br>103: goto 0;<br>104: a = b;<br>...<br>n: i = i + 1;<br>n+1: goto 101;|(=,0, ,i);<br>(<,i,2,t1);<br>(ifGoto,t1, ,0);<br>(goto, , ,0);<br>(=,b, ,a);<br>...<br>(+,i,1,i);<br>(goto, , ,101);


注：乘、除、求模三种操作，由于我们的指令集不支持相应指令，会在**生成目标代码时**转化为其他指令的组合
