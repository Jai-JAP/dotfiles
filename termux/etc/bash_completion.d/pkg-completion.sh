# put in `/data/data/com.termux/files/usr/etc/bash_completion.d`

_comp_pkg() {
  local current previous options package_command installed_command packages
  COMPREPLY=()
  current="${COMP_WORDS[COMP_CWORD]}"
  previous="${COMP_WORDS[@]::${#COMP_WORDS[@]}-1}"
  options="--check-mirror autoclean clean files install list-all list-installed reinstall search show uninstall upgrade update"
  package_command="install|show"
  installed_command="files|reinstall|uninstall"

  # >&2 echo ${previous}
  if [[ ${previous} =~ ${package_command} ]]; then
    # >&2 echo "pk"
    packages=$(pkg list-all 2>/dev/null | tail -n +2 | cut -d '/' -f 1)
    COMPREPLY=($(compgen -W "$packages" -- ${current}))
    return 0
  elif [[ ${previous} =~ ${installed_command} ]]; then
    packages=$(pkg list-installed 2>/dev/null | tail -n +2 | cut -d '/' -f 1)
    COMPREPLY=($(compgen -W "$packages" -- ${current}))
    return 0
  else
    COMPREPLY=($(compgen -W "${options}" -- ${current}))
    return 0
  fi

}

complete -F _comp_pkg pkg
