local programs = require("conf.programs")

hl.on("hyprland.start", function()
	-- environment setup
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

	hl.exec_cmd("hyprpm reload -n")
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("nm-applet")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("aw-qt")

	-- ui preferences
	hl.exec_cmd("hyprctl setcursor Adwaita 24")
	hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'")
	hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'")
	hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 12'")
	hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:close'")

	-- utility tools
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	-- hl.exec_cmd("wl-paste --type image --watch cliphist store") -- Wyłączone, żeby oszczędzić RAM
	hl.exec_cmd("hyprsunset")
end)
