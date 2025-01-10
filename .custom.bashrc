#!/bin/bash
# shellcheck enable=require-variable-braces

# customisations

if [[ $- == *i* ]]; then

  # shellcheck disable=SC1091
  . "$(dirname "${BASH_SOURCE[0]}")"/extras/palette.sh

  bind 'set completion-ignore-case on'
  bind 'set match-hidden-files off'
  bind -x '"\C-l":clear'
  shopt -s autocd
  shopt -s cdspell
  shopt -s dirspell
  shopt -s expand_aliases
  shopt -s no_empty_cmd_completion
  set -C

  HISTCONTROL=ignoreboth

  if [[ "${TERM}" != "linux" ]]; then
    _ls_icons="--icons"
  fi

  # shellcheck disable=SC2139
  alias ls="eza -ghoM --smart-group --git --no-time --no-permissions --group-directories-first --hyperlink --no-quotes -I .git ${_ls_icons}"
  # shellcheck disable=SC2139
  alias tree="eza -ghoMT --smart-group --git --no-time --no-permissions --group-directories-first --hyperlink --no-quotes -I .git ${_ls_icons}"
  alias cat="bat -p"

  alias venv="virtualenv"

  if command -v sudo &>/dev/null; then
    alias sudo="sudo "
  fi

  if [[ ! "${PREFIX}" =~ com.termux ]]; then
    alias ctl="systemctl"
  fi

  help() {
    command help "$@" || "$@" --help | bat -pl help
  }

  if [[ ${EUID} == 0 ]]; then
    PS1='${SUDO_USER:+(\[\e[01;33m$SUDO_USER\e[0m\]) }\[\e[01;31m\]\u@\h\[\e[00m\]:\[\e[01;34m\]\w\[\e[00m\] \n \[\e[01;31m\]\$_\[\e[00m\] '
  else
    PS1='\[\e[01;32m\]\u@\h\[\e[00m\]:\[\e[01;34m\]\w\[\e[00m\] \n \[\e[01;32m\]\$_\[\e[00m\] '
  fi

  export COMPAL_AUTO_UNMASK=1

  if [[ "${PREFIX}" =~ com.termux ]]; then
    # shellcheck source=/dev/null
    . "${HOME}/.local/share/blesh/ble.sh"
    # shellcheck source=/dev/null
    . "${HOME}/.local/share/bash-complete-alias/complete_alias"
  else # [[ "$TERM_PROGRAM" != "vscode" ]]; then
    # shellcheck disable=SC1091
    . "/usr/share/blesh/ble.sh"
    # shellcheck disable=SC1091
    . "/usr/share/bash-complete-alias/complete_alias"

    if [[ "${TERM_PROGRAM}" == "vscode" ]]; then
      # shellcheck source=/dev/null
      . "$(code --locate-shell-integration-path bash 2>/dev/null)"
    fi
  fi

  complete -F _complete_alias "${!BASH_ALIASES[@]}"

  if ! shopt -q login_shell && [[ "${XDG_CURRENT_DESKTOP}" == "GNOME" ]]; then
    alias logout="gnome-session-quit --no-prompt"
  fi
fi
