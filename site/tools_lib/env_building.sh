#!/bin/bash

cat /etc/issue | grep 16.04 > /dev/null

if [ $? == 0 ]
then
    VERSION=5;
elif [ $? == 1 ]
then
    VERSION=7;
else
    VERSION=5;
fi

sudo apt-get update

sudo apt-get install emdebian-archive-keyring
echo "[*] Installing mips cross compile environment..."

sudo apt-get install linux-libc-dev-mips-cross
sudo apt-get install libc6-mips-cross libc6-dev-mips-cross
sudo apt-get install binutils-mips-linux-gnu gcc-${VERSION}-mips-linux-gnu
sudo apt-get install g++-${VERSION}-mips-linux-gnu


echo "[*] Installing mipsel cross compile environment..."

sudo apt-get install linux-libc-dev-mipsel-cross
sudo apt-get install libc6-mipsel-cross libc6-dev-mipsel-cross
sudo apt-get install binutils-mipsel-linux-gnu
sudo apt-get install gcc-${VERSION}-mipsel-linux-gnu g++-${VERSION}-mips-linux-gnu

echo "[*] Installing armel/armhf cross compile environment..."

sudo apt-get install linux-libc-dev-armel-cross install linux-libc-dev-armhf-cross libc6-armhf-cross libc6-dev-armhf-cross
sudo apt-get install libc6-armel-cross libc6-dev-armel-cross
sudo apt-get install binutils-arm-none-eabi binutils-arm-linux-gnueabi
sudo apt-get install gcc-${VERSION}-arm-linux-gnueabi g++-${VERSION}-arm-linux-gnueabi

echo "[+] Install complete! Please reboot machine and then you can use it :)"

# ➜  tools_lib git:(master) ✗ mips
# mipsel-linux-gnu-addr2line     mips-linux-gnu-addr2line
# mipsel-linux-gnu-ar            mips-linux-gnu-ar
# mipsel-linux-gnu-as            mips-linux-gnu-as
# mipsel-linux-gnu-c++filt       mips-linux-gnu-c++filt
# mipsel-linux-gnu-cpp           mips-linux-gnu-cpp
# mipsel-linux-gnu-cpp-7         mips-linux-gnu-cpp-7
# mipsel-linux-gnu-dwp           mips-linux-gnu-dwp
# mipsel-linux-gnu-elfedit       mips-linux-gnu-elfedit
