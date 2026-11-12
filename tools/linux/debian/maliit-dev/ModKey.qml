/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Surface Duo: a sticky modifier key (Ctrl / Alt) for maliit-keyboard. Tap to latch it for the next key (it lights
 * up), tap again to release. DevKey reads the latch from the pad.
 */
import QtQuick 2.4
import keys 1.0

ActionKey {
    property var pad: null
    property string which: "ctrl"   // "ctrl" or "alt"

    overridePressArea: true         // no text from this key itself
    noMagnifier: true
    highlight: pad ? pad[which] : false
    label: pad && pad[which] ? (which === "ctrl" ? "CTRL" : "ALT") : (which === "ctrl" ? "Ctrl" : "Alt")
    width: panel.keyWidth

    onReleased: if (pad) pad[which] = !pad[which]
}
