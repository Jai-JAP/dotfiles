#!/bin/bash
# shellcheck enable=require-variable-braces

hash() {
  sha256sum "$1" | cut -d' ' -f1
}

hash_equal() {
  [[ -f "$2" && $(hash "$1") == $(hash "$2") ]]
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
  sudo bash -c "$(declare -f process_cfgs create_cfg_dirs link_cfg_files); process_cfgs $1 $2"
}

LOC=$(realpath "$(dirname "$0")")

if [[ ! "${PREFIX}" =~ com.termux ]]; then
  PASSWORD=""
  ATTEMPT=0

  read -r -p "[sudo] Password: " -s PASSWORD
  echo
  sudo -k
  while ! sudo -S true <<<"${PASSWORD}" &>/dev/null; do
    (( ATTEMPT++ ))

    if (( ATTEMPT == 3 )); then
      echo "Maximum attempts reached. Exiting." >&2
      exit 1
    fi

    read -r -p "[sudo] Incorrect Password, Try again: " -s PASSWORD
    echo
  done
  echo

  sudo() {
    command sudo -S "$@" <<<"${PASSWORD}"
  }
fi

config_common() {
  if ! type sudo &>/dev/null; then
    sudo() { "$@"; }
  fi

  if [[ -f "${PREFIX}"/etc/skel/.bash_profile ]]; then
    echo "'/etc/skel/.bash_profile' exists"
  else
    echo -e "#\n# ~/.bash_profile\n#\n\n[[ -f ~/.bashrc ]] && . ~/.bashrc\n" | sudo tee "${PREFIX}"/etc/skel/.bash_profile >/dev/null
  fi
  echo

  if hash_equal {"${LOC}","${PREFIX}"}/etc/skel/.bashrc; then
    echo "'/etc/skel/.bashrc' & '~/.bashrc' already upto date"
  else
    sudo rm /etc/skel/.bashrc
    sudo cp -v {"${LOC}",}/etc/skel/.bashrc
    cp -v {"${LOC}"/etc/skel,"${HOME}"}/.bashrc
    echo "'/etc/skel/.bashrc' & '~/.bashrc' updated successfully"
  fi
  echo

  if grep -q "${LOC}/.custom.bashrc" "${HOME}"/.bashrc; then
    echo -e "'~/.bashrc' already has customizations applied"
  else
    echo -e "\n# customisations\n\n# shellcheck disable=SC1091\n. \"${LOC}/.custom.bashrc\"" >>~/.bashrc
    echo -e "'~/.bashrc' updated to add customizations"
  fi
  echo

  for file in .blerc .gitconfig; do
    link {"${LOC}","${HOME}"}/"${file}"
  done
  echo
}

pkgs_to_install() {
    local installed
    mapfile -t installed < <(paru -Qq "$@" 2>/dev/null)
    installed+=("$@")
    printf "%s\n" "${installed[@]}" | sort | uniq -u
}

if [[ "${PREFIX}" =~ com.termux ]]; then
  echo -e "\e[33;1m -> \e[0m Installing packages."
  pkg update
  pkg install -y make gawk micro eza bat bash-completion command-not-found
  echo

  if [[ ! -d "${HOME}"/.local/share/blesh ]]; then
    echo -e "\e[33;1m -> \e[0m Installing ble.sh"
    git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh "${PREFIX}"/tmp/ble.sh
    make -C "${PREFIX}"/tmp/ble.sh install PREFIX="${HOME}/.local"
    rm -rf "${PREFIX}"/tmp/ble.sh
  else
    echo -e "\e[33;1m -> \e[0m ble.sh already installed"
  fi
  echo

  if [[ ! -d "${HOME}"/.local/share/bash-complete-alias ]]; then
    echo -e "\e[33;1m -> \e[0m Installing bash-complete-alias"
    git clone --depth 1 https://github.com/cykerway/complete-alias "${HOME}"/.local/share/bash-complete-alias
  else
    echo -e "\e[33;1m -> \e[0m bash-complete-alias already installed"
  fi
  echo

  config_common

  # shellcheck disable=SC2045
  for file in $(ls "${LOC}"/termux --ignore "etc"); do
    echo -ne "\e[33;1m ->\e[0m "
    link {"${LOC}/","${HOME}/."}termux/"${file}"
  done
  termux-reload-settings
  echo

  process_cfgs {"${LOC}"/termux,"${PREFIX}"}/etc
  echo

  process_cfgs {"${LOC}","${HOME}"}/.config/micro
  echo

