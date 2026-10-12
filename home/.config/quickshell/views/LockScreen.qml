import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick

Scope {
	id: root

	property string password: ""
	property string failText: ""
	property bool checking: false
	property bool showBackdrop: true
	// Drives the surfaces' fade; the lock itself engages and releases around it.
	property bool shown: false

	property double fingerprintStarted: 0
	property int fingerprintFastFails: 0

	readonly property bool locked: sessionLock.locked
	readonly property string backdropDir: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-lock"

	function backdropPath(screen): string {
		return backdropDir + "/" + screen.name + ".ppm";
	}

	// The desktop as it was when the lock engaged. Without a screenshot (boot,
	// restored lock, grim failure) the wallpaper stands in for it.
	function backdropSource(screen): string {
		return showBackdrop ? "file://" + backdropPath(screen) : Wallpaper.url;
	}

	// The desktop is screenshotted before the lock engages; once it has, the
	// compositor may already hand out black frames.
	function lock(): void {
		if (screenshots.running || (sessionLock.locked && !unlockTimer.running))
			return;
		stateFile.setText("locked");
		if (sessionLock.locked) {
			engage(showBackdrop);
			return;
		}
		screenshots.command = ["sh", "-c",
			'mkdir -p "$0" && for o in "$@"; do grim -t ppm -o "$o" "$0/$o.ppm" & done; wait',
			backdropDir].concat(Quickshell.screens.map(s => s.name));
		screenshots.running = true;
		screenshotTimeout.restart();
	}

	function engage(withBackdrop: bool): void {
		screenshotTimeout.stop();
		unlockTimer.stop();
		if (!sessionLock.locked)
			showBackdrop = withBackdrop;
		password = "";
		failText = "";
		fingerprintFastFails = 0;
		sessionLock.locked = true;
		shown = true;
		startFingerprint();
	}

	function unlock(): void {
		shown = false;
		fingerprintRetry.stop();
		if (fingerprintPam.active)
			fingerprintPam.abort();
		unlockTimer.restart();
	}

	function submit(): void {
		if (checking || !shown || password === "")
			return;
		checking = true;
		failText = "";
		passwordPam.start();
	}

	function startFingerprint(): void {
		if (shown && !fingerprintPam.active)
			lidState.running = true;
	}

	// Kept per compositor instance: a new session has no state yet, a restarted
	// shell finds the one it left behind.
	FileView {
		id: stateFile
		path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/quickshell-lock-state"
		blockLoading: true
		printErrors: false
	}

	// Only a recorded unlock leaves the session open. Autologin lands here with
	// no state at all, so the lock engages straight away, without the screenshot
	// round trip: there is no desktop to show yet and no frame to spare for one.
	Component.onCompleted: {
		if (stateFile.text().trim() === "unlocked")
			return;
		stateFile.setText("locked");
		engage(false);
	}

	PamContext {
		id: passwordPam
		configDirectory: Quickshell.shellPath("pam")
		config: "password.conf"

		onPamMessage: {
			if (responseRequired)
				respond(root.password);
			else if (messageIsError)
				root.failText = message;
		}

		onCompleted: result => {
			root.checking = false;
			if (result === PamResult.Success) {
				root.unlock();
				return;
			}
			root.password = "";
			if (root.failText === "")
				root.failText = "Authentication failed";
		}
	}

	PamContext {
		id: fingerprintPam
		configDirectory: Quickshell.shellPath("pam")
		config: "fingerprint.conf"

		onCompleted: result => {
			if (!root.shown)
				return;
			if (result === PamResult.Success) {
				root.unlock();
				return;
			}
			// An instant failure means no reader or no enrolled finger: stop
			// retrying instead of spinning for as long as the screen is locked.
			if (Date.now() - root.fingerprintStarted < 1000 && ++root.fingerprintFastFails >= 3)
				return;
			fingerprintRetry.restart();
		}
	}

	// Behind a closed lid the reader is out of reach: asking for a finger there
	// only burns fprintd's attempts, so wait for the lid instead.
	Process {
		id: lidState
		command: ["sh", "-c", "cat /proc/acpi/button/lid/*/state 2>/dev/null"]
		stdout: StdioCollector {
			onStreamFinished: {
				if (!root.shown || fingerprintPam.active)
					return;
				if (text.includes("closed")) {
					fingerprintRetry.restart();
					return;
				}
				root.fingerprintStarted = Date.now();
				fingerprintPam.start();
			}
		}
	}

	Timer {
		id: unlockTimer
		interval: Theme.lockFadeOut
		onTriggered: {
			stateFile.setText("unlocked");
			sessionLock.locked = false;
			root.password = "";
			root.failText = "";
			Quickshell.execDetached(["rm", "-rf", root.backdropDir]);
		}
	}

	Process {
		id: screenshots
		onExited: code => {
			if (!root.shown)
				root.engage(code === 0);
		}
	}

	// A stuck screenshot must never keep the session unlocked.
	Timer {
		id: screenshotTimeout
		interval: 500
		onTriggered: root.engage(false)
	}

	Timer {
		id: fingerprintRetry
		interval: 1000
		onTriggered: root.startFingerprint()
	}

	WlSessionLock {
		id: sessionLock

		WlSessionLockSurface {
			id: surface
			color: Theme.bgMain

			LockSurface {
				anchors.fill: parent
				context: root
				screen: surface.screen
			}
		}
	}

	IpcHandler {
		target: "session"

		function lock(): void {
			root.lock();
		}
	}
}
