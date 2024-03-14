#!/bin/bash

PASSWORD=""

hash() {
  sha256sum "$1" | cut -d' ' -f1
}

sudo() { 
  command sudo -S "$@" <<<"$PASSWORD"
}

create_cfg_dirs() {
  find . -mindepth 1 -type d \( \
    \( -exec test ! -d "$1/{}" \; \
    -exec mkdir -pv "$1/{}" \; \) \
    -o \
    -exec echo "'$1/{}' exists" \; \
    \)
}

link_cfg_files() {
  find . -mindepth 1 -type f \( \
    \( -exec test ! -L "$2/{}" \; \
    -exec ln -svf "$1/{}" "$2/{}" \; \) \
    -o \
    -exec echo "'$2/{}' exists" \; \
    \)
}

link() {
  # shellcheck disable=SC2088
  if [[ -L "$2" ]]; then
    echo "'$2' exists"
  else
    ln -svf "$1" "$2" 2>/dev/null || sudo ln -svf "$1" "$2"
  fi
}

process_cfgs() {
  # shellcheck disable=SC2164
  pushd "$1" >/dev/null
  create_cfg_dirs "$2"
  link_cfg_files "$1" "$2"
  # shellcheck disable=SC2164
  popd >/dev/null
}

process_root_cfgs() {
  command sudo -S bash -c "$(declare -f process_cfgs create_cfg_dirs link_cfg_files); process_cfgs $1 $2" <<<"$PASSWORD"
}

LOC=$(realpath "$(dirname "$0")")

if [[ "$PREFIX" =~ com.termux ]]; then
  if ! command -v gmake || ! command -v gawk || ! command -v micro; then
    echo -e "\033[33;1m -> \033[0m Installing packages."
    pkg install make gawk micro
  fi
  echo

  if [[ ! -d "$HOME/.local/share/blesh" ]]; then
    echo -e "\033[33;1m -> \033[0m Installing ble.sh"
    git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh "$PREFIX/tmp/ble.sh"
    make -C "$PREFIX/tmp/ble.sh" install PREFIX="$HOME/.local"
    rm -rvf "$PREFIX/tmp/ble.sh"
  else
    echo -e "\033[33;1m -> \033[0m ble.sh already installed"
  fi
  echi

  # shellcheck disable=SC2045
  for file in $(ls "$LOC/termux" --ignore "etc"); do
    echo -ne "\033[33;1m ->\033[0m "
    link {"$LOC/","$HOME/."}"termux/$file"
  done
  termux-reload-settings
  echo

  process_cfgs {"$LOC/termux","$PREFIX"}/"etc"
  echo

  process_cfgs {"$LOC","$HOME"}/".config/micro"
  echo

else
  read -r -p "[sudo] Password: " -s PASSWORD
  echo
  sudo -k
  while ! sudo -S true <<<"$PASSWORD" &>/dev/null; do
    read -r -p "[sudo] Incorrect Password, Try again: " -s PASSWORD
    echo
  done
  echo

  process_cfgs {"$LOC","$HOME"}/".config"
  echo

  for dir in modprobe.d profile.d skel xdg; do
    # shellcheck disable=SC2045
    for file in $(ls -A "$LOC/etc/$dir"); do
      link {"$LOC",}/"etc/$dir/$file"
    done
  done
  echo

  process_root_cfgs {"$LOC",}/"etc/pacman.d/hooks"
  echo

  if [[ $(hash "/etc/skel/.bashrc") != $(hash "$LOC/etc/skel/.bashrc") ]]; then
    sudo rm /etc/skel/.bashrc
    sudo cp -v {"$LOC",}/etc/skel/.bashrc
    cp -v {"$LOC/etc/skel","$HOME"}/.bashrc
  else
    echo -e "'/etc/skel/.bashrc' & '~/.bashrc' already upto date"
  fi
  echo

  if grep -c "MODULES=()" "/etc/mkinitcpio.conf" 1>/dev/null; then
    sudo sed -i 's/MODULES=()/MODULES=(i2c_hid i915)/' /etc/mkinitcpio.conf
    echo "'/etc/mkinitcpio.conf' updated"
    sudo mkinitcpio -P
  else
    echo "'/etc/mkinitcpio.conf' already upto date"
  fi
  echo

  for file in .bashrc .blerc; do
    if sudo test -L "/root/$file"; then
      echo -e "'/root/$file' exists"
    else
      sudo ln -svf {"$HOME",/root}/"$file"
    fi
  done
  echo

  echo -e "\033[33;1mInstalling \033[32;1myay\033[33;1m package manager...\033[0m"
  sudo pacman -S --needed --noconfirm yay 2>/dev/null
  echo

  echo -e "\033[33;1mInstalling necessary packages...\033[0m"
  if yay -Qq | grep -c gnome-desktop &>/dev/null; then
    GNOME_PKGS="gnome-shell-extension-blur-my-shell \
      gnome-shell-extension-just-perfection-desktop gnome-shell-extension-pano firefox-gnome-theme"
  fi
  # shellcheck disable=SC2086
  yay -S --needed --noconfirm discord intel-media-driver libvdpau-va-gl libva-utils \
    vdpauinfo intel-media-sdk thermald power-profiles-daemon micro ttf-firacode-nerd ttf-fira-code \
    blesh-git mkinitcpio-firmware visual-studio-code-bin firefox chromium $GNOME_PKGS 2>/dev/null
  echo

  echo -e "\033[33;1mCustomizing \033[32;1mFirefox\033[33;1m installation...\033[0m"
  FIREFOX_PROFILE="$(find "$HOME/.mozilla/firefox/" -name "*.default-release")"
  cat <<EOF >>"$FIREFOX_PROFILE/prefs.js"
