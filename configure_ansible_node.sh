#!/bin/bash
set -e # Exit on error

USERNAME="\" # Username will be passed as the first argument

echo "--- Starting Ansible Node Configuration Script ---"

# 1. Grant sudo access
echo "Granting sudo access to user '\user'..."
usermod -aG sudo "\user"
echo "Sudo access granted."

# 2. Install Python and pip
echo "Installing Python 3 and pip..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip
echo "Python and pip installed."

# 3. Install Ansible for the user
echo "Installing Ansible for user '\user'..."
sudo pip3 install --user ansible
echo "Ansible installed for user '\user'."

echo "--- Ansible Node Configuration Script Completed ---"
