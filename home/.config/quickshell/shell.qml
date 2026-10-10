//@ pragma IconTheme Papirus-Dark
import Quickshell
import Quickshell.Io
import QtQuick
import "views"

ShellRoot {
	id: root

	function viewFor(name: string): var {
		switch (name) {
		case "launcher": return launcherView;
		case "keybindings": return keysView;
		case "clipboard": return clipboardView;
		case "weather": return Weather;
		}
		return null;
	}

	function closeOthers(name: string): void {
		Notifications.closeCenter();
		QuickSettings.close();
		for (const other of ["launcher", "keybindings", "clipboard", "weather"]) {
			if (other !== name)
				viewFor(other).close();
		}
	}

	Variants {
		model: Quickshell.screens
		Bar {
		}
	}

	LauncherView {
		id: launcherView
		onOpened: {
			Notifications.hideToasts();
			root.closeOthers("launcher");
		}
	}

	KeybindingsView {
		id: keysView
		onOpened: {
			Notifications.hideToasts();
			root.closeOthers("keybindings");
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
			root.closeOthers("clipboard");
		}
	}

	QuickSettingsView {
		id: quickSettingsView
	}

	WeatherView {
		id: weatherView
		onOpened: {
			Notifications.hideToasts();
			root.closeOthers("weather");
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
			root.closeOthers(name);
			root.viewFor(name)?.open(mode);
		}

		function hide(name: string): void {
			root.closeOthers(name);
			root.viewFor(name)?.close();
		}

		function toggle(name: string, mode: string): void {
			root.closeOthers(name);
			root.viewFor(name)?.toggle(mode);
		}
	}
}
