#!/bin/bash

# Usage: ./update-kubeconfig.sh <IP_ADDRESS>
# Example: ./update-kubeconfig.sh 18.183.172.198

if [ -z "$1" ]; then
  echo "Error: IP address required"
  echo "Usage: $0 <IP_ADDRESS>"
  exit 1
fi

IP_ADDRESS=$1

# Create a temporary file for the updated config
TMP_FILE=$(mktemp)

# Read the config file and replace the certificate-authority-data block with insecure-skip-tls-verify
sed -e '/certificate-authority-data:/d' \
    -e "s|server: https://0.0.0.0:6443|insecure-skip-tls-verify: true\n    server: https://${IP_ADDRESS}:6443|" \
    config > "$TMP_FILE"

# Replace the original file
mv "$TMP_FILE" config

echo "Updated config file with IP address: $IP_ADDRESS"

\head -7 config

echo ""
echo "execute:"
echo "export KUBECONFIG=$PWD/config"
echo ""

export KUBECONFIG=$PWD/config
kubectl get no
