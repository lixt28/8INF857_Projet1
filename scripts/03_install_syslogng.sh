#!/usr/bin/env bash
set -e
sudo apt update
sudo apt install -y syslog-ng
sudo mkdir -p /var/log/central
sudo chown syslog:adm /var/log/central || true
sudo cp configs/syslog-ng/snort-es.conf /etc/syslog-ng/conf.d/snort-es.conf
sudo cp configs/syslog-ng/snort-mail.conf /etc/syslog-ng/conf.d/snort-mail.conf
sudo systemctl restart syslog-ng
sudo syslog-ng -s -f /etc/syslog-ng/syslog-ng.conf || true
