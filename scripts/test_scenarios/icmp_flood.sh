#!/usr/bin/env bash
TARGET=${1:-192.168.1.2}
COUNT=${2:-50}
sudo hping3 -1 -c "$COUNT" -i u1000 "$TARGET"
