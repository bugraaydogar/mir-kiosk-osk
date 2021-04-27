#!/bin/bash
set -e



# Wayland socket management
wdisplay="wayland-0"
if [ -n "$WAYLAND_DISPLAY" ]; then
  wdisplay="$WAYLAND_DISPLAY"
fi
wayland_sockpath="$XDG_RUNTIME_DIR/../$wdisplay"
wayland_snappath="$XDG_RUNTIME_DIR/$wdisplay"

# If running on Classic, a Wayland socket may be in the usual XDG_RUNTIME_DIR
if [ ! -S "$wayland_snappath" ]; then
  # Either running on Core, or no Wayland socket to be found
  if [ ! -S "$wayland_sockpath" ]; then
    echo "Error: Unable to find a valid Wayland socket in $(dirname $XDG_RUNTIME_DIR)"
    echo "Is a Wayland server running?"

    # On Core, Xwayland needs to run as root (bug lp:1767372), so everything has to
    if [ "$EUID" -ne 0 ]; then
      echo "You could try running as root"
    fi
    # It may be that the socket isn't there yet, in case we will get restarted by systemd,
    # wait a couple seconds to give the other side time to prepare
    # For mir-kiosk, https://github.com/MirServer/mir/issues/586 would solve it proper
    sleep 1
  fi

  # if running under wayland, use it
  #export WAYLAND_DEBUG=1
  # create the compat symlink for now
  if [ ! -e "$wayland_snappath" ]; then
    ln -s "$wayland_sockpath" "$wayland_snappath"
  fi
fi


while [ "$(cat /run/user/0/wayland-0 2>&1|sed 's/.*: //')" = "Permission denied" ]; do
    echo "Wayland socket not readable, sleeping for 10 sec"
    echo "Please run snap connect $SNAP_NAME:wayland mir-kiosk:wayland"
    sleep 10
done


# This snap provides both an X11 server and an X11 client which needs to connect to it. To allow
# this to work correctly, need to be both an X11 slot and X11 plug, and have them connected.
# Detect the X11 plug/slot connected by verifying access to fontconfig directory.
while ! ls /var/cache/fontconfig/ 2>/dev/null; do
    echo "Can not spawn X11 session, sleeping for 10 sec"
    echo "Please run snap connect $SNAP_NAME:x11-plug $SNAP_NAME:x11"
    sleep 10
done

# If necessary, set up minimal environment for Xwayland to function
if [ -z ${LIBGL_DRIVERS_PATH+x} ]; then
  if [ "$SNAP_ARCH" == "amd64" ]; then
    ARCH="x86_64-linux-gnu"
  elif [ "$SNAP_ARCH" == "armhf" ]; then
    ARCH="arm-linux-gnueabihf"
  elif [ "$SNAP_ARCH" == "arm64" ]; then
    ARCH="aarch64-linux-gnu"
  else
    ARCH="$SNAP_ARCH-linux-gnu"
  fi

  export LIBGL_DRIVERS_PATH=$SNAP/usr/lib/$ARCH/dri
fi

# Use new port number in case old server clean up wasn't successful
let port=$RANDOM%100
# Avoid low numbers as they may be used by desktop
let port+=4

# We need a simple window manager to make the client application fullscreen.
# Am using i3 here, so generate a simple config file for it.
I3_CONFIG=$SNAP_DATA/i3.config

cat <<EOF >> "$I3_CONFIG"
# i3 config file (v4)
font pango:monospace 8
# set window for fullscreen
for_window [${XWAYLAND_FULLSCREEN_WINDOW_HINT}] fullscreen
EOF


# Launch Xwayland.
(SNAPPY_PRELOAD=$SNAP \
LD_PRELOAD=$SNAP/lib/libxwayland-preload.so \
  $SNAP/usr/bin/Xwayland -nocursor -terminate :${port}; echo $?) &

trap "trap - SIGTERM && kill $pid" SIGINT SIGTERM EXIT # kill on signal or quit
sleep 1 # FIXME - Xwayland does emit SIGUSR1 when ready for client connections

export DISPLAY=:${port}
export GDK_BACKEND="x11"
export CLUTTER_BACKEND="x11"
export QT_QPA_PLATFORM="xcb"

export XDG_DATA_HOME=$SNAP/usr/share
export FONTCONFIG_PATH=$SNAP/etc/fonts/conf.d
export FONTCONFIG_FILE=$SNAP/etc/fonts/fonts.conf

# Avoid using $XDG_RUNTIME_DIR until LP: #1656340 is fixed
(XDG_RUNTIME_DIR=$SNAP_DATA $SNAP/bin/wmx) &
# (XDG_RUNTIME_DIR=$SNAP_DATA $SNAP/bin/flutter_gallery) &
# (XDG_RUNTIME_DIR=$SNAP_DATA $SNAP/usr/bin/matchbox-keyboard --width 1000 --height 500 ) &
"$@"

