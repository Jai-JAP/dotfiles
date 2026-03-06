# Useful snippets


## WSL commands integration without .exe extensions 

```bash
command_not_found_handle() {
  local cmd="$1"
  shift

  if command -v "${cmd}.exe" >/dev/null 2>&1; then
    "${cmd}.exe" "$@"
    return
  fi

  echo "command not found: ${cmd}" >&2
  return 127
}
```

Use `unset -f command_not_found_handle &>/dev/null` to disable in case it causes any errors

