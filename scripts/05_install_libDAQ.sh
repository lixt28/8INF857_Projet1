#!/usr/bin/env bash
# Script d'aide pour compiler Snort3 (adapté de https://docs.snort.org/start/installation)
# Exécuter avec sudo sur la VM monitoring
#sudo apt install -y build-essential g++ automake git autoconf libtool libpcap-dev libpcre2-dev libpcre3-dev libnet1-dev zlib1g-dev luajit hwloc libdnet-dev libdumbnet-dev bison flex liblzma-dev openssl libssl-dev pkg-config libhwloc-dev cmake cpputest libsqlite3-dev uuid-dev libcmocka-dev libnetfilter-queue-dev libmnl-dev autotools-dev libluajit-5.1-dev libunwind-dev libfl-dev
#sudo apt install -y build-essential cmake git libpcap-dev libpcre3-dev libdnet-dev       libdumbnet-dev zlib1g-dev liblzma-dev openssl libssl-dev pkg-config libhwloc-dev       libluajit-5.1-dev libluajit-5.1-common flex bison automake autoconf libtool
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential cmake pkg-config \
 libpcap-dev libpcre2-dev libpcre3-dev libnet1-dev zlib1g-dev \
 luajit libluajit-5.1-dev hwloc libdnet-dev libdumbnet-dev \
 bison flex liblzma-dev openssl libssl-dev \
 uuid-dev libsqlite3-dev libcmocka-dev libnetfilter-queue-dev \
 libmnl-dev libhwloc-dev autotools-dev libunwind-dev libfl-dev


# LibDAQ
git clone https://github.com/snort3/libdaq.git /tmp/libdaq
cd /tmp/libdaq || exit 1
./bootstrap || true
./configure --prefix=/usr/local/lib/daq_s3
make -j"$(nproc)"
sudo make install
echo "/usr/local/lib/daq_s3/lib/" | sudo tee /etc/ld.so.conf.d/libdaq3.conf
sudo ldconfig

# Snort3
git clone https://github.com/snort3/snort3.git /tmp/snort3
cd /tmp/snort3 || exit 1
export MY_PATH=/usr/local/
mkdir -p "$MY_PATH"
./configure_cmake.sh --prefix="$MY_PATH" --with-daq-includes=/usr/local/lib/daq_s3/include/ --with-daq-libraries=/usr/local/lib/daq_s3/lib/

cd build
make -j"$(nproc)"
sudo make install

"$MY_PATH/bin/snort" -V || true
echo "Snort3 installé dans $MY_PATH. Si 'snort -V' fonctionne, continuez la configuration (snort.lua, rules)."

