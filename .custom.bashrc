# customisations

if [[ $- == *i* ]]; then
  bind 'set completion-ignore-case on'
  shopt -s autocd
  shopt -s cdspell
  shopt -s dirspell
  shopt -s expand_aliases
  set -C

  HISTCONTROL=ignoreboth

  if [[ $EUID == 0 ]]; then
    PS1='${SUDO_USER:+(\033[01;33m$SUDO_USER\033[0m) }\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\] \n \[\033[01;31m\]\$_\[\033[00m\] '
  else
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\] \n \[\033[01;32m\]\$_\[\033[00m\] '
  fi

  if [[ "$TERM_PROGRAM" != "vscode" ]]; then
    . /usr/share/blesh/ble.sh
  fi
fi
