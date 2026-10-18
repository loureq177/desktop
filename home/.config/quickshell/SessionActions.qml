pragma Singleton
import Quickshell
import QtQuick

// Lock, suspend, log out, reboot and power off, for the launcher and the
// quick settings power page. The last three ask first: whoever offers them
// runs them only on a second press (`confirm`).
Singleton {
	id: root

	readonly property var actions: [
		{ id: "lock", label: "Lock", desc: "Lock the session", icon: "system-lock-screen", lineIcon: "lock", confirm: false, verb: "lock", keywords: "lock zablokuj ekran lockscreen" },
		{ id: "suspend", label: "Suspend", desc: "Lock and sleep", icon: "system-suspend", lineIcon: "moon", confirm: false, verb: "suspend", keywords: "suspend sleep uspij uśpij drzemka" },
		{ id: "logout", label: "Log out", desc: "Close every app and end the session", icon: "system-log-out", lineIcon: "log-out", confirm: true, verb: "log out", keywords: "logout log out relogin relog exit wyloguj przeloguj sesja" },
		{ id: "reboot", label: "Reboot", desc: "Close every app and restart", icon: "system-reboot", lineIcon: "rotate-cw", confirm: true, verb: "reboot", keywords: "reboot restart uruchom ponownie zrestartuj" },
		{ id: "poweroff", label: "Power off", desc: "Close every app and shut down", icon: "system-shutdown", lineIcon: "power", confirm: true, verb: "power off", keywords: "poweroff shutdown wylacz wyłącz power" }
	]

	readonly property var commands: ({
		"lock": ["sh", "-c", "loginctl lock-session"],
		"suspend": ["sh", "-c", "loginctl lock-session && systemctl suspend"],
		"logout": ["hyprshutdown"],
		"reboot": ["hyprshutdown", "--post-cmd", "systemctl reboot"],
		"poweroff": ["hyprshutdown", "--post-cmd", "systemctl poweroff"]
	})

	function run(id: string): bool {
		var cmd = commands[id];
		if (!cmd)
			return false;
		Quickshell.execDetached(["env", "-u", "__EGL_VENDOR_LIBRARY_FILENAMES", "-u", "MALLOC_CONF"].concat(cmd));
		return true;
	}
}
