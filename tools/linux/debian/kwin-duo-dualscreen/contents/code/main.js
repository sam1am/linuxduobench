// SPDX-License-Identifier: GPL-2.0-or-later
// Surface Duo, Plasma Mobile: move apps between the two screens.
//  - Swipe in from a screen's right edge: the active app goes to the screen on the right (or below, in landscape);
//    from the left edge: to the screen on the left (or above). The inner edges along the hinge count as screen edges
//    because the two outputs are laid out with the hinge gap between them (duo-posture / org.duo.HingeGap).
//  - Shortcuts: Meta+Shift+Right / Meta+Shift+Left, and Meta+Shift+O = the other screen.
// Plasma Mobile shows every app maximised without a title bar, so there is nothing to drag; this is the replacement.

function screensInOrder() {
    // left to right in portrait, top to bottom in landscape (duo-posture stacks them)
    var s = workspace.screens.slice();
    s.sort(function (a, b) { return (a.geometry.x + a.geometry.y) - (b.geometry.x + b.geometry.y); });
    return s;
}

function move(step) {
    var w = workspace.activeWindow;
    if (!w || !w.normalWindow || w.specialWindow) return;
    var s = screensInOrder();
    if (s.length < 2) return;
    var i = s.indexOf(w.output);
    if (i < 0) return;
    var j = step === 0 ? (i + 1) % s.length : i + step;
    if (j < 0 || j >= s.length) return;
    // (KWin's own "Window to Next Screen" refuses here: Plasma Mobile's InteractiveWindowMoveEnabled=false makes
    // isMovableAcrossScreens() false. sendClientToScreen() -> Window::sendToOutput() does not check it.)
    workspace.sendClientToScreen(w, s[j]);
    workspace.activeWindow = w;
    // A short outline over the window as a visual cue. (The move itself completes when the app commits a frame at
    // the new size - which never happens while the screens are DPMS-off: KWin then renders nothing.)
    workspace.showOutline(w.frameGeometry);
    var h = new QTimer();
    h.singleShot = true; h.interval = 250;
    h.timeout.connect(function () { workspace.hideOutline(); });
    h.start();
    var t = new QTimer();
    t.singleShot = true; t.interval = 800;
    t.timeout.connect(function () {
        print("duo-dualscreen: " + w.resourceClass + " " + s[i].name + " -> " + s[j].name + ": now on " + w.output.name);
    });
    t.start();
}

registerTouchScreenEdge(KWin.ElectricRight, function () { move(+1); });
registerTouchScreenEdge(KWin.ElectricLeft, function () { move(-1); });
registerShortcut("DuoMoveRight", "Duo: move app to the next screen", "Meta+Shift+Right", function () { move(+1); });
registerShortcut("DuoMoveLeft", "Duo: move app to the previous screen", "Meta+Shift+Left", function () { move(-1); });
registerShortcut("DuoMoveOther", "Duo: move app to the other screen", "Meta+Shift+O", function () { move(0); });
print("duo-dualscreen: loaded, " + workspace.screens.length + " screens");
