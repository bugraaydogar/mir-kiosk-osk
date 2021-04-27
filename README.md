# Intro

This is an experimental snap that tries to demonstrate Mir-kiosk with an integrated OSK.

# Usage

When the snap installed, a shell will be launch automatically.
matchbox-keyboard and flutter_gallery app will also be already installed in the snap.
To run flutter_gallery and a osk;
`export LC_ALL=en_UK.UTF-8`
`export FLUTTER_GALLERY_FULLSCREEN=1`
`$SNAP/bin/flutter_gallery &`
`$SNAP/usr/bin/matchbox-keyboard --width 1000 --height 500`
