> H4lo@海特实验室

[TOC]

## 前言

在使用 IDA 或者 Ghidra 工具来静态逆向分析 IOT 固件（mips/arm 架构）的过程中，经常会遇到有某些函数或者代码段逻辑比较复杂或者算法比较繁杂，难以静态分析出函数的功能，而且这个函数或者代码段又无法动态调试。这时候可以使用这个插件来帮助你在逆向过程中动态执行某一段汇编代码，通过对这段代码执行的结果或者执行的中间信息（hook），来对逆向工作起到一定的帮助效果。


## unicorn 工具的介绍

由于工具是基于 unicorn 开发，这里先介绍一下 unicorn 这个工具，给出官方的介绍：

> Unicorn is a lightweight multi-platform, multi-architecture CPU emulator framework.
...

> Multi-architectures: Arm, Arm64 (Armv8), M68K, Mips, Sparc, & X86 (include X86_64).

简单来说，这个工具是一个 cpu 指令模拟框架，也就是工具可以动态模拟任何的 cpu 指令，也就是可以对任意的一段汇编代码进行运行，并输出其结果。基于这个工具的特点，我们可以将他集成到反汇编引擎/工具中，如 IDA 或者 ghidra。工具详细的介绍可以看[官方网站][1]。

### 示例代码

```
from __future__ import print_function
 2 from unicorn import *
 3 from unicorn.x86_const import *
 4 
 5 # code to be emulated
 6 X86_CODE32 = b"\x41\x4a" # INC ecx; DEC edx
 7 
 8 # memory address where emulation starts
 9 ADDRESS = 0x1000000
10 
11 print("Emulate i386 code")
12 try:
13     # Initialize emulator in X86-32bit mode
14     mu = Uc(UC_ARCH_X86, UC_MODE_32)
15 
16     # map 2MB memory for this emulation
17     mu.mem_map(ADDRESS, 2 * 1024 * 1024)
18 
19     # write machine code to be emulated to memory
20     mu.mem_write(ADDRESS, X86_CODE32)
21 
22     # initialize machine registers
23     mu.reg_write(UC_X86_REG_ECX, 0x1234)
24     mu.reg_write(UC_X86_REG_EDX, 0x7890)
25 
26     # emulate code in infinite time & unlimited instructions
27     mu.emu_start(ADDRESS, ADDRESS + len(X86_CODE32))
28 
29     # now print out some registers
30     print("Emulation done. Below is the CPU context")
31 
32     r_ecx = mu.reg_read(UC_X86_REG_ECX)
33     r_edx = mu.reg_read(UC_X86_REG_EDX)
34     print(">>> ECX = 0x%x" %r_ecx)
35     print(">>> EDX = 0x%x" %r_edx)
36 
37 except UcError as e:
38     print("ERROR: %s" % e)
```

1. 首先使用 Uc 类新建一个 unicorn 对象，并设置目标指令架构为 X86、32 位模式
2. 映射出代码段（mem_map），并将汇编代码写入（mem_write）代码段，对寄存器进行赋值（reg_write）
3. 使用 emu_start 函数进行指令模拟，函数参数为开始的地址和结束的地址，**也就是之前映射出来的代码段的地址**。
4. 模拟完成之后可以对目标内存段或者寄存器进行读取的操作，以便分析模拟执行的结果


## IDA_MIPS_EMU 用法

IDA_MIPS_EMU 是一款 python 开发的用来模拟 mips指令的 IDA 插件，首先需要将插件加载到 IDA 中。在 File -> Script file 中加载进来即可。

1. 设置 emu 对象
```
a = EmuMips()
```
2 . 设置需要模拟的开始地址和结束地址，以及相关的参数

```
a.configEmu(0x400000,0x401000,[1,2,3])

Python>a.configEmu(0x00400640,0x00400678,[2,3])
[*] Init registers success...
[*] Init code and data segment success! 
[*] Init Stack success...
[*] set args...
```

- 其中参数是以数组的形式传递给 configEmu 函数，按照 mips 指令的传参方法，**这样最多支持三个参数的传入**。在调用这个函数时，同时初始化了栈段、代码段以及数据段，这样对于这些程序必须用到的段就不需要手动映射。

3 . 向某个内存段写入数据（必须是映射过的段）

```
a.fillData("test123",0x401000)

Python>a.fillData("MTIzNDUK",0xbfffe000)
[*] Data mapping address： 0xbfffe000
```
- 因为代码中实现了将程序 .text 全部映射了出来，所以这里向 0x401000 这个内存（.text 段中）写入 `test123` 是合法的。

4 . 读取寄存器的值

```
a.showRegs()

Python>a.showRegs()
[*]  regs: 
[*]     A0 = 0xbfffe000  A1 = 0x8  A2 = 0xbffff000
        SP = 0xbfff8000  RA = 0x0  FP = 0x0
```
    
5 . 读取映射过的内存段的值

```
a.readMemContent(0x10008000,[size])

Python>a.readMemContent(0xbfffe000,50)
[*] Dest memory content: MTIzNDUK
```


6 . 显示调试信息 

```
a.showTrace()

>>> Tracing instruction at 0x4435a4, instruction size = 0x4
>>> Tracing instruction at 0x4435a8, instruction size = 0x4
>>> Tracing instruction at 0x4435ac, instruction size = 0x4
>>> Tracing instruction at 0x4435b0, instruction size = 0x4
>>> Tracing instruction at 0x4435b4, instruction size = 0x4
...
```