else
  config_common

  process_cfgs {"${LOC}","${HOME}"}/.config
  echo

  process_root_cfgs {"${LOC}",/root}/.config/micro
  echo

  for dir in bluetooth makepkg.conf.d modprobe.d modules-load.d pacman.d/hooks profile.d udev wireplumber xdg; do
    process_root_cfgs {"${LOC}",}/etc/"${dir}"
  done
  for file in tlp.conf makepkg.conf paru.conf; do
    link {"${LOC}",}/etc/"${file}"
  done

  sudo sed -i '/^EDITOR=/s/=.*/=micro/g' /etc/environment
  sudo sed -i -e '/Color/s/^#[[:space:]]//' \
    -e '/VerbosePkgLists/s/^#[[:space:]]//' \
    -e '/ILoveCandy/s/^/# /' \
    -e '/CheckSpace/s/^#[[:space:]]//' \
    -e '/ParallelDownloads/s/^#[[:space:]]//' \
    -e '/ParallelDownloads = /s/= ./= 8/' /etc/pacman.conf

  # if sudo grep "^#\+[[:space:]]*Defaults pwfeedback" /etc/sudoers &>/dev/null; then
  #   sudo sed -i '/Defaults pwfeedback/s/^#*[[:space:]]*//' /etc/sudoers
  #   echo -e "Enabled password feedback for sudo prompt.\n"
  # elif [[ ! -f /etc/sudoers.d/0_pwfeedback ]]; then
  #   echo -e "##\n## Enable Password Feeback with asterisks (*)\n##\n\nDefaults pwfeedback\n" | sudo tee /etc/sudoers.d/0_pwfeedback >/dev/null
  #   echo -e "Enabled password feedback for sudo prompt.\n"
  # else
  #   echo -e "Password feedback for sudo prompt already enabled."
  # fi

  if command -v mkinitcpio &>/dev/null; then
    if grep -c "MODULES=()" "/etc/mkinitcpio.conf" 1>/dev/null; then
      sudo sed -i 's/MODULES=()/MODULES=( i2c_hid i915 )/' /etc/mkinitcpio.conf
      echo "'/etc/mkinitcpio.conf' updated"
      sudo mkinitcpio -P
    else
      echo "'/etc/mkinitcpio.conf' already upto date"
    fi
    MKINITCPIO_PKGS=( mkinitcpio-firmware )
    echo
  elif command -v dracut &>/dev/null; then
    if [[ -f /etc/dracut.conf.d/custom.conf ]]; then
      echo "'/etc/dracut.conf.d/custom.conf' exists"
    else
      echo -e "omit_dracutmodules+=\" qemu qemu-net \"\nforce_drivers+=\" i915 \"\n" | sudo tee /etc/dracut.conf.d/custom.conf >/dev/null
      echo "'/etc/dracut.conf.d/custom.conf' created"
    fi
  fi

  if ! lspci | awk '/VGA/ && /Intel/ {found=1} END {exit !found}'; then
    sudo rm -fv /etc/{profile.d/hwaccel.sh,modprobe.d/i915.conf}
    sudo sed -i -e "/MODULES=(/s/ i915//g" -e '/MODULES=([[:space:]])/d' /etc/mkinitcpio.conf
    sudo sed -i -e '/force_drivers+=/s/ i915//g' -e '/force_drivers+="[[:space:]]"/d' /etc/dracut.conf.d/custom.conf
  fi
  echo

  for file in .bashrc .blerc; do
    if sudo test -L /root/"${file}" && sudo test -e /root/"${file}"; then
      echo -e "'/root/${file}' exists"
    else
      sudo ln -svf {"${HOME}",/root}/"${file}"
    fi
  done
  echo

  echo -e "\e[33;1mInstalling \e[32;1mparu\e[33;1m package manager...\e[0m"
  if ! sudo pacman -S --needed --noconfirm paru 2>/dev/null; then
    sudo git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
    # shellcheck disable=SC2164
    pushd /tmp/paru-bin >/dev/null
    makepkg -si --needed --noconfirm
    # shellcheck disable=SC2164
    popd >/dev/null
    sudo rm -rf /tmp/paru-bin
  fi
  echo

  echo -e "\e[33;1mInstalling necessary packages...\e[0m"
  if paru -Qq | grep -c gnome-desktop &>/dev/null; then
    GNOME_PKGS=( adw-gtk-theme papirus-icon-theme bibata-cursor-theme firefox-gnome-theme \
        kvantum-theme-libadwaita-git libgda6 webp-pixbuf-loader gnome-extensions-cli )
  fi
  mapfile -t PKGS < <( pkgs_to_install ghostty fzf yazi eza micro wl-clipboard bat git-delta \
      jq blesh-git bash-complete-alias visual-studio-code-bin refind intel-media-{driver,sdk} \
      libva-{intel-driver,utils} libvdpau-va-gl vdpauinfo vulkan-{intel,mesa-layers,tools} \
      firefox chromium ttf-{fira-code,nerd-fonts-symbols{,-mono}} {pipewire,gst-plugin}-libcamera \
      thermald tlp{,-rdw} kvantum{,-qt5} qt{5,6}ct kanata-bin "${GNOME_PKGS[@]}" "${MKINITCPIO_PKGS[@]}" )
  paru -Syu --needed --noconfirm "${PKGS[@]}"
  echo

  if systemctl --user is-active kanata &>/dev/null; then
    echo -e "\e[32;1mMOD-TAP is already setup on CAPS_LOCK.\e[0m"
  else
    echo -e "\e[33;1mSetting MOD-TAP on CAPS_LOCK using Kanata.\e[0m"
    sudo groupadd uinput
    sudo usermod -aG input "${USER}"
    sudo usermod -aG uinput "${USER}"
    echo "- Added user '${USER}' to groups 'input', 'uinput'"
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    echo "- udev rules reloaded successfully."
    systemctl --user daemon-reload
    systemctl --user enable kanata
    systemctl --user start kanata
    if systemctl --user is-active kanata &>/dev/null; then
      echo -e "- \e[32mKanata service started.\n\e[0m"
      echo -e "- \e[32mMOD-TAP on CAPS_LOCK setup succesfully.\e[0m"
    else
      echo -e "- \e[31mUnable to start kanata service.\e[0m"
    fi
  fi
  echo

  if paru -Qq | grep -c gnome-desktop &>/dev/null; then
    echo -e "\e[33;1mCustomizing \e[32;1mGnome\e[33;1m installation...\e[0m"
