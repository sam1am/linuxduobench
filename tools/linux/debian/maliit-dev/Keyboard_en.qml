/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Surface Duo: maliit-keyboard's English layout + a developer row (Esc, Tab, sticky Ctrl/Alt, arrows, - and /) and
 * programming symbols on long press. Based on maliit-keyboard 2.3.1 languages/en/Keyboard_en.qml (Canonical, GPL-3).
 * Installed over the package's file with dpkg-divert (tools/linux/debian/maliit-dev/install.sh).
 *   Ctrl / Alt: tap = latch for the next key (lit), tap again = off. Ctrl then c = Ctrl+C, Ctrl then a left arrow =
 *   Ctrl+Left. Long press: "-" = _ = + *, "/" = \ | ~ `, "," = ; : ' " ( ) [ ] { } < >, "." = ? ! @ # $ % ^ & *.
 *   The top letter row keeps the digits on long press.
 */
import QtQuick 2.4
import MaliitKeyboard 2.0
import keys 1.0

KeyPad {
    id: kp
    property bool ctrl: false
    property bool alt: false

    anchors.fill: parent
    content: c1
    symbols: "languages/Keyboard_symbols.qml"

    Column {
        id: c1
        anchors.fill: parent
        spacing: 0

        Row {
            anchors.horizontalCenter: parent.horizontalCenter;
            spacing: 0
            DevKey { pad: kp; label: "Esc"; seq: "Escape"; leftSide: true; }
            DevKey { pad: kp; label: "Tab"; seq: "Tab"; }
            ModKey { pad: kp; which: "ctrl"; }
            ModKey { pad: kp; which: "alt"; }
            DevKey { pad: kp; label: "←"; seq: "Left"; }
            DevKey { pad: kp; label: "↓"; seq: "Down"; }
            DevKey { pad: kp; label: "↑"; seq: "Up"; }
            DevKey { pad: kp; label: "→"; seq: "Right"; }
            DevKey { pad: kp; label: "-"; shifted: "_"; extended: ["_", "=", "+", "*"]; extendedShifted: ["-", "=", "+", "*"]; }
            DevKey { pad: kp; label: "/"; shifted: "\\"; extended: ["\\", "|", "~", "`"]; extendedShifted: ["/", "|", "~", "`"]; rightSide: true; }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter;
            spacing: 0
            DevKey { pad: kp; label: "q"; shifted: "Q"; extended: ["1"]; extendedShifted: ["1"]; leftSide: true; }
            DevKey { pad: kp; label: "w"; shifted: "W"; extended: ["2"]; extendedShifted: ["2"] }
            DevKey { pad: kp; label: "e"; shifted: "E"; extended: ["3", "è", "é", "ê", "ë", "€"]; extendedShifted: ["3", "È","É", "Ê", "Ë", "€"] }
            DevKey { pad: kp; label: "r"; shifted: "R"; extended: ["4"]; extendedShifted: ["4"] }
            DevKey { pad: kp; label: "t"; shifted: "T"; extended: ["5", "þ"]; extendedShifted: ["5", "Þ"] }
            DevKey { pad: kp; label: "y"; shifted: "Y"; extended: ["6", "ý", "¥"]; extendedShifted: ["6", "Ý", "¥"] }
            DevKey { pad: kp; label: "u"; shifted: "U"; extended: ["7", "û","ù","ú","ü"]; extendedShifted: ["7", "Û","Ù","Ú","Ü"] }
            DevKey { pad: kp; label: "i"; shifted: "I"; extended: ["8", "î","ï","ì","í"]; extendedShifted: ["8", "Î","Ï","Ì","Í"] }
            DevKey { pad: kp; label: "o"; shifted: "O"; extended: ["9", "ö","ô","ò","ó"]; extendedShifted: ["9", "Ö","Ô","Ò","Ó"] }
            DevKey { pad: kp; label: "p"; shifted: "P"; extended: ["0"]; extendedShifted: ["0"]; rightSide: true; }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter;
            spacing: 0
            DevKey { pad: kp; label: "a"; shifted: "A"; extended: ["ä","à","â","ª","á","å", "æ"]; extendedShifted: ["Ä","À","Â","ª","Á","Å","Æ"]; leftSide: true; }
            DevKey { pad: kp; label: "s"; shifted: "S"; extended: ["ß","$"]; extendedShifted: ["$"] }
            DevKey { pad: kp; label: "d"; shifted: "D"; extended: ["ð"]; extendedShifted: ["Ð"] }
            DevKey { pad: kp; label: "f"; shifted: "F"; }
            DevKey { pad: kp; label: "g"; shifted: "G"; }
            DevKey { pad: kp; label: "h"; shifted: "H"; }
            DevKey { pad: kp; label: "j"; shifted: "J"; }
            DevKey { pad: kp; label: "k"; shifted: "K"; }
            DevKey { pad: kp; label: "l"; shifted: "L"; rightSide: true; }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter;
            spacing: 0
            ShiftKey {}
            DevKey { pad: kp; label: "z"; shifted: "Z"; }
            DevKey { pad: kp; label: "x"; shifted: "X"; }
            DevKey { pad: kp; label: "c"; shifted: "C"; extended: ["ç"]; extendedShifted: ["Ç"] }
            DevKey { pad: kp; label: "v"; shifted: "V"; }
            DevKey { pad: kp; label: "b"; shifted: "B"; }
            DevKey { pad: kp; label: "n"; shifted: "N"; extended: ["ñ"]; extendedShifted: ["Ñ"] }
            DevKey { pad: kp; label: "m"; shifted: "M"; }
            BackspaceKey {}
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            height: panel.keyHeight + Device.row_margin;

            SymbolShiftKey { id: symShiftKey;                            anchors.left: parent.left; height: parent.height; }
            LanguageKey    { id: languageMenuButton;                     anchors.left: symShiftKey.right; height: parent.height; }
            DevKey         { id: commaKey; pad: kp; label: ","; shifted: ","; extended: [";", ":", "'", "\"", "(", ")", "[", "]", "{", "}", "<", ">"]; extendedShifted: [";", ":", "'", "\"", "(", ")", "[", "]", "{", "}", "<", ">"]; anchors.left: languageMenuButton.right; height: parent.height; }
            SpaceKey       { id: spaceKey;                               anchors.left: commaKey.right; anchors.right: dotKey.left; noMagnifier: true; height: parent.height; }
            DevKey         { id: dotKey; pad: kp; label: "."; shifted: "."; extended: ["?", "!", "@", "#", "$", "%", "^", "&", "*"]; extendedShifted: ["?", "!", "@", "#", "$", "%", "^", "&", "*"]; anchors.right: enterKey.left; height: parent.height; }
            ReturnKey      { id: enterKey;                               anchors.right: parent.right; height: parent.height; }
        }
    } // column
}
