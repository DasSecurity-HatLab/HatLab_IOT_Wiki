
> w0lfzhang@HatLab

[TOC]

## PowerPC 概述

> PowerPC（Performance Optimization With Enhanced RISC – Performance Computing，有时简称 PPC）是一种精简指令集（RISC）架构的中央处理器（CPU），其基本的设计源自 IBM（国际商用机器公司）的POWER（Performance Optimized With Enhanced RISC）。


PowerPC处理器有广泛的实现范围，包括从诸如 Power4 那样的高端服务器CPU 到嵌入式 CPU 市场（任天堂 Gamecube 使用了 PowerPC），在通信、工控、航天国防等要求高性能和高可靠性的领域得到广泛应用，是一颗“贵族的芯片”。

## PowerPC 汇编介绍

### 寄存器

PowerPC 的处理器有32个（32 位或 64 位）GPR（通用寄存器）以及诸如 PC（程序计数器，也称为 IAR/指令地址寄存器或 NIP/下一指令指针）、LR（链接寄存器）、CR（条件寄存器）等各种其它专用寄存器。有些 PowerPC CPU 还有 32 个 64 位 FPR（浮点寄存器）。

#### 通用寄存器的介绍以及用途

PPC 汇编通用寄存器范围从 r0 到 r31，各个寄存器的具体功能如下表：

|   寄存器名  |   寄存器功能   |
| ---- | ---- |
|   r0   |   在函数开始（function prologs）时使用。   |
|   r1   |   堆栈指针，相当于 IA32 架构中的esp寄存器，IDA pro 中把这个寄存器反汇编标识为 sp。   |
|   r2   |   内容表（toc）指针，IDA pro 中把这个寄存器反汇编标识为 rtoc。系统调用时，它包含系统调用号。   |
|   r3   |   作为调用函数的第一个参数和函数的返回值。   |
|   r4 - r10   |   函数或系统调用开始的参数。   |
|   r11   |   用在指针的调用和当作一些语言的环境指针。   |
|   r12   |   它用在异常处理和 glink（动态连接器）代码。   |
|   r13   |   保留作为系统线程 ID。   |
|   r14 - r31   |    作为本地变量，非易失性。   |


#### 专用寄存器的介绍以及用途

除了一些通用寄存器，在 PPC 中还存在一些比较特殊的专用寄存器：

|   寄存器名  |   寄存器功能   |
| ---- | ---- |
|   lr   |   链接寄存器，它用来存放函数调用的返回地址。   |
|   ctr   |   计数寄存器，它用来当作循环计数器，会随特定转移操作而递减。   |
|   xer   |   定点异常寄存器，存放整数运算操作的进位以及溢出信息。   |
|   msr   |   机器状态寄存器，用来配置微处理器的设定。   |
|   cr   |   条件寄存器，它分成8个4位字段，cr0-cr7，它反映了某个算法操作的结果并且提供条件分支的机制。


### 常见汇编指令操作码

#### 赋值语句



|	指令名	|	指令作用	|
|----|----|
|	li rA, imm	|	将立即数的值赋值给 rA 寄存器	|
|	lwz rA, d(rB)	|	将 `rB+d` 地址取值存储到 rA	|
|	lis rA, imm	|	将寄存器的值先左移 4 位，并赋值给 rA 寄存器	|
|	mr rA, rB	|	将 rB 寄存器的值赋值给 rA 寄存器	|


#### 存储指令

存储指令的作用使用第一个操作数的内容存储到第二个操作数的内容地址中。PPC 指令中一些常见的存储指令：

