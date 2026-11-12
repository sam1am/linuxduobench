/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Surface Duo (Debian/Plasma Mobile), developer keys for maliit-keyboard's English layout.
 * A key that sends either a named key (seq: "Tab", "Escape", "Left", ...) or, while Ctrl/Alt is latched on the pad,
 * that modifier + the key ("Ctrl+C", "Ctrl+Left"), through maliit's "keysequence" action
 * (AbstractTextEditor::sendKeySequence -> QKeySequence::fromString). Without a modifier a character key types as usual.
 */
import QtQuick 2.4
import keys 1.0

CharKey {
    property var pad: null          // the KeyPad holding ctrl/alt (set by the layout)
    property string seq: ""         // a named key; "" = a character key
    readonly property string mods: pad ? ((pad.ctrl ? "Ctrl+" : "") + (pad.alt ? "Alt+" : "")) : ""
    readonly property string ch: (panel.activeKeypadState === "NORMAL" || shifted === "") ? label : shifted

    noMagnifier: seq !== ""
    skipAutoCaps: seq !== ""
    action: (seq !== "" || mods !== "") ? "keysequence" : ""
    valueToSubmit: seq !== "" ? mods + seq : (mods !== "" ? mods + (ch.length === 1 ? ch.toUpperCase() : ch) : ch)

    // a latched modifier applies to one key; clear it after this key was sent
    onReleased: if (pad && mods !== "") Qt.callLater(function () { pad.ctrl = false; pad.alt = false; })
}
