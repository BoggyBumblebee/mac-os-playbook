#!/bin/bash

echo +~+~+~+~ Generate SSH Key
ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519_github -C "christopher@boggybumblebee.com" <<<y 2>&1 >/dev/null

echo +~+~+~+~ Ensure SSH Agent is running
eval "$(ssh-agent -s)"

echo +~+~+~+~ Add SSH Key to local SSH, and macOS Keychain
ssh-add -K ~/.ssh/id_ed25519_github

echo +~+~+~+~ Create SSH Config File
touch ~/.ssh/config

cat <<EOT >> ~/.ssh/config
Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519_github
EOT

clear
echo +~+~+~+~ Allow user to add SSH Key to GitHub
echo
echo
cat ~/.ssh/id_ed25519_github.pub
pbcopy < ~/.ssh/id_ed25519_github.pub

echo Copied public key to clipboard
echo
echo
read -p "Add the above public key to GitHub, then press [Enter] to resume and test connectivity"

echo +~+~+~+~ Test SSH Key with GitHub
echo
echo
ssh -T git@github.com

