#!/bin/bash


hash() {
  sha256sum "$1" | cut -d' ' -f1
}

create_cfg_dirs() {
  find . -mindepth 1 -type d \( \
    \( -exec test -d "$1/{}" \; \
    -exec echo "'$1/{}' exists" \; \) \
    -o \
    -exec mkdir -pv "$1/{}" \; \
    \)
}

link_cfg_files() {
  find . -mindepth 1 -type f \( \
    \( -exec test -L "$2/{}" \; -a -exec test -e "$2/{}" \; \
    -exec echo "'$2/{}' exists" \; \) \
    -o \
    -exec ln -svf "$1/{}" "$2/{}" \; \
    \)
}

link() {
  # shellcheck disable=SC2088
  if [[ -L "$2" && -e "$2" ]]; then
    echo "'$2' exists"
  else
    ln -svf "$1" "$2" 2>/dev/null || sudo ln -svf "$1" "$2"
  fi
}

process_cfgs() {
  mkdir -pv "$2"
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

config_common() {
  for file in .blerc .clang-format .gitconfig; do
    link {"$LOC","$HOME"}/"$file"
  done
  echo

  if grep -q "$LOC/.custom.bashrc" "$HOME/.bashrc"; then
    echo -e "'~/.bashrc' already has customizations applied"
  else
    echo -e "\n# customisations\n\n. \"$LOC/.custom.bashrc\"" >>~/.bashrc
    echo -e "'~/.bashrc' updated to add customizations"
  fi
}

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
    rm -rf "$PREFIX/tmp/ble.sh"
  else
    echo -e "\033[33;1m -> \033[0m ble.sh already installed"
  fi
  echo

  config_common

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
  PASSWORD=""

  read -r -p "[sudo] Password: " -s PASSWORD
  echo
  sudo -k
  while ! sudo -S true <<<"$PASSWORD" &>/dev/null; do
    read -r -p "[sudo] Incorrect Password, Try again: " -s PASSWORD
    echo
  done
  echo

  sudo() {
    command sudo -S "$@" <<<"$PASSWORD"
  }

  config_common

  process_cfgs {"$LOC","$HOME"}/".config"
  process_root_cfgs {"$LOC","/root"}/".config/micro"
  echo

  for dir in modprobe.d profile.d xdg; do
    process_root_cfgs {"$LOC",}/"etc/$dir"
  done
  if ! lspci | awk '/VGA/ && /Intel/ {found=1} END {exit !found}'; then
    sudo rm -fv "/etc"/{"profile.d/hwaccel.sh","modprobe.d/i915.conf"}
  fi
  for file in tlp.conf makepkg.conf paru.conf; do
    link {"$LOC",}/"etc/$file"
  done
  echo

  sudo sed -i '/^EDITOR=/s/=.*/=micro/g' /etc/environment
  process_root_cfgs {"$LOC",}/"etc/pacman.d/hooks"
  sudo sed -i -e '/Color/s/^#[[:space:]]//' \
    -e '/ILoveCandy/s/^/#/' \
    -e '/CheckSpace/s/^#[[:space:]]//' \
    -e '/ParallelDownloads/s/^#[[:space:]]//' \
    -e '/ParallelDownloads = /s/= ./= 8/' /etc/pacman.conf
  echo

  if [[ -f "/etc/skel/.bash_profile" ]]; then
    echo "'/etc/skel/.bash_profile' exists"
  else
    echo -e "#\n# ~/.bash_profile\n#\n\n[[ -f ~/.bashrc ]] && . ~/.bashrc\n" | sudo tee "/etc/skel/.bash_profile" >/dev/null
  fi

  if [[ $(hash "/etc/skel/.bashrc") != $(hash "$LOC/etc/skel/.bashrc") || ! -f "/etc/skel/.bashrc" ]]; then
    sudo rm /etc/skel/.bashrc
    sudo cp -v {"$LOC",}/etc/skel/.bashrc
    cp -v {"$LOC/etc/skel","$HOME"}/.bashrc
  else
    echo "'/etc/skel/.bashrc' & '~/.bashrc' already upto date"
  fi
  echo

  if command -v mkinitcpio &>/dev/null; then
    if grep -c "MODULES=()" "/etc/mkinitcpio.conf" 1>/dev/null; then
      sudo sed -i 's/MODULES=()/MODULES=(i2c_hid i915)/' /etc/mkinitcpio.conf
      echo "'/etc/mkinitcpio.conf' updated"
      sudo mkinitcpio -P
    else
      echo "'/etc/mkinitcpio.conf' already upto date"
    fi
    MKINITCPIO_PKGS="mkinitcpio-firmware"
    echo
  elif command -v dracut &>/dev/null; then
    if [[ -f "/etc/dracut.conf.d/custom.conf" ]]; then
      echo "'/etc/dracut.conf.d/custom.conf' exists"
    else
      command sudo -S bash -c 'echo -e "omit_dracutmodules+=\" btrfs btrfs-snapshot-overlay qemu qemu-net \"\nadd_drivers+=\" i915 \"" > "/etc/dracut.conf.d/custom.conf"' <<<"$PASSWORD"
    fi
  fi

  for file in .bashrc .blerc; do
    if sudo test -L "/root/$file" && sudo test -e "/root/$file"; then
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
    GNOME_PKGS="firefox-gnome-theme libgda6 adw-gtk3 papirus-icon-theme bibata-cursor-theme valent-git \
      gnome-shell-extension-valent-git kvantum kvantum-qt5 kvantum-theme-libadwaita-git qt5ct qt6ct"
  fi
  # shellcheck disable=SC2086
  yay -Syu --needed --noconfirm jq micro wl-clipboard intel-media-driver intel-media-sdk \
    libva-intel-driver libva-utils vdpauinfo vulkan-intel vulkan-mesa-layers vulkan-tools \
    thermald tlp tlp-rdw ttf-firacode-nerd ttf-fira-code blesh-git visual-studio-code-bin \
    firefox chromium refind gnome-extensions-cli python-tqdm $GNOME_PKGS $MKINITCPIO_PKGS
  echo

  if yay -Qq | grep -c gnome-desktop &>/dev/null; then
    echo -e "\033[33;1mCustomizing \033[32;1mGnome\033[33;1m installation...\033[0m"
# apps-menu@gnome-shell-extensions.gcampax.github.com
# arcmenu@arcmenu.com
# auto-move-windows@gnome-shell-extensions.gcampax.github.com
# custom-accent-colors@demiskp
# dash-to-panel@jderose9.github.com
# drive-menu@gnome-shell-extensions.gcampax.github.com
# forge@jmmaranan.com
# gsconnect@andyholmes.github.io
# gtk4-ding@smedius.gitlab.com
# launch-new-instance@gnome-shell-extensions.gcampax.github.com
# native-window-placement@gnome-shell-extensions.gcampax.github.com
# pamac-updates@manjaro.org
# places-menu@gnome-shell-extensions.gcampax.github.com
# screenshot-window-sizer@gnome-shell-extensions.gcampax.github.com
# space-bar@luchrioh
# user-theme@gnome-shell-extensions.gcampax.github.com
# window-list@gnome-shell-extensions.gcampax.github.com
# windowsNavigator@gnome-shell-extensions.gcampax.github.com
# workspace-indicator@gnome-shell-extensions.gcampax.github.com
# x11gestures@joseexposito.github.io
# light-style@gnome-shell-extensions.gcampax.github.com

    gext install \
      just-perfection-desktop@just-perfection \
      Vitals@CoreCoding.com \
      unblank@sun.wxg@gmail.com \
      pano@elhan.io \
      blur-my-shell@aunetx \
      appindicatorsupport@rgcjonas.gmail.com \
      dash-to-dock@micxgx.gmail.com \
      gnome-ui-tune@itstime.tech \
      legacyschemeautoswitcher@joshimukul29.gmail.com 
    
    echo -e "\033[33;1mRestoring dconf settings\033[0m"
    # dconf reset -f /
    dconf load /org/ <<< "$(sed 's|/home/jaiap|'"$HOME"'|g' "$LOC/etc/settings.dconf")"
    echo
  fi

  echo -e "\033[33;1mCustomizing User logo\033[0m"
  if sudo test -f "/var/lib/AccountsService/icons/$USER" && [[ $(hash "/var/lib/AccountsService/icons/$USER") == $(hash "$LOC"/icon.*) ]] ; then
    echo -e "User logo already setup\n"
  else
    sudo cp -v "$LOC"/icon.* "/var/lib/AccountsService/icons/$USER"
    command sudo -S bash -c 'echo -e "[User]\nLanguages=$LANG;\nSession=\nIcon=/var/lib/AccountsService/icons/${SUDO_USER}\nSystemAccount=false" > "/var/lib/AccountsService/users/${SUDO_USER}"' <<<"$PASSWORD"
    echo -e "\033[32;1mUser logo set successfully\033[0m\n"
  fi
  
  echo -e "\033[33;1mCustomizing Bootscreen\033[0m"
  if sudo test -d "/boot/efi/EFI/refind/themes/refind-theme-regular"; then
    echo "Bootscreen customisations already applied."
  else 
    sudo refind-install
    sudo cp -v {"$LOC","/boot/efi/EFI"}/"refind/refind.conf"
    sudo cp -v {"$LOC/refind","/boot"}/"refind_linux.conf"
    ROOT_DEV="$(mount | grep 'on / ' | cut -d' ' -f1)"
    ROOT_UUID="$(sudo -S blkid "$ROOT_DEV" -s UUID -o value <<<"$PASSWORD")"
    sudo sed -i 's|root=UUID=|&'"$ROOT_UUID"'|g' "/boot/refind_linux.conf"
    sudo sed -i 's|ro root=|&'"$ROOT_DEV"'|g' "/boot/refind_linux.conf"
    echo
    
    # shellcheck disable=SC2164
    pushd "$HOME/.cache/yay" >/dev/null
    yay -G refind-theme-regular-git && sed -i 's|/boot/EFI|/boot/efi/EFI/|' ./refind-theme-regular-git/PKGBUILD
    # shellcheck disable=SC2164
    pushd "refind-theme-regular-git" >/dev/null
    if ! git diff --quiet HEAD -- . ':PKGBUILD'; then
      git commit -am "Fix refind_home path"
    fi
    yay -S refind-theme-regular-git --noredownload --noconfirm
    # shellcheck disable=SC2164
    popd >/dev/null
    # shellcheck disable=SC2164
    popd >/dev/null
  fi
  echo

  echo -e "\033[33;1mCustomizing \033[32;1mFirefox\033[33;1m installation...\033[0m"
  if pgrep firefox >/dev/null; then
    echo -ne " - \033[33;1mFirefox currently running. Save your work and press ENTER to continue.\033[0m"
    read -r
    killall firefox
  fi

  while IFS= read -r FIREFOX_PROFILE; do
    cat <<EOF >>"$FIREFOX_PROFILE/prefs.js"
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[\"sponsorblocker_ajay_app-browser-action\",\"ublock0_raymondhill_net-browser-action\",\"idcac-pub_guus_ninja-browser-action\",\"addon_darkreader_org-browser-action\"],\"nav-bar\":[\"back-button\",\"forward-button\",\"stop-reload-button\",\"urlbar-container\",\"downloads-button\",\"unified-extensions-button\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[\"firefox-view-button\",\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"PersonalToolbar\":[\"import-button\",\"personal-bookmarks\"]},\"seen\":[\"save-to-pocket-button\",\"developer-button\",\"idcac-pub_guus_ninja-browser-action\",\"ublock0_raymondhill_net-browser-action\",\"sponsorblocker_ajay_app-browser-action\",\"addon_darkreader_org-browser-action\"],\"dirtyAreaCache\":[\"nav-bar\",\"PersonalToolbar\",\"unified-extensions-area\",\"toolbar-menubar\",\"TabsToolbar\"],\"currentVersion\":20,\"newElementCount\":4}");
user_pref("widget.gtk.rounded-bottom-corners.enabled", true);
user_pref("widget.use-xdg-desktop-portal.file-picker", 1);
user_pref("widget.use-xdg-desktop-portal.location", 1);
user_pref("widget.use-xdg-desktop-portal.open-uri", 1);
user_pref("widget.use-xdg-desktop-portal.settings", 1);
EOF

    if yay -Qq | grep -c gnome-desktop &>/dev/null; then
      FIREFOX_CHROME_DIR="$FIREFOX_PROFILE/chrome"
      mkdir -p "$FIREFOX_CHROME_DIR"
      link {"/usr/lib","$FIREFOX_CHROME_DIR"}/"firefox-gnome-theme"
      for file in userChrome.css userContent.css; do
        if [[ -f "$FIREFOX_CHROME_DIR/$file" ]]; then
          echo "'$FIREFOX_CHROME_DIR/$file' exists"
        else
          echo "@import \"firefox-gnome-theme/$file\";" >"$FIREFOX_CHROME_DIR/$file"
        fi
      done
      link {"$FIREFOX_CHROME_DIR/firefox-gnome-theme/configuration","$FIREFOX_PROFILE"}/"user.js"

      cat <<EOF >>"$FIREFOX_PROFILE/prefs.js"
user_pref("gnomeTheme.activeTabContrast", true);
user_pref("gnomeTheme.hideSingleTab", false);
user_pref("gnomeTheme.tabsAsHeaderbar", true);
user_pref("gnomeTheme.hideWebrtcIndicator", true)
EOF
    fi

    echo -e " - Customizations applied to ${FIREFOX_PROFILE##*/}\n"
  done < <(awk -F'=' -e '$0 ~ /\[Profile[[:digit:]]+\]/ { f=1; next } /\[/{ f=0; next } f && $1=="Path"{ print "'"$HOME"'/.mozilla/firefox/"$2 }' "$HOME/.mozilla/firefox/profiles.ini")

  sudo mkdir -pv "/etc/firefox/policies"
  link {"$LOC",}/"etc/firefox/policies/policies.json"
  echo

  echo -e "\033[33;1mCustomizing \033[32;1mChromium\033[33;1m installation...\033[0m"
  sudo mkdir -pv "/etc/chromium/policies"
  link {"$LOC",}/"etc/chromium/policies/managed"
  echo

  sudo systemctl enable --now thermald tlp 2>/dev/null

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
