//@ pragma IconTheme Papirus-Dark
import Quickshell
import Quickshell.Io
import QtQuick
import "views"

ShellRoot {
	id: root

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