![](http://10.20.152.151/server/../Public/Uploads/2020-05-14/5ebca3ef79fc7.png)



- 如这里对 `stb rS, d(rA)` 存储指令的理解：[rA + d] = rS，即将 rS 寄存器的内容存储到 `rA + d` 表示的内存地址中。

#### 加载指令

加载指令与存储指令类似，只是将数据存储位置换了一个方向，即将第二个操作数的内容存储到第一个操作数的内容地址中。一些常见的加载指令：

![](http://10.20.152.151/server/../Public/Uploads/2020-05-14/5ebca49e90436.png)

- 如这里对 `lbz rD, d(rA)` 加载指令的理解：rD = [rA + d]，即将 `rA + d` 内存地址中的值存储到 rD 寄存器中。

#### 转移/跳转指令

PPC 的跳转指令主要分为以下几种：

```
b				无条件转移
bl				函数调用
blr				函数返回，跳转到 lr 寄存器存储的地址中
bctrl			jump to ctr 寄存器
```

- 特殊寄存器传送指令

![](http://10.20.152.151/server/../Public/Uploads/2020-05-14/5ebca7f698e82.png)

#### 其他指令

|	指令名	|	指令作用	|
|----|----|
|	mflr rA	|	Move From Link Register，将 lr 寄存器的值存储到 rA 寄存器中，一般用于函数开头	|
|	mtlr rA	|	与 mflr 指令相反，将 rA 寄存器的值存储到 lr 寄存器中，一般用于函数结尾的返回	|
|	...	|	...	|
|		|		|

### 函数调用

powerpc 函数调用跟 arm，mips 架构指令集有些类似。函数传参从 r3 寄存器开始，r3 - r8 寄存器依次存放需要传入的参数顺序。

当调用某个函数时，用到以下指令：

```
bl func			// 跳转并链接
```

该指令类似 mips 架构的 `jalr` 指令，会保存该指令下一条指令地址到 lr 寄存器中，然后 jump 到 func 函数。在 func 函数开头，会存储 lr 寄存器的值到 r0 寄存器中，接着会将 r0 寄存器的值保存到栈中。**这一系列的步骤就相当于保存调用者函数的返回地址到栈上。**

- 举个例子：

```
func:

stwu      r1, -0x20(r1)				// 定义 r1 栈寄存器
mflr      r0							 // 将 lr 寄存器的值存入 r0 寄存器
stw       r28, 0x10(r1)
stw       r29, 0x14(r1)
stw       r0, 0x24(r1)				 // 将 r0 寄存器的值存储到 r1+0x24 内存地址中
......
```
然后在函数返回时，会将 r0 从栈中取出，然后赋值给 lr，然后返回：

```
lwz       r0, 0x24(r1)				// 将返回地址 从 r1+0x24 的内存地址中取出，并赋值给 r0 寄存器
mtlr      r0							// 将 r0 寄存器的值赋值给 lr 寄存器
lwz       r28, 0x10(r1)
lwz       r29, 0x14(r1)
addi      r1, r1, 0x20
blr											// 跳转到 lr 寄存器存储的地址中，表示函数返回
```

所以在 ppc 的栈溢出利用过程中，我们需要覆盖保存 r0 的栈地址的地方。这个保存 r0 的栈地址相对 r1 的偏移是不确定的，需要自己静态分析或动态调试发现。

## IDA 汇编代码例子

以某个 Vxworks 系统的固件程序在 IDA 中的汇编结果为例，实际查看一下常见 PPC 汇编语句的作用：

```
ROM:001D3FE4
ROM:001D3FE4                         # =============== S U B R O U T I N E =======================================
ROM:001D3FE4
ROM:001D3FE4
ROM:001D3FE4                         loginUserVerify:                        # CODE XREF: FTP_User_Add+1EC↑p
ROM:001D3FE4                                                                 # add_ftp_user+164↑p ...
ROM:001D3FE4
ROM:001D3FE4                         .set back_chain, -0x70
ROM:001D3FE4                         .set var_68, -0x68
ROM:001D3FE4                         .set var_10, -0x10
ROM:001D3FE4                         .set var_C, -0xC
ROM:001D3FE4                         .set var_4, -4
ROM:001D3FE4                         .set sender_lr,  4
ROM:001D3FE4
ROM:001D3FE4 94 21 FF 90                             stwu      r1, back_chain(r1)
ROM:001D3FE8 7C 08 02 A6                             mflr      r0
ROM:001D3FEC 93 E1 00 6C                             stw       r31, 0x70+var_4(r1)
ROM:001D3FF0 90 01 00 74                             stw       r0, 0x70+sender_lr(r1)
ROM:001D3FF4 7C 7F 1B 78                             mr        r31, r3
ROM:001D3FF8 7C 83 23 78                             mr        r3, r4
ROM:001D3FFC 38 81 00 08                             addi      r4, r1, 0x70+var_68
ROM:001D4000 48 00 06 91                             bl        sub_1D4690
ROM:001D4004 2C 83 FF FF                             cmpwi     cr1, r3, -1
ROM:001D4008 40 86 00 0C                             bne       cr1, loc_1D4014
ROM:001D400C 38 60 FF FF                             li        r3, -1
ROM:001D4010 48 00 00 5C                             b         loc_1D406C
ROM:001D4014                         # ---------------------------------------------------------------------------
ROM:001D4014
ROM:001D4014                         loc_1D4014:                             # CODE XREF: loginUserVerify+24↑j
ROM:001D4014 3D 20 00 33                             lis       r9, dword_3297A4@ha
ROM:001D4018 80 69 97 A4                             lwz       r3, dword_3297A4@l(r9)
ROM:001D401C 7F E4 FB 78                             mr        r4, r31
ROM:001D4020 38 A1 00 60                             addi      r5, r1, 0x70+var_10
ROM:001D4024 38 C1 00 64                             addi      r6, r1, 0x70+var_C
ROM:001D4028 4B FC A8 C5                             bl        symFindByName
ROM:001D402C 2C 83 FF FF                             cmpwi     cr1, r3, -1
ROM:001D4030 40 86 00 10                             bne       cr1, loc_1D4040
ROM:001D4034 3C 60 00 36                             lis       r3, 0x36
ROM:001D4038 60 63 00 01                             ori       r3, r3, 1 # 0x360001
ROM:001D403C 48 00 00 20                             b         loc_1D405C
ROM:001D4040                         # ---------------------------------------------------------------------------
ROM:001D4040
ROM:001D4040                         loc_1D4040:                             # CODE XREF: loginUserVerify+4C↑j
ROM:001D4040 80 61 00 60                             lwz       r3, 0x70+var_10(r1)
ROM:001D4044 38 81 00 08                             addi      r4, r1, 0x70+var_68
ROM:001D4048 4B FA 33 39                             bl        strcmp
ROM:001D404C 2C 83 00 00                             cmpwi     cr1, r3, 0
ROM:001D4050 41 86 00 18                             beq       cr1, loc_1D4068
ROM:001D4054 3C 60 00 36                             lis       r3, 0x36
ROM:001D4058 60 63 00 03                             ori       r3, r3, 3 # 0x360003
ROM:001D405C
ROM:001D405C                         loc_1D405C:                             # CODE XREF: loginUserVerify+58↑j
ROM:001D405C 4B FC 05 CD                             bl        errnoSet
ROM:001D4060 38 60 FF FF                             li        r3, -1
ROM:001D4064 48 00 00 08                             b         loc_1D406C
ROM:001D4068                         # ---------------------------------------------------------------------------
ROM:001D4068
ROM:001D4068                         loc_1D4068:                             # CODE XREF: loginUserVerify+6C↑j
ROM:001D4068 38 60 00 00                             li        r3, 0
ROM:001D406C
ROM:001D406C                         loc_1D406C:                             # CODE XREF: loginUserVerify+2C↑j
ROM:001D406C                                                                 # loginUserVerify+80↑j
ROM:001D406C 80 01 00 74                             lwz       r0, 0x70+sender_lr(r1)
ROM:001D4070 7C 08 03 A6                             mtlr      r0
ROM:001D4074 83 E1 00 6C                             lwz       r31, 0x70+var_4(r1)
ROM:001D4078 38 21 00 70                             addi      r1, r1, 0x70
ROM:001D407C 4E 80 00 20                             blr
ROM:001D407C                         # End of function loginUserVerify
```

### 函数初始化汇编语句

0x01D3FE4 地址定义为 loginUserVerify 函数的开头。

1. 首先 0x01D3FE4 地址处的 `stwu      r1, back_chain(r1)` 指令，将 r1 寄存器（表示栈寄存器）的值存储到 r1-0x70 地址处，此条指令相当于保存原来函数的栈环境，类似与 x86 中 `push ebp` 指令的操作。

2. 接着 `mflr      r0` 指令，将 lr 寄存器的值存储到 r0 寄存器中，在地址 0x01D3FF0 处，将 r0 寄存器的值存储到 r1+0x74 的内存地址处


### 逻辑处理一

在 0x01D3FF4 到 0x01D4000 地址段中，对 r3 和 r4 寄存器进行赋值，并使用 bl 指令调用了 `sub_1D4690` 函数，针对于参数的传递，可以表示成 `sub_1D4690(r4,r1+0x8)`。

在 0x01D4004 到 0x01D4010 地址段中，进行了分支判断和条件跳转，首先 `cmpwi` 指令，比较 r3 寄存器的值是否为 -1，跳转到 loc_1D4014 代码段中，否则跳转到 loc_1D406C 代码段中（也就是函数的结尾），表示此分支为结束分支。

用伪 C 代码来表示这里的代码如下：

```
if(sub_1D4690(r4,r1+0x8) != -1){
	goto loc_1D4014;
}else{
	return -1;
}
```

### 逻辑处理二

在 0x01D4014 到 0x01D403C 地址段中，同样进行了函数调用、分支判断和条件跳转，先对 r3、r4、r5、r6 四个寄存器进行赋值，接着调用 `symFindByName` 函数，即调用 `symFindByName(dword_3297A4,r31,r1+0x60,r1+0x64)`。

比较函数的返回值，如果为 -1 的话跳转到 0x01D405C 地址处，调用 `errnoSet(0x360001)` 函数，并 `jmp loc_1D405C` 进行函数返回。不为 -1 的话跳转到 0x01D4040 代码段处，在此代码段中，调用了 `strcmp` 函数，比较 `strcmp` 函数的返回结果，并进行分支跳转。

整个函数的伪 C 代码可以表示为：

```
int loginUserVerify(r4,r4){
	if(sub_1D4690(r4,r1+0x8) != -1){
		if(symFindByName(dword_3297A4,r31,r1+0x60,r1+0x64) == -1){
			errnoSet(0x360001);
			return -1;
		}else{
			if(strcmp([r1+0x60],r1+0x8)==0){
				return 0;
			}else{
				errnoSet(0x360003);
				return -1;
			}
		}
	}else{
		return -1;
	}
}
```

### 函数末尾

0x01D406C 到 0x01D407C 内存地址定义为函数末尾代码段，首先 `lwz` 指令将原本存储在栈上的返回地址取出，赋值给 r0 寄存器， 并使用 `mtlr` 命令将 r0 寄存器的值复制到 lr 寄存器中，接着 `addi      r1, r1, 0x70` 语句恢复调用前的栈空间，最后 `blr` 指令相当于 `jmp lr` 跳转回返回地址处，进行函数返回。

## 总结

PPC 的汇编架构本质是属于 RISC 类的指令集，许多汇编指令的操作和运算和 MIPS 指令集大同小异，分析时只需对照着学习、分析即可。
