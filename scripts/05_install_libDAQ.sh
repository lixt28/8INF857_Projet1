#!/usr/bin/env bash
# Script d'aide pour compiler Snort3 (adapté de https://docs.snort.org/start/installation)
# Exécuter avec sudo sur la VM monitoring
sudo apt install -y build-essential g++ automake git autoconf libtool libpcap-dev libpcre3-dev libnet1-dev zlib1g-dev luajit hwloc libdnet-dev libdumbnet-dev bison flex liblzma-dev openssl libssl-dev pkg-config libhwloc-dev cmake cpputest libsqlite3-dev uuid-dev libcmocka-dev libnetfilter-queue-dev libmnl-dev autotools-dev libluajit-5.1-dev libunwind-dev libfl-dev

# LibDAQ
git clone https://github.com/snort3/libdaq.git
cd libdaq
./bootstrap
./configure --prefix=/usr/local/lib/daq_s3
make
sudo make install
cat /etc/ld.so.conf.d/libdaq3.conf
sudo ldconfig
