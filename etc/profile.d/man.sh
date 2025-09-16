#!/bin/bash

_bat="bat"
if command -v batcat &>/dev/null; then
  _bat="batcat"
fi

export MANPAGER="sh -c 'col -bx | ${_bat} -l man -p'"
export MANROFFOPT="-c"
