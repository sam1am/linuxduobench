#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Surface Duo, Plasma Mobile: each screen's navigation bar acts on ITS screen. Stock, the close (X) button closes the
# focused app wherever it is, so the X under the left screen could close the app on the right one. The task panel's
# tasks model already says filterByScreen but never gets a screen; give it the panel's screen, sort it by last use, and
# close the most recently used app on that screen.
#   usage (root, on the phone or with ROOT=<debian root>):  sh install.sh      (idempotent)
# The package's file is diverted (dpkg-divert) and patched from it, so a plasma-mobile upgrade does not silently
# overwrite this; re-run after one. Undo: rm <file> && dpkg-divert --rename --remove <file>
set -e
R=${ROOT:-}
F=/usr/share/plasma/plasmoids/org.kde.plasma.mobile.taskpanel/contents/ui/NavigationPanelComponent.qml
run() { if [ -n "$R" ]; then chroot "$R" "$@"; else "$@"; fi; }
[ -f "$R$F" ] || { echo "no $R$F"; exit 1; }
run dpkg-divert --quiet --local --rename --divert $F.distrib --add $F
python3 -I - "$R$F.distrib" "$R$F" <<'EOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
def rep(old, new):
    global s
    if s.count(old) != 1:
        sys.exit("plasma-mobile-perscreen: anchor found %d times, not patching: %r" % (s.count(old), old[:60]))
    s = s.replace(old, new)
rep("        filterByScreen: true\n",
    "        filterByScreen: true\n"
    "        screenGeometry: Plasmoid.containment.screenGeometry   // Duo: this panel's screen only\n"
    "        sortMode: TaskManager.TasksModel.SortLastActivated   // Duo: most recently used first\n")
rep("enabled: Keyboards.KWinVirtualKeyboard.active || WindowPlugin.WindowUtil.hasCloseableActiveWindow",
    "enabled: Keyboards.KWinVirtualKeyboard.active || tasksModel.count > 0   // Duo: an app on this screen")
rep("""            } else if (WindowPlugin.WindowUtil.hasCloseableActiveWindow) {
                // if task switcher is closed, but there is an active window
                if (tasksModel.activeTask !== 0) {
                    tasksModel.requestClose(tasksModel.activeTask);
                }
            }""", """            } else if (tasksModel.count > 0) {
                // Duo: close the app on THIS screen (the most recently used one here), not the focused one anywhere
                tasksModel.requestClose(tasksModel.makeModelIndex(0));
            }""")
open(dst, "w").write(s)
print("plasma-mobile-perscreen: patched", dst)
EOF
