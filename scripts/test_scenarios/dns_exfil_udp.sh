#!/usr/bin/env bash
TARGET=${1:-192.168.1.2}
for i in {1..5}; do
  printf 'exfil' | nc -u -w1 "$TARGET" 53
  sleep 0.2
done
