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

PACKAGES="glu libglvnd clang ninja pkgconf gtk3 android-sdk-platform-tools android-sdk-cmdline-tools-latest"
#shellcheck disable=2086
if yay -Qq $PACKAGES &>/dev/null; then
  echo "Dependencies already installed"
else
  echo -e "\033[33;1mInstalling dependencies\033[0m"
  yay -S --needed --noconfirm $PACKAGES 2>/dev/null
  sudo chown root:users /opt/android-sdk
  sudo chmod g+w /opt/android-sdk
  echo
fi

if [[ "$(sdkmanager --list_installed | grep -e 'build-tools' -e 'platforms' -e 'sources' -c)" -ge 3 ]]; then
  echo "Required android-sdk components already installed."
else
  echo -e "\033[33;1mInstalling required \033[32;1mandroid-sdk\033[33;1m components\033[0m"
  BUILD_TOOLS="$(sdkmanager --list | awk '/build-tools/ && !/rc/ {print $1}' | sort -uV | tail -n1)" 
  PLATFORM="$(sdkmanager --list | awk '/platforms;android-[0-9]+/ && !/ext/ {print $1}' | sort -uV | tail -n1)" 
  SOURCES="${PLATFORM/platforms/sources}"
  sdkmanager "$BUILD_TOOLS" "$PLATFORM" "$SOURCES"
  echo
fi

if [[ -d "/opt/flutter" ]]; then
  echo "Flutter already installed"
else
  echo -e "\033[33;1mInstalling \033[32;1mFlutter\033[0m"
  # DATA="$(curl -fSsl https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json)"
  # BASEURL="$(jq -r <<<$DATA .base_url)"
  # HASH="$(jq -r <<<$DATA .current_release.stable)"
  # RELEASE_INFO="$(jq -r <<<$DATA ".releases[] | select(.hash == \"$HASH\")")"
  # RELURL="$(jq -r <<<$RELEASE_INFO .archive)"
  # SHA256SUM="$(jq -r <<<$RELEASE_INFO .sha256)"
  # FILENAME=${RELURL##*/}
  # aria2c -x16 -j8 --summary-interval=0 --download-result=hide --console-log-level=error "$BASEURL/$RELURL" --dir /tmp 
  # FILE_SHA256SUM="$(sha256sum /tmp/$FILENAME | awk '{print $1}')"
  # if [[ "$FILE_SHA256SUM" == "$SHA256SUM" ]]; then 
  #   sudo tar -xf "/tmp/$FILENAME" -C /opt/
  # else
  #   echo -e "\033[31;1mFlutter sdk download corrupted. Install failed\033[0m"
  # fi
  # sudo rm -rf "/tmp/$FILENAME"
  
  # # or
   
  sudo mkdir -p /opt/flutter
  sudo chown "$USER:$USER" /opt/flutter
  git clone https://github.com/flutter/flutter -b stable --single-branch --depth=1 /opt/flutter
  flutter doctor
  
  flutter config --no-analytics
  flutter bash-completion | sudo tee /usr/share/bash-completion/completions/flutter >/dev/null
  echo "Flutter installed successfully"
fi
