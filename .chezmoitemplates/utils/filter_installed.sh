filter_installed() {
  local installed=()
  local cmd=()
  local packages=()
  
  while [[ $# -gt 0 ]]; do
    [[ "$1" == "--" ]] && shift && break
    cmd+=("$1")
    shift
  done
  
  packages=("$@")
  
  mapfile -t installed < <("${cmd[@]}" "${packages[@]}" 2>/dev/null)
  
  installed+=("${packages[@]}")
  printf "%s\n" "${installed[@]}" | sort | uniq -u
}
