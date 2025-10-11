#!/usr/bin/env bash
# usage: sudo ./ssh_bruteforce_syn.sh 192.168.1.2 40
TARGET=${1:-192.168.1.2}
COUNT=${2:-40}
sudo hping3 -S -p 22 -c "$COUNT" --faster "$TARGET"
