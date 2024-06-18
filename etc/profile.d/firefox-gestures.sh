#!/bin/sh

# Enable Firefox wayland if running a wayland session
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    export MOZ_ENABLE_WAYLAND=1
# Else enable xinput2 for gestures
else
    export MOZ_USE_XINPUT2=1
fi
