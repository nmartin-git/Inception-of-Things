#!/bin/bash

set -e

apt-get update
apt-get install -y curl

curl -sfL https://get.k3s.io | K3S_URL="https://192.168.56.110:6443" K3S_TOKEN_FILE="/vagrant/node-token" INSTALL_K3S_EXEC="agent --node-ip 192.168.56.111" sh -