# apps-menu@gnome-shell-extensions.gcampax.github.com
# arcmenu@arcmenu.com
# auto-move-windows@gnome-shell-extensions.gcampax.github.com
# custom-accent-colors@demiskp
# dash-to-panel@jderose9.github.com
# drive-menu@gnome-shell-extensions.gcampax.github.com
# forge@jmmaranan.com
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
        appindicatorsupport@rgcjonas.gmail.com \
        blur-my-shell@aunetx \
        dash-to-dock@micxgx.gmail.com \
        gnome-ui-tune@itstime.tech \
        gsconnect@andyholmes.github.io \
        just-perfection-desktop@just-perfection \
        legacyschemeautoswitcher@joshimukul29.gmail.com \
        pano@elhan.io \
        unblank@sun.wxg@gmail.com \
        Vitals@CoreCoding.com \
        rounded-window-corners@fxgn \
        quick-settings-tweaks@qwreey

    echo -e "\e[33;1mRestoring dconf settings\e[0m"
    # dconf reset -f /
    dconf load /org/ <<< "$(sed 's|%HOME%|'"${HOME}"'|g' "${LOC}"/etc/dconf-settings.ini)"
    echo
  fi

  echo -e "\e[33;1mCustomizing User logo\e[0m"
  if sudo bash -c "$(declare -f hash_equal); hash_equal \"${LOC}\"/icon.* /var/lib/AccountsService/icons/\"${USER}\""; then
    echo -e "User logo already setup\n"
  else
    sudo cp -v "${LOC}"/icon.* /var/lib/AccountsService/icons/"${USER}"
    echo -e "[User]\nLanguages=${LANG};\nSession=\nIcon=/var/lib/AccountsService/icons/${USER}\nSystemAccount=false\n" | sudo tee /var/lib/AccountsService/users/"${USER}"
    echo -e "\e[32;1mUser logo set successfully\e[0m\n"
  fi

  echo -e "\e[33;1mCustomizing Bootscreen\e[0m"
  if sudo bash -c "$(declare -f hash_equal); hash_equal \"${LOC}\"/refind/refind.conf /boot/efi/EFI/refind/refind.conf" && sudo test -d /boot/efi/EFI/refind/themes/refind-theme-regular; then
    echo "Bootscreen customisations already applied."
  else
    sudo refind-install
    sudo cp -v {"${LOC}",/boot/efi/EFI}/refind/refind.conf
    sudo cp -v {"${LOC}"/refind,/boot}/refind_linux.conf
    ROOT_DEV="$(mount | grep 'on / ' | cut -d' ' -f1)"
    ROOT_UUID="$(sudo -S blkid "${ROOT_DEV}" -s UUID -o value <<<"${PASSWORD}")"
    sudo sed -i 's|root=UUID=|&'"${ROOT_UUID}"'|g' /boot/refind_linux.conf
    sudo sed -i 's|ro root=|&'"${ROOT_DEV}"'|g' /boot/refind_linux.conf
    echo

    # shellcheck disable=SC2164
    pushd "${HOME}"/.cache/paru/clone >/dev/null
    paru -G refind-theme-regular-git
    # shellcheck disable=SC2164
    pushd refind-theme-regular-git >/dev/null
    sed -i 's|/boot/EFI|/boot/efi/EFI/|' ./PKGBUILD
    if ! git diff --quiet HEAD -- . ':PKGBUILD'; then
      git commit -am "Fix refind_home path"
    fi
    paru -S refind-theme-regular-git --noredownload --noconfirm
    # shellcheck disable=SC2164
    popd >/dev/null
    # shellcheck disable=SC2164
    popd >/dev/null
  fi
  echo

  echo -e "\e[33;1mCustomizing \e[32;1mFirefox\e[33;1m installation...\e[0m"
  if pgrep firefox >/dev/null; then
    echo -ne " - \e[33;1mFirefox currently running. Save your work and press ENTER to continue.\e[0m"
    read -r
    killall firefox 2>/dev/null
  fi

  while IFS= read -r FIREFOX_PROFILE; do
    if paru -Qq | grep -c gnome-desktop &>/dev/null; then
      FIREFOX_CHROME_DIR="${FIREFOX_PROFILE}"/chrome
      mkdir -p "${FIREFOX_CHROME_DIR}"
      link {/usr/lib,"${FIREFOX_CHROME_DIR}"}/firefox-gnome-theme
      for file in userChrome.css userContent.css; do
        if [[ -f "${FIREFOX_CHROME_DIR}/${file}" ]]; then
          echo "'${FIREFOX_CHROME_DIR}/${file}' exists"
        else
          echo "@import \"firefox-gnome-theme/${file}\";" >"${FIREFOX_CHROME_DIR}/${file}"
        fi
      done
      cp {"${FIREFOX_CHROME_DIR}"/firefox-gnome-theme/configuration,"${FIREFOX_PROFILE}"}/user.js

      cat <<EOF >>"${FIREFOX_PROFILE}"/user.js

