#!/bin/bash

LOC=$(realpath $(dirname $0))

if [[ -f "~/.termux" ]]; then

  for file in $(ls ./termux); do
    ln -sf {$LOC/,~/.}termux/$file
  done

else

  for file in .blerc .clang-format .gitconfig; do
    ln -sf {$LOC,~}/$file
  done

  for file in $(ls $LOC/.config); do
    ln -sf {$LOC,~}/.config/$file
  done

  for dir in modprobe.d profile.d skel xdg; do
    for file in $(ls -A $LOC/etc/$dir); do
      sudo ln -sf {$LOC,}/etc/$dir/$file
    done
  done

  sudo mkdir -p /etc/pacman.d/hooks
  for hook in $(ls $LOC/etc/pacman.d/hooks); do
    sudo ln -sf {$LOC,}/etc/pacman.d/hooks/$hook
  done

  sudo rm /etc/skel/.bashrc
  sudo cp {$LOC,}/etc/skel/.bashrc
  cp {$LOC/etc/skel,~}/.bashrc

  sudo sed -i 's/^#MODULES=()/MODULES=(i2c_hid i915)/' /etc/mkinitcpio.conf

  if ! $(grep ". $LOC/.custom.bashrc" ~/.bashrc); then
    echo -e "\n# customisations\n\n. $LOC/.custom.bashrc" >>~/.bashrc
  fi

  for file in .bashrc .blerc; do
    sudo ln -sf {$HOME,/root}/$file
  done

  sudo pacman -S --needed --noconfirm intel-media-driver libvdpau-va-gl \
    libva-utils vdpauinfo intel-media-sdk thermald power-profiles-daemon yay

  sudo systemctl enable --now thermald power-profiles-daemon

  sudo update-desktop-database # global
  update-desktop-database      # user directory

  sudo mkinitcpio -P

  echo -e "\n\n\033[33;1mManual intervention required.\033[0m"

  echo -e " \033[31;1m-\033[0m Edit \"\033[34;1m/etc/{fstab,crypttab}\033[0m\" using the previous config files as reference"
  echo -e " \033[31;1m-\033[0m Save your bitlocker key in \"\033[34;1m/etc/cryptsetup-keys.d/*.key\033[0m\" using the previous key file as reference"
  echo -e " \033[31;1m-\033[0m Previous confg files are in \033[34;1metc\033[0m subdir in current dir."

  echo -e "\033[32;1mAutomatic dotfiles sync successful.\033[0m\n"

fi
