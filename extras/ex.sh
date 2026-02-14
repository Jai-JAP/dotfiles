#!/hint/bash

# # ex - archive extractor
# # usage: ex [-C dir] <file>
ex() {
  local dest="" opt file base out
  while getopts ":C:" opt; do
    case "${opt}" in
      C) dest=${OPTARG} ;;
      *) echo "usage: ex [-C dir] file"; return 1 ;;
    esac
  done
  shift $((OPTIND - 1))
  file=$1

  [[ -n ${dest} ]] && mkdir -p "${dest}"

  if [[ -f "${file}" ]]; then
    base=${file##*/}
    case "${file}" in
      *.tar.* | *.t*) tar xaf "${file}" "${dest:+-C "${dest}"}" ;;
      *.bz2)
        out=${base%.bz2}
        if [[ -n ${dest} ]]; then lbunzip2 -c "${file}" >"${dest}/${out}" || bunzip2 -c "${file}" >"${dest}/${out}"; else lbunzip2 "${file}" || bunzip2 "${file}"; fi
        ;;
      *.rar) unrar x "${file}" ${dest:+${dest}} ;;
      *.gz)
        out=${base%.gz}
        if [[ -n ${dest} ]]; then unpigz -c "${file}" >"${dest}/${out}" || gunzip -c "${file}" >"${dest}/${out}"; else unpigz "${file}" || gunzip "${file}"; fi
        ;;
      *.xz)
        out=${base%.xz}
        if [[ -n ${dest} ]]; then unxz -T0 -c "${file}" >"${dest}/${out}"; else unxz -T0 "${file}"; fi
        ;;
      *.zip) unzip ${dest:+-d "${dest}"} "${file}" ;;
      *.zst | *.zstd)
        out=${base%.zst}; out=${out%.zstd}
        if [[ -n ${dest} ]]; then unzstd -T0 -c "${file}" >"${dest}/${out}"; else unzstd -T0 "${file}"; fi
        ;;
      *.Z)
        out=${base%.Z}
        if [[ -n ${dest} ]]; then uncompress -c "${file}" >"${dest}/${out}"; else uncompress "${file}"; fi
        ;;
      *.7z) 7z x "${file}" ${dest:+-o"${dest}"} ;;
      *) echo "'${file}' cannot be extracted via ex()" ;;
    esac
  else
    echo "'${file}' is not a valid file"
  fi
}