- **详细的代码参考文末的项目地址**。

### 例子 1

- 程序源代码

```
#include <stdlib.h>

int calc(int a,int b){
        int sum;
        sum = a+b;
        return sum;

}

int main(){
        calc(2,3);
}
```

将其编译成 mips lsb 程序，将其加载到 IDA 中，查看 calc 的汇编代码：

```
.text:00400640                 .globl calc
.text:00400640 calc:                                    # CODE XREF: main+18↓p
.text:00400640
.text:00400640 var_10          = -0x10
.text:00400640 var_4           = -4
.text:00400640 arg_0           =  0
.text:00400640 arg_4           =  4
.text:00400640
.text:00400640                 addiu   $sp, -0x18
.text:00400644                 sw      $fp, 0x18+var_4($sp)
.text:00400648                 move    $fp, $sp
.text:0040064C                 sw      $a0, 0x18+arg_0($fp)
.text:00400650                 sw      $a1, 0x18+arg_4($fp)
.text:00400654                 lw      $v1, 0x18+arg_0($fp)
.text:00400658                 lw      $v0, 0x18+arg_4($fp)
.text:0040065C                 addu    $v0, $v1, $v0
.text:00400660                 sw      $v0, 0x18+var_10($fp)
.text:00400664                 lw      $v0, 0x18+var_10($fp)
.text:00400668                 move    $sp, $fp
.text:0040066C                 lw      $fp, 0x18+var_4($sp)
.text:00400670                 addiu   $sp, 0x18
.text:00400674                 jr      $ra
.text:00400678                 nop
.text:00400678  # End of function calc
```

#### 模拟过程

1 . 创建一个 emu object
```
Python>a = EmuMips()
```


2 . 配置模拟地址和参数

```
Python>a.configEmu(0x00400640,0x00400678,[2,3])
[*] Init registers success...
[*] Init code and data segment success! 
[*] Init Stack success...
[*] set args...
```

3 . 显示寄存器信息

```
Python>a.showRegs()
[*]  regs: 
[*]     A0 = 0x2  A1 = 0x3  A2 = 0x0
        SP = 0xbfff8000  RA = 0x0  FP = 0x0  V0 = 0x0
        
```
4 . 开始指令模拟

```
Python>a.beginEmu()
[*] emulating...

[*] Done! Emulate result return: 0x5
```

5 . 打印出结果

```
Python>a.showRegs()
[*]  regs: 
[*]     A0 = 0x2  A1 = 0x3  A2 = 0x0
        SP = 0xbfff8000  RA = 0x0  FP = 0x0  V0 = 0x5
        
```

- mips 汇编代码的函数返回值存在 V0 寄存器中，这里很明显打印出了正确的结果。


### 例子 2

这里实战分析一个 base64 的解码函数。加载某个固件，找到 base64_decode 函数：

![image.png-224.4kB][2]

首先分析出函数的参数的表示意义，经过简单的分析：**第一个参数为 base64 编码的字符串地址，第二个参数为字符串的长度，第三个参数为 base64 解码之后的目标内存地址。**

#### 模拟过程

- 假设这里需要解码 `dGVzdDEyMzQK`，即 `test1234`

1 . 创建一个 emu object
```
Python>a = EmuMips()
[+] Init...
```

2 . 配置模拟地址和参数

```
Python>a.configEmu(0x00443278,0x00443648,[0x3000,12,0x4000])
[*] Init registers success...
[*] Init code and data segment success! 
[*] Init Stack success...
[*] set args...
```

- 0x3000 和 0x4000 地址都需要映射

3 . 映射出两个地址地址

```
Python>a.mapNewMemory(0x3000)
[*] Map memory success!
Python>a.mapNewMemory(0x4000)
[*] Map memory success!
```

4 . 将字符串写入第一个内存地址

```
Python>a.fillData("dGVzdDEyMzQK",0x3000)
[*] Data mapping address： 0x3000
```

- 读取内存发现正常写入

```
Python>a.readMemContent(0x3000)
[*] Dest memory content: dGVzdDEyMzQK
```

5 . 映射出 base64 编码表

![image.png-181.6kB][3]

```
Python>a.fillData("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/>\xFF\xFF\xFF?456789:;<=\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x01\x02\x03\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\xFF\xFF\xFF\xFF\xFF\xFF\x1A\x1B\x1C\x1D\x1E\x1F\x20!\"#$%&'()*+,-./0123",0x00471390)
[*] Data mapping address： 0x471390
```

6 . 开始模拟

```
Python>a.beginEmu()
[*] emulating...

[*] Done! Emulate result return: 0x9
```

- 可知函数的返回值为 9，即 `test1234` 字符串的长度。

7 . 查看结果，解码成功

```
Python>a.readMemContent(0x4000)
[*] Dest memory content: test1234
```

## 项目地址

```
https://github.com/H4lo/IDA_MIPS_EMU
```


  [1]: http://www.unicorn-engine.org/
  [2]: http://static.zybuluo.com/H4l0/7otthcythb7xi5sxrmihufo5/image.png
  [3]: http://static.zybuluo.com/H4l0/47zh25ft96d8as3ckd6fuu4w/image.png