#!/usr/bin/env bash
# Snort3
git clone https://github.com/snort3/snort3.git 
export MY_PATH=/usr/local/
mkdir -p "$MY_PATH"
./configure_cmake.sh --prefix="$MY_PATH" --with-daq-includes=/usr/local/lib/daq_s3/include/ --with-daq-libraries=/usr/local/lib/daq_s3/lib/

cd build
make -j"$(nproc)"
sudo make install

snort -V
echo "Snort3 installé dans $MY_PATH. Si 'snort -V' fonctionne, continuez la configuration (snort.lua, rules)."
