#!/usr/bin/env python3
# Author: Daniel L. Van Den Bosch
# Date: 2025
# keyboard_toggle.py

import gi, time, subprocess
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib

SCREEN_W  = Gdk.Screen.get_default().get_width()
SCREEN_H  = Gdk.Screen.get_default().get_height()
TOGGLE_H  = 40                        # reserved top strip
KBD_H     = SCREEN_H // 3
BROWSER_H = SCREEN_H - KBD_H - TOGGLE_H

class ToggleWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Toggle")
        self.set_decorated(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_accept_focus(False)
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)   # panel‑like
        self.set_resizable(False)
        self.set_border_width(0)

        btn = Gtk.Button(label="⌨")
        btn.set_size_request(60, TOGGLE_H-10)
        btn.connect("clicked", self.on_click)
        self.add(btn)

        self.set_size_request(60, TOGGLE_H)
        self.move(SCREEN_W - 70, 5)                   # top‑right

        self.connect("realize", self._add_strut)      # reserve space
        GLib.timeout_add_seconds(5, self._keep_above) # heartbeat

    # ---------- strut helper -------------------------------------------------
    def _add_strut(self, widget):
        wid = widget.get_window().get_xid()
        # Tell WM to reserve TOGGLE_H pixels at the top
        subprocess.call([
            "xprop","-id",str(wid),
            "-f","_NET_WM_STRUT_PARTIAL","32c",
            "-set","_NET_WM_STRUT_PARTIAL",
            f"0, 0, {TOGGLE_H}, 0,   0, 0, 0, 0,   0,{TOGGLE_H},0,0"])
        subprocess.call([
            "xprop","-id",str(wid),
            "-f","_NET_WM_STRUT","32c",
            "-set","_NET_WM_STRUT",f"0, 0, {TOGGLE_H}, 0"])

    # ---------- keep‑above heartbeat -----------------------------------------
    def _keep_above(self):
        wid = self.get_window().get_xid()
        subprocess.call(["wmctrl","-i","-r",str(wid),"-b","add,above"])
        return True                                      # repeat timer

    # ---------- toggle logic --------------------------------------------------
    def on_click(self, _):
        if subprocess.call(["pgrep","-x","onboard"], stdout=subprocess.DEVNULL)==0:
            subprocess.call(["pkill","onboard"])
            subprocess.call([
                "wmctrl","-r",":ACTIVE:",
                "-e",f"0,0,{TOGGLE_H},{SCREEN_W},{SCREEN_H-TOGGLE_H}"])
        else:
            subprocess.Popen(["onboard","--layout=Small"])
            time.sleep(2)
            subprocess.call(["wmctrl","-r","Onboard","-b","add,above"])
            subprocess.call([
                "wmctrl","-r","Onboard",
                "-e",f"0,0,{BROWSER_H},{SCREEN_W},{KBD_H}"])
            subprocess.call([
                "wmctrl","-r",":ACTIVE:",
                "-e",f"0,0,{TOGGLE_H},{SCREEN_W},{BROWSER_H}"])

# ---------- run window -------------------------------------------------------
if __name__ == "__main__":
    win = ToggleWindow()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()
