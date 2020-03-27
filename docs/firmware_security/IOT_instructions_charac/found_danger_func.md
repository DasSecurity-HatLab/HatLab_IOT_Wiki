# IOT 设备漏洞挖掘-MIPS 指令集逆向技巧

## MIPS 反汇编工具

IDA 无法直接反汇编 mips 代码，但是有两个插件可以辅助我们进行伪代码的生成。

### IDA 插件之 retdec

项目地址：https://github.com/avast/retdec

安装过程较为简单，可以参考网上的相关教程，不在此赘述了，以下是两张分析时候的截图，第一张是分析过程中的截图，第二张是分析的结果。

![1](http://static.zybuluo.com/H4l0/gw23cphl54ael140xpibmi1f/image.png)

![image.png-401kB][1]

### Ghidra

> 
Ghidra是由美国国家安全局（NSA）研究部门开发的软件逆向工程（SRE）套件，是一个软件逆向工程（SRE）框架，包括一套功能齐全的高端软件分析工具，使用户能够在各种平台上分析编译后的代码，包括Windows、Mac OS和Linux。功能包括反汇编，汇编，反编译，绘图和脚本，以及数百个其他功能。Ghidra支持各种处理器指令集和可执行格式，可以在用户交互模式和自动模式下运行。用户还可以使用公开的API开发自己的Ghidra插件和脚本。

总之这个一个功能非常强大的反汇编工具，基于 java 开发，可以反汇编很多种的汇编代码类型。而我们使用这个工具的目的就是因为这个工具可以帮助我们生成 mips 的伪 C 代码。从而方便我们进行代码逆向。

有一款Ghrida的插件比较适用于习惯于用IDA的同学，会把Ghrida里面的快捷键映射成IDA里面的快捷键，这样用起来就好多了。

插件地址：`https://github.com/enovella/ida2ghidra-kb`

插件的安装方法较为简单，依照说明即可。实现了包括x、g等IDA中快捷键功能。

另外，需要主要，在使用Ghrida分析MIPS的时候，PLT和GOT的时候经常会出现问题，如图所示：

![image.png-112.5kB][2]

如果你需要定位GOT表，还是需要使用IDA查找更为直观方便。

> xxxkkk@海特实验室

## 敏感函数定位

我们在逆向分析一个 mips 指令集架构的二进制程序时，可以使用敏感函数定位的方法，快速定位敏感函数，如 system、sprintf、strcpy 等命令执行和容易发生栈溢出的函数。

## 常见敏感函数类别

### 内存类型的敏感函数

* 栈溢出敏感函数

在 MIPS 指令集中，特别是智能设备，一般来说栈溢出漏洞较为常见，也是比较容易利用的一类漏洞，发生栈溢出可能的函数有 strcpy，sprintf，snprint, strchr 等。

1） strcpy 类函数如下所示，直接从 http 数据包参数中的数据内容，直接复制到栈上，没有经过任何的判断与处理，因此可以通过栈溢出越界的 buffer 覆盖当前函数的返回地址，可以进一步利用 ROP 技术来获取目标程序的 shell。

```
strcpy(stack, buf_from_http);
```

2）sprintf类，如果格式化中有“%s”格式化字符串，同时没有对输入的数据进行长度判断的话，则也有可能造成栈溢出漏洞。

```
sprintf(stack, "%s", buf_from_http);
```

3) snprintf类，snprintf 的返回值是输入的长度，而不是输出的长度，因此下面的代码则有可能存在漏洞，大致的利用原理因为，第一个snprinf返回值是输入的长度，一般输入的长度大于sizeof(stack)，则第二个 snprintf 的 size 则变为负数，snprintf 的大小是无符号的，因此变成了一个超大的size，导致第二个可以用来覆盖返回地址。值得注意的是，这样类型的 overflow 还可以用来bypass canary。 

```
int left = snprintf(stack, sizeof(stack),"%s", buf_from_http1);
snprintf(stack+left, sizeof(stack)-left, "%s", buf_from_http2);
```

4） strchr类，如下所示，乍一看好像使用了strncpy规定了复制的长度，但仔细看就会发现，复制的长度也是由输入的字符串来决定的，因此直接在？前面输入超长的字符即可实现overflow

