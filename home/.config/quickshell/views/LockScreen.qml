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

	// A restored lock has no desktop left to screenshot, only the lock itself.
	function backdropPath(screen): string {
		return backdropDir + "/" + screen.name + ".ppm";
	}

	// The desktop is screenshotted before the lock engages; once it has, the
	// compositor may already hand out black frames.
	function lock(restored = false): void {
		if (screenshots.running || (sessionLock.locked && !unlockTimer.running))
			return;
		stateFile.setText("locked");
		if (sessionLock.locked || restored) {
			engage(showBackdrop && !restored);
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
		if (!shown || fingerprintPam.active)
			return;
		fingerprintStarted = Date.now();
		fingerprintPam.start();
	}

	// Lives in XDG_RUNTIME_DIR, so it is missing on the first start after login
	// (autologin boots straight into the lock) and survives a shell restart.
	FileView {
		id: stateFile
		path: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-lock-state"
		blockLoading: true
		printErrors: false
	}

	Component.onCompleted: {
		var state = stateFile.text().trim();
		if (state !== "unlocked")
			lock(state === "locked");
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
