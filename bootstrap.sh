#!/bin/bash

hash() {
  echo $(sha256sum "$1" | cut -d' ' -f1)
}

create_dirs() {
  find -mindepth 1 -type d \( \
    \( -exec test ! -d "$1/{}" \; \
    -exec mkdir -pv "$1/{}" \; \) \
    -o \
    -exec echo "'$1/{}' exists" \; \
    \)
}

link_files() {
  find -mindepth 1 -type f \( \
    \( -exec test ! -L "$2/{}" \; \
    -exec ln -svf "$1/{}" "$2/{}" \; \) \
    -o \
    -exec echo "'$2/{}' exists" \; \
    \)
}

process_configs() {
  pushd "$1" >/dev/null
  create_dirs "$2"
  link_files "$1" "$2"
  popd >/dev/null
}

process_root_configs() {
  sudo bash -c "$(declare -f process_configs create_dirs link_files); process_configs $1 $2"
}

LOC=$(realpath $(dirname $0))

if [[ "$PREFIX" =~ "com.termux" ]]; then
  if ! command -v gmake || ! command -v gawk || ! command -v micro; then
    echo -e "\033[33;1m -> \033[0m Installing packages."
    pkg install make gawk micro
  fi

  process_configs {"$LOC/termux","$PREFIX"}/"etc"
  termux-reload-settings
  echo

  process_configs {"$LOC","$HOME"}/".config/micro"
  echo

else

  process_configs {"$LOC","$HOME"}/".config"
  echo

  for dir in modprobe.d profile.d skel xdg; do
    for file in $(ls -A "$LOC/etc/$dir"); do
      if [[ ! -L "/etc/$dir/$file" ]]; then
        sudo ln -svf {"$LOC",}/"etc/$dir/$file"
      else
        echo "'/etc/$dir/$file' exists"
      fi
    done
  done
  echo

  process_root_configs {"$LOC",}/"etc/pacman.d/hooks"
  echo

  if [[ $(hash "/etc/skel/.bashrc") != $(hash "$LOC/etc/skel/.bashrc") ]]; then
    sudo rm /etc/skel/.bashrc
    sudo cp -v {"$LOC",}/etc/skel/.bashrc
    cp -v {"$LOC/etc/skel","$HOME"}/.bashrc
  else
    echo -e "'/etc/skel/.bashrc' & '~/.bashrc' already upto date"
  fi
  echo

  if $(grep "MODULES=()" /etc/mkinitcpio.conf); then
    sudo sed -i 's/MODULES=()/MODULES=(i2c_hid i915)/' /etc/mkinitcpio.conf
    echo "'/etc/mkinitcpio.conf' updated"
    sudo mkinitcpio -P
  else
    echo "'/etc/mkinitcpio.conf' already upto date"
  fi
  echo

  for file in .bashrc .blerc; do
    if ! $(sudo test -L "/root/$file"); then
      sudo ln -svf {"$HOME",/root}/"$file"
    else
      echo -e "'/root/$file' exists"
    fi
  done
  echo

  echo -e "\033[33;1mInstalling necessary packages...\033[0m"
  sudo pacman -S --needed --noconfirm yay 1>/dev/null 2>/dev/null
  if yay -Qq | grep -c gnome-desktop 1>/dev/null 2>/dev/null; then
    GNOME_PKGS="gnome-shell-extension-blur-my-shell \
      gnome-shell-extension-just-perfection-desktop gnome-shell-extension-pano"
  fi
  yay -S --needed --noconfirm intel-media-driver libvdpau-va-gl libva-utils \
    vdpauinfo intel-media-sdk thermald power-profiles-daemon micro \
    blesh-git mkinitcpio-firmware visual-studio-code-bin webcord-bin $GNOME_PKGS 2>/dev/null
  echo

  sudo systemctl enable --now thermald power-profiles-daemon 2>/dev/null

  sudo update-desktop-database

  if [[ ! -f "$LOC/.firstRunSuccess" ]]; then
    echo -e "\n\033[33;1mManual intervention required.\033[0;1m [OPTIONAL]\033[0m"

    echo -e " \033[31;1m-\033[0m Edit \"\033[34;1m/etc/{fstab,crypttab}\033[0m\" using the previous config files as reference"
    echo -e " \033[31;1m-\033[0m Save your bitlocker key in \"\033[34;1m/etc/cryptsetup-keys.d/*.key\033[0m\" using the previous key file as reference"
    echo -e " \033[31;1m-\033[0m Previous confg files are in \033[34;1metc\033[0m subdir in current dir."

    echo -e "\033[32;1mAutomatic dotfiles sync successful.\033[0m\n"
    touch $LOC/.firstRunSuccess
  fi

fi

for file in .blerc .clang-format .gitconfig; do
  if [[ ! -L "$HOME/$file" ]]; then
    ln -svf {"$LOC","$HOME"}/"$file"
  else
    echo "'~/$file' exists"
  fi
done
echo

if ! $(grep ". $LOC/.custom.bashrc" $HOME/.bashrc); then
  echo -e "\n# customisations\n\n. $LOC/.custom.bashrc" >>~/.bashrc
  echo -e "'~/.bashrc' updated to add customizations"
else
  echo -e "'~/.bashrc' already has customizations applied"
fi
echo
