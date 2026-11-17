#!/bin/bash
sudo apt update && sudo apt install -y curl unzip

curl -fsSL https://awscli.amazonaws.com/v2/install.sh | sudo bash -s -- --system