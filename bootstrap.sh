#!/bin/bash

hash() {
  echo $(sha256sum "$1" | cut -d' ' -f1)
}

LOC=$(realpath $(dirname $0))

if [[ -d "$HOME/.termux" ]]; then

  for file in $(ls "$LOC/termux"); do
    echo -ne "\033[33;1m ->\033[0m "
    if [[ ! -L "$HOME/.termux/$file" ]]; then
      ln -svf "$LOC/termux/$file" "$HOME/.termux/$file"
    else
      echo "~/.termux/$file exists"
    fi
  done

  termux-reload-settings

  echo -ne "\033[33;1m ->\033[0m "
  if [[ ! -d "$HOME/.config/micro" ]]; then
    mkdir -pv "$HOME/.config/micro"
  else
    echo "'~/.config/micro' exists"
  fi
  for file in $(ls "$LOC/.config/micro"); do
    echo -ne "\033[33;1m ->\033[0m "
    if [[ ! -L "$HOME/.config/micro/$file" ]]; then
      ln -svf {"$LOC","$HOME"}/".config/micro/$file"
    else
      echo "'~/config/micro/$file' exists"
    fi
  done

else

  for file in $(ls -A "$LOC/.config"); do
    echo -ne "\033[33;1m ->\033[0m "
    if [[ -d "$LOC/.config/$file" ]]; then
      if [[ ! -d "$HOME/.config/$file" ]]; then
        mkdir -pv "$HOME/.config/$file"
      else
        echo "'~/.config/$file' exists"
      fi
      for _file in $(ls -A "$LOC/.config/$file"); do
        echo -ne "\033[33;1m ->\033[0m "
        if [[ ! -L "$HOME/.config/$file/$_file" ]]; then
          ln -svf {"$LOC","$HOME"}/".config/$file/$_file"
        else
          echo "'~/config/$file/$_file' exists"
        fi
      done
    elif [[ -f "$LOC/.config/$file" ]]; then
      if [[ ! -L "$HOME/.config/$file" ]]; then
        ln -svf {"$LOC","$HOME"}/".config/$file"
      else
        echo "'~/.config/$file' exists"
      fi
    fi
  done
  echo

  for dir in modprobe.d profile.d skel xdg; do
    for file in $(ls -A "$LOC/etc/$dir"); do
      echo -ne "\033[33;1m ->\033[0m "
      if [[ ! -L "/etc/$dir/$file" ]]; then
        sudo ln -svf {"$LOC",}/"etc/$dir/$file"
      else
        echo "'/etc/$dir/$file' exists"
      fi
    done
  done
  echo

  echo -ne "\033[33;1m ->\033[0m "
  if [[ ! -d "/etc/pacman.d/hooks" ]]; then
    sudo mkdir -pv /etc/pacman.d/hooks
  else
    echo "'/etc/pacman.d/hooks' exists"
  fi

  for hook in $(ls "$LOC/etc/pacman.d/hooks"); do
    echo -ne "\033[33;1m ->\033[0m "
    if [[ ! -L "/etc/pacman.d/hooks/$hook" ]]; then
      sudo ln -svf {"$LOC",}/"etc/pacman.d/hooks/$hook"
    else
      echo "'/etc/pacman.d/hooks/$hook' exists"
    fi
  done
  echo

  if [[ $(hash "/etc/skel/.bashrc") != $(hash "$LOC/etc/skel/.bashrc") ]]; then
    sudo rm /etc/skel/.bashrc
    echo -ne "\033[33;1m ->\033[0m "
    sudo cp -v {"$LOC",}/etc/skel/.bashrc
    echo -ne "\033[33;1m ->\033[0m "
    cp -v {"$LOC/etc/skel","$HOME"}/.bashrc
  else
    echo -e "\033[33;1m ->\033[0m '/etc/skel/.bashrc' & '~/.bashrc' already upto date"
  fi
  echo

  echo -ne "\033[33;1m ->\033[0m "
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
      echo -ne "\033[33;1m ->\033[0m "
      sudo ln -svf {"$HOME",/root}/"$file"
    else
      echo -e "\033[33;1m ->\033[0m '/root/$file' exists"
    fi
  done
  echo

  echo -e "\033[33;1mInstalling necessary packages...\033[0m"
  sudo pacman -S --needed --noconfirm intel-media-driver libvdpau-va-gl \
    libva-utils vdpauinfo intel-media-sdk thermald power-profiles-daemon yay 2>/dev/null
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
  echo -ne "\033[33;1m ->\033[0m "
  if [[ ! -L "$HOME/$file" ]]; then
    ln -svf {"$LOC","$HOME"}/"$file"
  else
    echo "'~/$file' exists"
  fi
done
echo

if ! $(grep ". $LOC/.custom.bashrc" $HOME/.bashrc); then
  echo -e "\n# customisations\n\n. $LOC/.custom.bashrc" >>~/.bashrc
  echo -e "\033[33;1m ->\033[0m '~/.bashrc' updated to add customizations"
else
  echo -e "\033[33;1m ->\033[0m '~/.bashrc' already has customizations applied"
fi
echo
