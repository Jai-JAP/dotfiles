#!/bin/bash

if [[ -f "~/.termux" ]]; then
  for file in $(ls ./termux); do
    ln -sf {"$(realpath ./termux)",~/.termux}/$file
  done
  exit
else

  for file in; do
    ln -sf {"$(realpath .)",~}/$file
  done

  echo "
    . $(realpath .)/.custom.bashrc" >>~/.bashrc
fi