user_pref("widget.gtk.rounded-bottom-corners.enabled", true);
user_pref("widget.use-xdg-desktop-portal.file-picker", 1);
user_pref("widget.use-xdg-desktop-portal.location", 1);
user_pref("widget.use-xdg-desktop-portal.open-uri", 1);
user_pref("widget.use-xdg-desktop-portal.settings", 1);
EOF

  if yay -Qq | grep -c gnome-desktop &>/dev/null; then
    FIREFOX_CHROME_DIR="$FIREFOX_PROFILE/chrome"
    mkdir -p "$FIREFOX_CHROME_DIR"
    link {"/usr/lib","$FIREFOX_CHROME_DIR"}"/firefox-gnome-theme"
    echo '@import "firefox-gnome-theme/userChrome.css";' >"$FIREFOX_CHROME_DIR/userChrome.css"
    echo '@import "firefox-gnome-theme/userContent.css";' >"$FIREFOX_CHROME_DIR/userContent.css"
    link {"$FIREFOX_CHROME_DIR/configuration","$FIREFOX_PROFILE"}"/user.js"

    cat <<EOF >>"$FIREFOX_PROFILE/prefs.js"
user_pref("gnomeTheme.activeTabContrast", true);
user_pref("gnomeTheme.hideSingleTab", false);
user_pref("gnomeTheme.tabsAsHeaderbar", true);
EOF
  fi

  sudo mkdir -pv "/etc/firefox/policies"
  link {"$LOC",}"/etc/firefox/policies/policies.json"
  echo

  echo -e "\033[33;1mCustomizing \033[32;1mChromium\033[33;1m installation...\033[0m"
  sudo mkdir -pv "/etc/chromium/policies"
  link {"$LOC",}"/etc/chromium/policies/managed"
  echo

  sudo systemctl enable --now thermald power-profiles-daemon 2>/dev/null

  sudo update-desktop-database

  if [[ ! -f "$LOC/.firstRunSuccess" ]]; then
    echo -e "\n\033[33;1mManual intervention required.\033[0;1m [OPTIONAL]\033[0m"

    echo -e " \033[31;1m-\033[0m Edit \"\033[34;1m/etc/{fstab,crypttab}\033[0m\" using the previous config files as reference"
    echo -e " \033[31;1m-\033[0m Save your bitlocker key in \"\033[34;1m/etc/cryptsetup-keys.d/*.key\033[0m\" using the previous key file as reference"
    echo -e " \033[31;1m-\033[0m Previous confg files are in \033[34;1metc\033[0m subdir in current dir."

    echo -e "\033[32;1mAutomatic dotfiles sync successful.\033[0m\n"
    touch "$LOC/.firstRunSuccess"
  fi

fi

for file in .blerc .clang-format .gitconfig; do
  link {"$LOC","$HOME"}/"$file"
done
echo

if ! "$(grep "$LOC/.custom.bashrc" "$HOME/.bashrc")"; then
  echo -e "\n# customisations\n\n. $LOC/.custom.bashrc" >>~/.bashrc
  echo -e "'~/.bashrc' updated to add customizations"
else
  echo -e "'~/.bashrc' already has customizations applied"
fi
echo
