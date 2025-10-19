#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Error on line $LINENO: $BASH_COMMAND" >&2' ERR

# Script d'aide pour compiler Snort3 (adapté de https://docs.snort.org/start/installation)
# Exécuter avec sudo sur la VM monitoring

sudo apt update
sudo apt install -y \
  build-essential cmake pkg-config git \
  autoconf automake libtool \
  libpcap-dev libpcre3-dev libpcre2-dev libnet1-dev zlib1g-dev \
  luajit libluajit-5.1-dev hwloc libhwloc-dev \
  libdnet-dev libdumbnet-dev bison flex liblzma-dev \
  openssl libssl-dev uuid-dev libsqlite3-dev libcmocka-dev \
  libnetfilter-queue-dev libmnl-dev autotools-dev libunwind-dev libfl-dev

# LibDAQ
if [ ! -d /tmp/libdaq ]; then
  git clone https://github.com/snort3/libdaq.git /tmp/libdaq
fi
cd /tmp/libdaq || exit 1
./bootstrap
./configure --prefix=/usr/local/lib/daq_s3
make -j"$(nproc)"
sudo make install
test -f /usr/local/lib/daq_s3/lib/daq/daq_pcap.so || {
  echo "daq_pcap.so introuvable -> installe libpcap-dev puis recompile libdaq."
  exit 1
}
echo "/usr/local/lib/daq_s3/lib" | sudo tee /etc/ld.so.conf.d/libdaq3.conf
sudo ldconfig

# Snort3
if [ ! -d /tmp/snort3 ]; then
  git clone https://github.com/snort3/snort3.git /tmp/snort3
fi
cd /tmp/snort3 || exit 1
export MY_PATH=/usr/local
mkdir -p "$MY_PATH"
./configure_cmake.sh --prefix="$MY_PATH"        --with-daq-includes=/usr/local/lib/daq_s3/include/        --with-daq-libraries=/usr/local/lib/daq_s3/lib/

cd build
make -j"$(nproc)"
sudo make install

"$MY_PATH/bin/snort" -V || true
echo "Snort3 installé dans $MY_PATH. Si 'snort -V' fonctionne, continuez la configuration (snort.lua, rules)."

