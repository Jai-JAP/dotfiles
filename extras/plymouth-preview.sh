#!/bin/bash

# Preview Plymouth Splash
# by _khAttAm_
# www.khattam.info
# License: GPL v3
# source: https://gist.github.com/nextgenthemes/5396198
# modified by Sébastien Bouchard <sebastjava@hotmail.ca>

if [[ "$( id -u )" != 0 ]]; then
  echo "Must be run as root!"
  exit
fi

DURATION=${1:-10}

plymouthd; plymouth --show-splash; sleep "$DURATION"; plymouth quit