user_pref("gnomeTheme.activeTabContrast", true);
user_pref("gnomeTheme.hideSingleTab", false);
user_pref("gnomeTheme.tabsAsHeaderbar", true);
user_pref("gnomeTheme.hideWebrtcIndicator", true)
EOF
    fi

    cat <<EOF >>"${FIREFOX_PROFILE}"/user.js

user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[\"sponsorblocker_ajay_app-browser-action\",\"ublock0_raymondhill_net-browser-action\",\"idcac-pub_guus_ninja-browser-action\",\"addon_darkreader_org-browser-action\"],\"nav-bar\":[\"back-button\",\"forward-button\",\"stop-reload-button\",\"urlbar-container\",\"downloads-button\",\"unified-extensions-button\"],\"toolbar-menubar\":[\"menubar-items\"],\"TabsToolbar\":[\"firefox-view-button\",\"tabbrowser-tabs\",\"new-tab-button\",\"alltabs-button\"],\"PersonalToolbar\":[\"import-button\",\"personal-bookmarks\"]},\"seen\":[\"save-to-pocket-button\",\"developer-button\",\"idcac-pub_guus_ninja-browser-action\",\"ublock0_raymondhill_net-browser-action\",\"sponsorblocker_ajay_app-browser-action\",\"addon_darkreader_org-browser-action\"],\"dirtyAreaCache\":[\"nav-bar\",\"PersonalToolbar\",\"unified-extensions-area\",\"toolbar-menubar\",\"TabsToolbar\"],\"currentVersion\":20,\"newElementCount\":4}");
user_pref("widget.gtk.rounded-bottom-corners.enabled", true);
user_pref("widget.use-xdg-desktop-portal.file-picker", 1);
user_pref("widget.use-xdg-desktop-portal.location", 1);
user_pref("widget.use-xdg-desktop-portal.open-uri", 1);
user_pref("widget.use-xdg-desktop-portal.settings", 1);
user_pref("media.webrtc.camera.allow-pipewire", true);
EOF

    echo -e " - Customizations applied to ${FIREFOX_PROFILE##*/}\n"
  done < <(awk -F'=' -e '$0 ~ /\[Profile[[:digit:]]+\]/ { f=1; next } /\[/{ f=0; next } f && $1=="Path"{ print "'"${HOME}"'/.mozilla/firefox/"$2 }' \
              "${HOME}"/.mozilla/firefox/profiles.ini)

  sudo mkdir -pv /etc/firefox/policies
  link {"${LOC}",}/etc/firefox/policies/policies.json
  echo

  echo -e "\e[33;1mCustomizing \e[32;1mChromium\e[33;1m installation...\e[0m"
  sudo mkdir -pv /etc/chromium/policies
  link {"${LOC}",}/etc/chromium/policies/managed

  systemctl --user stop wireplumber -q
  systemctl --user stop pipewire -q
  systemctl --user start wireplumber -q

  sudo systemctl enable --now thermald tlp 2>/dev/null

  sudo update-desktop-database

  if [[ ! -f "${LOC}"/.firstRunSuccess ]]; then
    echo
    echo -e "\n\e[33;1mManual intervention required.\e[0;1m [OPTIONAL]\e[0m"

    echo -e " \e[31;1m-\e[0m Edit \"\e[34;1m/etc/{fstab,crypttab}\e[0m\" using the previous config files as reference"
    echo -e " \e[31;1m-\e[0m Save your bitlocker key in \"\e[34;1m/etc/cryptsetup-keys.d/*.key\e[0m\" using the previous key file as reference"
    echo -e " \e[31;1m-\e[0m Previous confg files are in \e[34;1metc\e[0m subdir in current dir."

    echo -e "\e[32;1mAutomatic dotfiles sync successful.\e[0m\n"
    touch "${LOC}"/.firstRunSuccess
  fi

fi
