#!/bin/bash
PASSWORD=""

read -r -p "[sudo] Password: " -s PASSWORD
echo
#shellcheck disable=SC2218
sudo -k
while ! sudo -S true <<<"$PASSWORD" &>/dev/null; do
  read -r -p "[sudo] Incorrect Password, Try again: " -s PASSWORD
  echo
done
echo
sudo() {
  command sudo -S "$@" <<<"$PASSWORD"
}

if [[ -d "/opt/flutter" ]]; then
  echo "Flutter already installed"
else
  echo -e "\033[33;1mInstalling \033[32;1mFlutter\033[0m"
  sudo true
  yay -S --needed --noconfirm glu libglvnd clang ninja pkgconf gtk3 2>/dev/null
  sudo git clone https://github.com/flutter/flutter -b stable --single-branch --depth=1 /opt/flutter
  flutter config --no-analytics
  flutter doctor
  echo "Flutter installed successfully"
fi