```
char *query = strchr(url, '?');
strncpy(stack, url, quey - url -1);
```

如：`index.phpaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa?a=1`。只要 QURTY_STRING 够长就可以导致栈溢出。

### 注入类型的敏感函数（逻辑）
注入类型的漏洞相对来说就简单很多，只要看数据流的处理流程，确定输入能否控制敏感函数即可。
常见的敏感函数如system、popen、exec、execve等，在注入类型漏洞中，对于过滤的关键词绕过是比较关键的，例如没有空格的时候可以使用 $IFS进行绕过。也可以通过一些编码比如xxd，base64等。

## IDA 自动定位敏感函数插件

这里推荐一个比较方便定位二进制程序敏感函数的 python 插件：MipsAduit，项目地址：https://github.com/giantbranch/mipsAudit

> 该工具是一个 MIPS 静态汇编审计辅助脚本，通过敏感函数回溯的方法，可以较方便的审计出 C 语言中的危险函数。

### 插件的安装方法

在 IDA -> file -> Script File 中加载即可，加载完成后会在控制台中输出相应的信息。

![image.png-125.4kB][3]

点击相应的地址就可以跳转过去，对应的位置会被高亮显示：

![image.png-287.6kB][4]


## 使用 IDAPython 自带函数来定位敏感函数

IDAPython 自带很多的 API，可以使用这这些 API 函数来辅助我们进行函数的定位。

如，定位出调用 sprintf 函数的地址列表的代码：

```
sprintf_list = set()
for loc,name in Names():
    if "sprintf" == name:
        for addr in XrefsTo(loc):											# 列出调用 sprintf 的函数地址
                sprintf_list.add(GetFunctionName(addr.frm))
                
print("\n\n")
print(sprintf_list)																# 打印输出
```
- 可以直接在 IDA 中，File -> Script command... 的输入框中输入这些代码，点击 run 就可以执行：

![image.png-218kB][5]

运行完成之后的结果使用 print 函数输出之后，会打印在 Output window 中：

![image.png-31.7kB][6]

这些输出的地址就是引用了 sprintf 方法的函数，同样双击函数名可以直接跳转到相应的地址。

- 读者可以在自行在 `for addr in XrefsTo(loc): ` 语句下加入其他过滤语句，以达到更准确定制自己想要的功能。

如这里想要排除 sytem 敏感函数第一个参数为 .data 段中的字符，且不包含 %s 字符的话（说明格式化参数不可控），如我们需要排除这种情况：

```
system("rm -f /tmp/auth_engineer");
```

那么，条件可以写成这样：

```
system_list = set()
for loc,name in Names():
    if "system" == name:
        for addr in XrefsTo(loc):                                            # 列出调用 system 的函数地址
                system_list.add(addr.frm)
print("\n\n")

system_args_list = set()
for addr in system_list:
    arg2_addr = 0
    arg2_addr = RfirstB(addr)       # 获取对 a0 语句赋值的语句
    arg2_str = GetString(Dword(GetOperandValue(arg2_addr,1)))                                # 获取 a0 参数的值的字符串 

    try:
        if "%s" not in arg2_str:
            system_args_list.add(addr)  # 排除这种情况
        else:
            pass
    except:
        pass
        
result_list = system_list-system_args_list  # 取差集，得到最终结果

for addr in result_list:
    print(hex(addr))
```

得到的结果也更精确一些：

![](http://10.20.152.151/server/../Public/Uploads/2020-03-27/5e7d6fb836a0a.png)


  [1]: http://static.zybuluo.com/H4l0/jofhmrwbbyrecierwda6go3m/image.png
  [2]: http://static.zybuluo.com/H4l0/4h1984vstnofxnaqx93p0xt8/image.png
  [3]: http://static.zybuluo.com/H4l0/a3h3txd3nue0k6qrh4jkibdh/image.png
  [4]: http://static.zybuluo.com/H4l0/hjufchrzgl5akko5vaodef38/image.png
  [5]: http://static.zybuluo.com/H4l0/13ny6s9ai430ej7l7hrk4qof/image.png
  [6]: http://static.zybuluo.com/H4l0/i5lb6x01sq817o22xp7whe2k/image.png
