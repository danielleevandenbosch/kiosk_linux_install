#!/usr/bin/env python3
# Author: Daniel L. Van Den Bosch
# Date: 2025
# keyboard_toggle.py

import gi
import os
import time
import subprocess

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk

SCREEN_W = Gdk.Screen.get_default().get_width()
SCREEN_H = Gdk.Screen.get_default().get_height()
TOGGLE_H = 40
KBD_H = SCREEN_H // 3
BROWSER_H = SCREEN_H - KBD_H - TOGGLE_H


class ToggleWindow(Gtk.Window):
    def __init__(self):
        Gtk.Window.__init__(self, title="Toggle")
        self.set_decorated(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_accept_focus(False)
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.set_resizable(False)
        self.set_border_width(0)

        button = Gtk.Button(label="⌨")
        button.set_size_request(60, 40)
        button.connect("clicked", self.on_click)
        self.add(button)

        self.set_size_request(60, 40)
        self.move(SCREEN_W - 70, SCREEN_H - 50)


    def move(self, x, y):
        self.connect("realize", lambda w: w.move(x, y))

    def on_click(self, widget):
        if "onboard" in subprocess.getoutput("pgrep -a onboard"):
            subprocess.call(["pkill", "onboard"])
            subprocess.call(["wmctrl", "-r", ":ACTIVE:", "-e", f"0,0,{TOGGLE_H},{SCREEN_W},{SCREEN_H - TOGGLE_H}"])
        else:
            subprocess.Popen(["onboard"])
            time.sleep(2)
            subprocess.call(["wmctrl", "-r", "Onboard", "-b", "add,above"])
            subprocess.call(["wmctrl", "-r", "Onboard", "-e", f"0,0,{BROWSER_H},{SCREEN_W},{KBD_H}"])
            subprocess.call(["wmctrl", "-r", ":ACTIVE:", "-e", f"0,0,0,{SCREEN_W},{BROWSER_H}"])

win = ToggleWindow()
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
