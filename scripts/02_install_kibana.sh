#!/usr/bin/env bash
set -e
sudo apt update
sudo apt install -y kibana
sudo sed -i 's/#server.host: "localhost"/server.host: "0.0.0.0"/' /etc/kibana/kibana.yml || true
sudo sed -i 's/#elasticsearch.hosts: .*/elasticsearch.hosts: ["http:\/\/localhost:9200"]/' /etc/kibana/kibana.yml || true
sudo systemctl enable --now kibana
