sudo apt update
sudo apt install -y \
  build-essential cmake pkg-config \
  libpcap-dev libpcre2-dev libdnet-dev \
  luajit libluajit-5.1-dev \
  zlib1g-dev libhwloc-dev liblzma-dev libssl-dev \
  libhyperscan-dev libflatbuffers-dev libunwind-dev \
  autoconf automake libtool flex bison
#!/usr/bin/env bash
set -e
# Script d'aide pour compiler Snort3 (adapté de https://docs.snort.org/start/installation)
# Exécuter avec sudo sur la VM monitoring

sudo apt update
sudo apt install -y build-essential cmake git libpcap-dev libpcre3-dev libdnet-dev       libdumbnet-dev zlib1g-dev liblzma-dev openssl libssl-dev pkg-config libhwloc-dev       libluajit-5.1-dev libluajit-5.1-common flex bison automake autoconf libtool

# LibDAQ
if [ ! -d /tmp/libdaq ]; then
  git clone https://github.com/snort3/libdaq.git /tmp/libdaq
fi
cd /tmp/libdaq || exit 1
./bootstrap || true
./configure --prefix=/usr/local/lib/daq_s3
make -j"$(nproc)"
sudo make install
echo "/usr/local/lib/daq_s3/lib/" | sudo tee /etc/ld.so.conf.d/libdaq3.conf
sudo ldconfig

# Snort3
if [ ! -d /tmp/snort3 ]; then
  git clone https://github.com/snort3/snort3.git /tmp/snort3
fi
cd /tmp/snort3 || exit 1
export MY_PATH=/usr/local/snort
mkdir -p "$MY_PATH"
./configure_cmake.sh --prefix="$MY_PATH"        --with-daq-includes=/usr/local/lib/daq_s3/include/        --with-daq-libraries=/usr/local/lib/daq_s3/lib/

cd build
make -j"$(nproc)"
sudo make install

"$MY_PATH/bin/snort" -V || true
echo "Snort3 installé dans $MY_PATH. Si 'snort -V' fonctionne, continuez la configuration (snort.lua, rules)."
