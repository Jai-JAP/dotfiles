#!/bin/bash
# shellcheck enable=require-variable-braces

hash() {
  sha256sum "$1" | cut -d' ' -f1
}

hash_equal() {
  [[ -f "$2" && $(hash "$1") == $(hash "$2") ]]
}

create_cfg_dirs() {
  local target_dir
  target_dir=$1
  # shellcheck disable=SC2016
  find . -mindepth 1 -type d \( \
    \( -exec test -d "${target_dir}/{}" \; \
    -exec sh -c 'echo " - '\''$1'\'' exists" >&2' _ "${target_dir}"/{} \; \) \
    -o \
    -exec sh -c 'echo -n ' - ' && mkdir -pv "$1"' _ "${target_dir}"/{} \; \
    \)
}

link_cfg_files() {
  local target_dir
  target_dir=$1
  # shellcheck disable=SC2016
  find . -mindepth 1 -type f \( \
    \( -exec test -L "${target_dir}/{}" \; -a \
    -exec test -e "${target_dir}/{}" \; \
    -exec sh -c 'echo " - '\''$1'\'' exists" >&2' _ "${target_dir}"/{} \; \) \
    -o \
    -exec sh -c 'echo -n " - " && ln -svf "$1" "$2"' _ "${PWD}"/{} "${target_dir}"/{} \; \
    \)
}

link() {
  if [[ -L "$2" && -e "$2" ]]; then
    echo " - '$2' exists" >&2
  else
    echo -n " - "
    ln -svf "$1" "$2" 2>/dev/null || sudo ln -svf "$1" "$2"
  fi
}

copy() {
  echo -n " - "
  if [[ -w "$2" || -w "$(dirname "$2")" ]]; then
    cp -v "$1" "$2" 2>/dev/null
  else
    sudo cp -v "$1" "$2" 2>/dev/null
  fi
}

makedir() {
  if [[ -d "$1" ]]; then
    echo " - '$1' exists" >&2
  else
    echo -n " - "
    mkdir -pv "$1" 2>/dev/null || sudo mkdir -pv "$1"
  fi
}

process_cfgs() {
  makedir "$2"
  # shellcheck disable=SC2164
  pushd "$1" >/dev/null
  create_cfg_dirs "$2"
  link_cfg_files "$2"
  echo >&2
  # shellcheck disable=SC2164
  popd >/dev/null
}

process_root_cfgs() {
  sudo bash -c "$(declare -f process_cfgs create_cfg_dirs link_cfg_files makedir); process_cfgs $1 $2"
}

LOC=$(realpath "$(dirname "$0")")

if [[ ! "${PREFIX}" =~ com.termux ]]; then
  PASSWORD=""
  ATTEMPT=0

  faillock --reset
  read -r -p "[sudo] Password: " -s PASSWORD
  echo
  sudo -k
  while ! sudo -S true <<<"${PASSWORD}" &>/dev/null; do
    ((ATTEMPT++))

    if ((ATTEMPT == 3)); then
      echo "Maximum attempts reached. Exiting." >&2
      exit 1
    fi

    read -r -p "[sudo] Incorrect Password, Try again: " -s PASSWORD
    echo
  done
  echo -ne "\e[A\e[2K"

  sudo() {
    command sudo -S "$@" <<<"${PASSWORD}"
  }
fi

if [[ "$*" =~ -q ]]; then
  exec 3<>"${PREFIX}"/tmp/bootstrap.stderr
  exec 2>&3
fi

config_common() {
  if ! type sudo &>/dev/null; then
    sudo() { "$@"; }
  fi

  echo -e "\e[33;1m-> Linking all config files.\e[0m"

  makedir "${PREFIX}"/etc/skel

  if [[ -f "${PREFIX}"/etc/skel/.bash_profile ]]; then
    echo -e " - '${PREFIX}/etc/skel/.bash_profile' exists" >&2
  else
    echo -e "#\n# ~/.bash_profile\n#\n\n[[ -f ~/.bashrc ]] && . ~/.bashrc\n" | sudo tee "${PREFIX}"/etc/skel/.bash_profile >/dev/null
    echo -e " - '${PREFIX}/etc/skel/.bash_profile' created."
  fi

  if [[ -f "${HOME}"/.bash_profile ]]; then
    echo -e " - '~/.bash_profile' exists" >&2
  else
    copy {"${PREFIX}/etc/skel","${HOME}"}/.bash_profile
  fi

  echo >&2

  local custom_bashrc
  custom_bashrc="\n# customisations\n\n# shellcheck disable=SC1091\n. \"${LOC}/.custom.bashrc\""

  local tmp_bashrc
  tmp_bashrc=$(mktemp)
  cp "${LOC}"/etc/skel/.bashrc "${tmp_bashrc}"
  echo -e "${custom_bashrc}" | tee -a "${tmp_bashrc}" &>/dev/null

  if hash_equal {"${LOC}","${PREFIX}"}/etc/skel/.bashrc && hash_equal "${HOME}"/.bashrc "${tmp_bashrc}"; then
    echo -e " - '${PREFIX}/etc/skel/.bashrc' & '~/.bashrc' already upto date\n" >&2
    rm "${tmp_bashrc}"
  else
    sudo rm "${PREFIX}"/etc/skel/.bashrc "${tmp_bashrc}"
    copy {"${LOC}","${PREFIX}"}/etc/skel/.bashrc
    copy {"${LOC}"/etc/skel,"${HOME}"}/.bashrc
    echo -e " - '${PREFIX}/etc/skel/.bashrc' & '~/.bashrc' updated successfully\n"
  fi

  if grep -q "${LOC}/.custom.bashrc" "${HOME}"/.bashrc; then
    echo -e " - '~/.bashrc' already has customizations applied.\n" >&2
  else
    echo -e "${custom_bashrc}" >>~/.bashrc
    echo -e " - '~/.bashrc' updated to add customizations\n"
  fi

  for file in .blerc .gitconfig; do
    link {"${LOC}","${HOME}"}/"${file}"
  done
}

filter_installed_pkgs() {
  local installed
  mapfile -t installed < <(paru -Qq "$@" 2>/dev/null)
  installed+=("$@")
  printf "%s\n" "${installed[@]}" | sort | uniq -u
}

filter_installed_exts() {
  local installed
  mapfile -t installed < <(gext list --only-uuid)
  installed+=("$@")
  printf "%s\n" "${installed[@]}" | sort | uniq -u
}

if [[ "${PREFIX}" =~ com.termux ]]; then
  echo -e "\e[33;1m-> Installing packages.\e[0m"
  pkg update
  pkg install -y make gawk micro eza bat bash-completion command-not-found
  echo

  if [[ -d "${HOME}"/.local/share/blesh ]]; then
    echo -e "\e[33;1m-> ble.sh already installed.\e[0m\n" >&2
  else
    echo -e "\e[33;1m-> Installing ble.sh\e[0m"
    git clone --recursive --depth 1 --shallow-submodules https://github.com/akinomyoga/ble.sh "${PREFIX}"/tmp/ble.sh
    make -C "${PREFIX}"/tmp/ble.sh install PREFIX="${HOME}/.local"
    rm -rf "${PREFIX}"/tmp/ble.sh
    echo -e " - \e[32;1mble.sh installed succesfully.\e[0m\n"
  fi

  if [[ -d "${HOME}"/.local/share/bash-complete-alias ]]; then
    echo -e "\e[33;1m-> bash-complete-alias already installed\e[0m\n" >&2
  else
    echo -e "\e[33;1m-> Installing bash-complete-alias\e[0m"
    git clone --depth 1 https://github.com/cykerway/complete-alias "${HOME}"/.local/share/bash-complete-alias
    echo -e " - \e[32;1mbash-complete-alias installed succesfully.\e[0m\n"
  fi

  echo -e "\e[33;1m-> Customizing Termux installation\e[0m"
  for file in {colors,termux}.properties font.ttf; do
    link {"${LOC}/","${HOME}/."}termux/"${file}"
  done
  echo

  config_common
  echo

  process_cfgs {"${LOC}"/termux,"${PREFIX}"}/etc
  process_cfgs {"${LOC}","${HOME}"}/.config/micro

  echo -e "\e[33;1m-> Reloading Termux.\e[0m"
  termux-reload-settings

else
  config_common

  process_cfgs {"${LOC}","${HOME}"}/.config

  process_root_cfgs {"${LOC}",/root}/.config/micro

  for dir in bluetooth modprobe.d pacman.d/hooks profile.d udev wireplumber xdg; do
    if [[ -d "${LOC}"/etc/"${dir}" ]]; then
      process_root_cfgs {"${LOC}",}/etc/"${dir}"
    else
      echo -e " - \e[31;1mError directory '${LOC}/etc/${dir}' does not exist.\e[0m"
    fi
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
      echo " - '/etc/mkinitcpio.conf' updated"
      sudo mkinitcpio -P
    else
      echo -e " - '/etc/mkinitcpio.conf' already upto date\n" >&2
    fi
    MKINITCPIO_PKGS=(mkinitcpio-firmware)
  elif command -v dracut &>/dev/null; then
    if [[ -f /etc/dracut.conf.d/custom.conf ]]; then
      echo -e " - '/etc/dracut.conf.d/custom.conf' exists\n" >&2
    else
      echo -e "omit_dracutmodules+=\" qemu qemu-net \"\nforce_drivers+=\" i915 \"\n" | sudo tee /etc/dracut.conf.d/custom.conf >/dev/null
      echo -e " - '/etc/dracut.conf.d/custom.conf' created\n"
    fi
  fi

  if ! lspci | awk '/VGA/ && /Intel/ {found=1} END {exit !found}'; then
    sudo rm -fv /etc/{profile.d/hwaccel.sh,modprobe.d/i915.conf}
    sudo sed -i -e "/MODULES=(/s/ i915//g" -e '/MODULES=([[:space:]])/d' /etc/mkinitcpio.conf
    sudo sed -i -e '/force_drivers+=/s/ i915//g' -e '/force_drivers+="[[:space:]]"/d' /etc/dracut.conf.d/custom.conf
    echo
  fi

  for file in .bashrc .blerc; do
    if sudo test -L /root/"${file}" && sudo test -e /root/"${file}"; then
      echo -e " - '/root/${file}' exists" >&2
    else
      sudo ln -svf {"${HOME}",/root}/"${file}"
    fi
  done
  echo

  if [[ "$*" =~ -q ]]; then exec 3>&2; fi

  if command -v paru &>/dev/null; then
    echo -e "\e[33;1m-> \e[32;1mparu\e[33;1m package manager already installed.\n" >&2
  else
    echo -e "\e[33;1m-> Installing \e[32;1mparu\e[33;1m package manager...\e[0m"
    sudo pacman -Sy
    if pacman -Ssq paru &>/dev/null; then
      echo " - Installing paru from repos"
      sudo pacman -Su --needed paru
    else
      echo " - paru not found in repos. Installing from AUR" >&2
      sudo git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
      # shellcheck disable=SC2164
      pushd /tmp/paru-bin >/dev/null
      makepkg -si --needed --noconfirm
      # shellcheck disable=SC2164
      popd >/dev/null
      sudo rm -rf /tmp/paru-bin
    fi
    echo
  fi

  if [[ "$*" =~ -q ]]; then exec 2>&3; fi

  echo -e "\e[33;1m-> Installing necessary packages...\e[0m"
  if paru -Qq gnome-desktop &>/dev/null; then
    GNOME_PKGS=(gnome-extensions-cli {adw-gtk,papirus-icon,bibata-cursor,firefox-gnome}-theme
      kvantum-theme-libadwaita-git libgda6 webp-pixbuf-loader)
  fi
  mapfile -t PKGS < <(filter_installed_pkgs ghostty fzf ripgrep fd yazi eza micro wl-clipboard \
    bat git-delta blesh-git bash-complete-alias shellcheck shfmt refind firefox thermald dex jq \
    {visual-studio-code,hoppscotch,onlyoffice,brave,keymapper}-bin kvantum{,-qt5} qt{5,6}ct uv \
    ttf-{fira-code,nerd-fonts-symbols{,-mono}} tlp{,-rdw} thermald dex intel-media-{driver,sdk} \
    libvdpau-va-gl libva-{intel-driver,utils} vdpauinfo vulkan-{intel,mesa-layers,tools} \
    {pipewire,gst-plugin}-libcamera easyeffects calf tealdeer linux-keep-modules \
    "${GNOME_PKGS[@]}" "${MKINITCPIO_PKGS[@]}")
  paru -Syu --needed --noconfirm "${PKGS[@]}"
  echo

  for program in keymapper kanata; do
    daemon="${program/keymapper/keymapperd}"
    if paru -Qq "${program}" &>/dev/null; then
      if systemctl is-active "${daemon}" &>/dev/null; then
        echo -e "\e[33;1m-> MOD-TAP is already setup on CAPS_LOCK using \e[32;1m${program^}\e[33;1m.\e[0m\n" >&2
      else
        echo -e "\e[33;1m-> Setting up MOD-TAP on CAPS_LOCK using \e[32;1m${program^}\e[33;1m...\e[0m"

        if [[ "${program}" == "kanata" ]]; then
          link {"${LOC}",}/etc/systemd/user/kanata.service
          sudo systemctl daemon-reload
        fi

        sudo systemctl enable --now "${daemon}" &>/dev/null

        if systemctl is-active "${daemon}" &>/dev/null; then
          echo -e " - \e[32m${daemon^} service started.\e[0m"
          if [[ "${program}" == "kanata" ]] || pidof keymapper || dex /etc/xdg/autostart/keymapper.desktop; then
            echo -e " - \e[32;1mMOD-TAP on CAPS_LOCK setup succesfully.\e[0m"
          fi
        else
          echo -e "- \e[31;1mUnable to start ${daemon^} service.\e[0m"
        fi
        echo
      fi
      break
    fi
  done

  if paru -Qq gnome-desktop &>/dev/null; then
    echo -e "\e[33;1m-> Customizing \e[32;1mGnome\e[33;1m installation...\e[0m"
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

    mapfile -t EXTENSIONS < <(filter_installed_exts \
      Bluetooth-Battery-Meter@maniacx.github.com \
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
      quick-settings-tweaks@qwreey \
      lockkeys@vaina.lt)

    if (("${#EXTENSIONS[@]}" == 0)); then
      echo -e " - \e[33;1mExtensions already installed.\e[0m" >&2
    else
      echo -e " - \e[33;1mInstalling Extensions...\e[0m"
      gext install "${EXTENSIONS[@]}"
      echo
    fi

    if systemctl is-enabled gcr-ssh-agent &>/dev/null; then
      echo -e " - \e[33;1mSSH login agent already setup\e[0m\n" >&2
    else
      echo -e " - \e[32;1mSetting up SSH login...\e[0m\n"
      sudo systemctl --global enable gcr-ssh-agent &>/dev/null
      systemctl --user start gcr-ssh-agent.socket
      systemctl --user start gcr-ssh-agent
    fi

    echo -e " - \e[33;1mRestoring dconf settings...\e[0m"
    # dconf reset -f /
    dconf load / <<<"$(sed 's|%HOME%|'"${HOME}"'|g' "${LOC}"/etc/dconf-settings.ini)"
    echo
  fi

  if sudo bash -c "$(declare -f hash_equal); hash_equal \"${LOC}\"/icon.* /var/lib/AccountsService/icons/\"${USER}\""; then
    echo -e "\e[33;1m-> User logo already setup\e[0m\n" >&2
  else
    echo -e "\e[33;1m-> Customizing User logo\e[0m"
    copy "${LOC}"/icon.* /var/lib/AccountsService/icons/"${USER}"
    echo -e "[User]\nLanguages=${LANG};\nSession=\nIcon=/var/lib/AccountsService/icons/${USER}\nSystemAccount=false\n" | sudo tee /var/lib/AccountsService/users/"${USER}"
    echo -e " - \e[32;1mUser logo set successfully\e[0m\n"
  fi

  if sudo bash -c "$(declare -f hash_equal); hash_equal \"${LOC}\"/refind/refind.conf /boot/efi/EFI/refind/refind.conf" && sudo test -d /boot/efi/EFI/refind/themes/refind-theme-regular; then
    echo -e "\e[33;1m-> Bootscreen customisations already applied.\e[0m\n" >&2
  else
    echo -e "\e[33;1m-> Customizing Bootscreen\e[0m"
    sudo refind-install
    echo -e " - \e[32;1mRefind installed successfully\e[0m"
    copy {"${LOC}",/boot/efi/EFI}/refind/refind.conf
    copy {"${LOC}"/refind,/boot}/refind_linux.conf
    ROOT_DEV="$(findmnt -no SOURCE /)"
    ROOT_UUID="$(sudo -S blkid "${ROOT_DEV}" -s UUID -o value <<<"${PASSWORD}")"
    sudo sed -i 's|root=UUID=|&'"${ROOT_UUID}"'|g' /boot/refind_linux.conf
    sudo sed -i 's|ro root=|&'"${ROOT_DEV}"'|g' /boot/refind_linux.conf
    echo -e " - \e[32;1mrefind_linux.conf configured successfully\e[0m\n"

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
    echo
  fi

  echo -e "\e[33;1m-> Customizing \e[32;1mFirefox\e[33;1m installation...\e[0m"
  if pgrep firefox >/dev/null; then
    echo -ne " - \e[33;1mFirefox currently running. Save your work and press ENTER to continue.\e[0m"
    read -r
    echo -ne "\e[A\e[2K"
    killall firefox 2>/dev/null
  fi

  echo -e " - Customizing \e[32mFirefox\e[0m policies..."
  makedir /etc/firefox/policies
  link {"${LOC}",}/etc/firefox/policies/policies.json
  echo

  while IFS= read -r FIREFOX_PROFILE; do
    if paru -Qq gnome-desktop &>/dev/null; then
      echo -e " - Setting up \e[32mfirefox-gnome-theme\e[0m for ${FIREFOX_PROFILE}"
      FIREFOX_CHROME_DIR="${FIREFOX_PROFILE}"/chrome
      makedir "${FIREFOX_CHROME_DIR}"
      link {/usr/lib,"${FIREFOX_CHROME_DIR}"}/firefox-gnome-theme
      for file in userChrome.css userContent.css; do
        if [[ -f "${FIREFOX_CHROME_DIR}/${file}" ]]; then
          echo " - '${FIREFOX_CHROME_DIR}/${file}' exists" >&2
        else
          echo "@import \"firefox-gnome-theme/${file}\";" >"${FIREFOX_CHROME_DIR}/${file}"
        fi
      done
      cp {"${FIREFOX_CHROME_DIR}"/firefox-gnome-theme/configuration,"${FIREFOX_PROFILE}"}/user.js

      cat <<EOF >>"${FIREFOX_PROFILE}"/user.js
// Gnome theme customizations

user_pref("gnomeTheme.hideSingleTab", false);
user_pref("gnomeTheme.tabsAsHeaderbar", true);
user_pref("gnomeTheme.hideWebrtcIndicator", true);

EOF
    fi

    echo " - Hardening user.js & applying custom settings for ${FIREFOX_PROFILE##*/}"
    cat "${LOC}/firefox/user.js" >>"${FIREFOX_PROFILE}"/user.js

    echo -e " - \e[32;1mCustomizations applied to ${FIREFOX_PROFILE##*/}\e[0m\n"
  done < <(awk -F'=' -e '$0 ~ /\[Profile[[:digit:]]+\]/ { f=1; next } /\[/{ f=0; next } f && $1=="Path"{ print "'"${HOME}"'/.mozilla/firefox/"$2 }' \
    "${HOME}"/.mozilla/firefox/profiles.ini)

  for browser in brave chromium; do
    echo -e "\e[33;1m-> Customizing \e[32;1m${browser^}\e[33;1m policies...\e[0m"
    makedir /etc/"${browser}"/policies
    for type in managed recommended; do
      if [[ -d "${LOC}"/etc/"${browser}"/policies/"${type}" ]]; then
        link {"${LOC}",}/etc/"${browser}"/policies/"${type}"
      fi
    done
    echo -e " - \e[32;1mCustom policies applied for ${browser^}.\e[0m\n"
  done

  systemctl --user stop wireplumber pipewire -q
  systemctl --user start wireplumber -q

  sudo systemctl enable --now thermald tlp cleanup-linux-modules 2>/dev/null

  sudo update-desktop-database

  if [[ ! -f "${LOC}"/.firstRunSuccess ]]; then
    echo -e "\n\e[33;1mManual intervention required.\e[0;1m [OPTIONAL]\e[0m"

    echo -e " \e[31;1m-\e[0m Edit \"\e[34;1m/etc/{fstab,crypttab}\e[0m\" using the previous config files as reference"
    echo -e " \e[31;1m-\e[0m Save your bitlocker key in \"\e[34;1m/etc/cryptsetup-keys.d/*.key\e[0m\" using the previous key file as reference"
    echo -e " \e[31;1m-\e[0m Previous confg files are in \e[34;1metc\e[0m subdir in current dir."

    echo -e "\e[32;1mAutomatic dotfiles sync successful.\e[0m\n"
    touch "${LOC}"/.firstRunSuccess
  else
    echo -en "\e[A"
  fi

fi
