//@ pragma IconTheme Papirus-Dark
// Keep in sync with ui.toml [theme] icon and hyprland.lua QS_ICON_THEME.
// Without a pinned theme Quickshell follows the Qt platform theme (hicolor
// fallback here, since QT_QPA_PLATFORMTHEME is intentionally unset), so
// LauncherView iconPath() intermittently misses Papirus icons.
// Quickshell daemon: hosts the bar, launcher, keybindings cheatsheet,
// notification surfaces (sticky toasts + control center) and the polkit
// authentication dialog. Started from Hyprland autostart: `quickshell -d`.
// Control via IPC:
//   qs ipc call shell summon launcher apps|emoji|power
//   qs ipc call shell summon keybindings ""
//   qs ipc call shell toggle launcher apps
//   qs ipc call shell hide launcher
//   qs ipc call notifications toggle|toggleDnd|dndOn|dndOff|clear|dismissLatest|invokeAction|invokeDefault|status
//   qs ipc call osd volume|brightness|mic|touchpad
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
		onOpened: {
			Notifications.hideToasts();
			keysView.close();
			clipboardView.close();
			Notifications.closeCenter();
			QuickSettings.close();
			Weather.close();
		}
	}

	KeybindingsView {
		id: keysView
		onOpened: {
			Notifications.hideToasts();
			launcherView.close();
			clipboardView.close();
			Notifications.closeCenter();
			QuickSettings.close();
			Weather.close();
		}
	}

	NotificationToasts {
		id: notifToasts
	}

	NotificationCenter {
		id: notifCenter
	}

	ClipboardView {
		id: clipboardView
		onOpened: {
			Notifications.hideToasts();
			launcherView.close();
			keysView.close();
			Notifications.closeCenter();
			QuickSettings.close();
			Weather.close();
		}
	}

	QuickSettingsView {
		id: quickSettingsView
	}

	WeatherView {
		id: weatherView
		onOpened: {
			Notifications.hideToasts();
			launcherView.close();
			keysView.close();
			clipboardView.close();
			Notifications.closeCenter();
			QuickSettings.close();
		}
		onDismissed: Weather.close()
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
			QuickSettings.close();
			Weather.close();
			if (name === "launcher") {
				keysView.close();
				clipboardView.close();
				launcherView.open(mode);
			} else if (name === "keybindings") {
				launcherView.close();
				clipboardView.close();
				keysView.open();
			} else if (name === "clipboard") {
				launcherView.close();
				keysView.close();
				clipboardView.open();
			} else if (name === "weather") {
				launcherView.close();
				keysView.close();
				clipboardView.close();
				Weather.open();
			}
		}

		function hide(name: string): void {
			Notifications.closeCenter();
			QuickSettings.close();
			Weather.close();
			if (name === "launcher")
				launcherView.close();
			else if (name === "keybindings")
				keysView.close();
			else if (name === "clipboard")
				clipboardView.close();
			else if (name === "weather")
				Weather.close();
		}

		function toggle(name: string, mode: string): void {
			Notifications.closeCenter();
			QuickSettings.close();
			if (name === "launcher") {
				Weather.close();
				keysView.close();
				clipboardView.close();
				launcherView.toggle(mode);
			} else if (name === "keybindings") {
				Weather.close();
				launcherView.close();
				clipboardView.close();
				keysView.toggle();
			} else if (name === "clipboard") {
				Weather.close();
				launcherView.close();
				keysView.close();
				clipboardView.toggle();
			} else if (name === "weather") {
				launcherView.close();
				keysView.close();
				clipboardView.close();
				Weather.toggle();
			}
		}
	}
}
