> H4lo@海特实验室

## 概述

对 firmadyne 开源项目的 fat.py 文件进行了改进：

1. 将宿主机与虚拟机之间的通信方式改为 tap0 虚拟网卡模式，解决了部分情况下宿主机无法和虚拟机进行通信的问题。
2. 默认在 2309 开启了设备的 telnet 端口，不需要密码即可连接。


## 改进脚本链接

放在了海特实验室知识库目录下：

https://gitee.com/h4lo1/HatLab_Tools_Library/blob/master/firmadyne/modify_fat.py
