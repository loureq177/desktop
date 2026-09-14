// Quickshell daemon: hosts the bar, launcher, keybindings cheatsheet,
// notification surfaces (sticky toasts + control center) and the polkit
// authentication dialog. Started from Hyprland autostart: `quickshell -d`.
// Control via IPC:
//   qs ipc call shell summon launcher drun|run|emoji|power
//   qs ipc call shell summon keybindings ""
//   qs ipc call shell toggle launcher drun
//   qs ipc call shell hide launcher
//   qs ipc call notifications toggle|toggleDnd|dndOn|dndOff|clear|dismissLatest|invokeAction|invokeDefault|status
//   qs ipc call osd volume|brightness|mic
//   qs ipc call clipboard toggle|open|close
import Quickshell
import Quickshell.Io
import QtQuick
import "views"

ShellRoot {
	id: root

	// One status bar per screen.
	Variants {
		model: Quickshell.screens
		Bar {
		}
	}

	LauncherView {
		id: launcherView
	}

	KeybindingsView {
		id: keysView
	}

	NotificationToasts {
		id: notifToasts
	}

	NotificationCenter {
		id: notifCenter
	}

	ClipboardView {
		id: clipboardView
	}

	Osd {
		id: osd
	}

	PolkitDialog {
		id: polkitDialog
	}

	IpcHandler {
		target: "shell"

		function summon(name: string, mode: string): void {
			Notifications.closeCenter();
			if (name === "launcher") {
				keysView.close();
				launcherView.open(mode);
			} else if (name === "keybindings") {
				launcherView.close();
				keysView.open();
			}
		}

		function hide(name: string): void {
			Notifications.closeCenter();
			if (name === "launcher")
				launcherView.close();
			else if (name === "keybindings")
				keysView.close();
		}

		function toggle(name: string, mode: string): void {
			Notifications.closeCenter();
			if (name === "launcher") {
				keysView.close();
				launcherView.toggle(mode);
			} else if (name === "keybindings") {
				launcherView.close();
				keysView.toggle();
			}
		}
	}
}
