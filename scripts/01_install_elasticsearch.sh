#!/usr/bin/env bash
set -e
sudo apt update
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt install -y apt-transport-https
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt update
sudo apt install -y elasticsearch
sudo sed -i 's/#cluster.name.*/cluster.name: "lab-cluster"/' /etc/elasticsearch/elasticsearch.yml || true
sudo sed -i 's/#network.host.*/network.host: 0.0.0.0/' /etc/elasticsearch/elasticsearch.yml || true
sudo systemctl enable --now elasticsearch
#sleep 3
#curl -s 'http://localhost:9200/_cluster/health?pretty'
