// SPDX-License-Identifier: GPL-2.0-or-later
// Surface Duo, Plasma Mobile: move apps between the two screens.
//  - DuoMoveFromDSI-1 / DuoMoveFromDSI-2: the app on top of THAT screen goes to the other one. duo-posture invokes
//    these for a swipe along the top of a screen towards the hinge.
//  - Shortcuts: Meta+Shift+Right / Meta+Shift+Left (the focused app to the next / previous screen), Meta+Shift+O
//    (the focused app to the other screen).
// Plasma Mobile shows every app maximised without a title bar, so there is nothing to drag; this is the replacement.
// (The first version used swipes in from the side edges; moving away from the hinge to go the other way was
// unintuitive, so those are gone.)

function screensInOrder() {
    // left to right in portrait, top to bottom in landscape (duo-posture stacks them)
    var s = workspace.screens.slice();
    s.sort(function (a, b) { return (a.geometry.x + a.geometry.y) - (b.geometry.x + b.geometry.y); });
    return s;
}

function send(w, from, to) {
    // (KWin's own "Window to Next Screen" refuses here: Plasma Mobile's InteractiveWindowMoveEnabled=false makes
    // isMovableAcrossScreens() false. sendClientToScreen() -> Window::sendToOutput() does not check it.)
    workspace.sendClientToScreen(w, to);
    workspace.activeWindow = w;
    // a short outline over the window as a visual cue (the move completes when the app commits a frame at the new
    // size, which never happens while the screens are DPMS-off: KWin then renders nothing)
    workspace.showOutline(w.frameGeometry);
    var h = new QTimer();
    h.singleShot = true; h.interval = 250;
    h.timeout.connect(function () { workspace.hideOutline(); });
    h.start();
    print("duo-dualscreen: " + w.resourceClass + " " + from.name + " -> " + to.name);
}

// apps only: not KWin's own internal windows (the outline, OSDs: resourceClass kwin_wayland), not panels or popups
function movable(w) {
    return w && w.normalWindow && !w.specialWindow && !w.minimized && !w.skipTaskbar &&
        w.resourceClass !== "kwin_wayland";
}

function move(step) {
    var w = workspace.activeWindow;
    if (!movable(w)) return;
    var s = screensInOrder();
    if (s.length < 2) return;
    var i = s.indexOf(w.output);
    if (i < 0) return;
    var j = step === 0 ? (i + 1) % s.length : i + step;
    if (j < 0 || j >= s.length) return;
    send(w, s[i], s[j]);
}

function moveFrom(name) {
    var s = screensInOrder(), from = null, to = null;
    for (var k = 0; k < s.length; k++) { if (s[k].name === name) from = s[k]; else if (!to) to = s[k]; }
    if (!from || !to) return;
    var ws = workspace.stackingOrder;          // bottom to top
    for (var i = ws.length - 1; i >= 0; i--) {
        if (movable(ws[i]) && ws[i].output === from) { send(ws[i], from, to); return; }
    }
    print("duo-dualscreen: no app on " + name);
}

registerShortcut("DuoMoveRight", "Duo: move app to the next screen", "Meta+Shift+Right", function () { move(+1); });
registerShortcut("DuoMoveLeft", "Duo: move app to the previous screen", "Meta+Shift+Left", function () { move(-1); });
registerShortcut("DuoMoveOther", "Duo: move app to the other screen", "Meta+Shift+O", function () { move(0); });
registerShortcut("DuoMoveFromDSI-1", "Duo: move the left screen's app to the right screen", "", function () { moveFrom("DSI-1"); });
registerShortcut("DuoMoveFromDSI-2", "Duo: move the right screen's app to the left screen", "", function () { moveFrom("DSI-2"); });
print("duo-dualscreen: loaded, " + workspace.screens.length + " screens");
