#!/bin/bash

set -e

apt-get updates
apt-get install -y curl

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip 192.168.56.110" sh -

while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
  sleep 2
done

cp /var/lib/rancher/k3s/server/node-token /vagrant