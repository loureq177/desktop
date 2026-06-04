hl.on("hyprland.start", function()
	hl.exec_cmd(
		"dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP"
	)
	hl.exec_cmd(
		"systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP"
	)
	hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'")
	hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'")
	hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'Adwaita Sans 12'")
	hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:close'")
	hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")

	hl.exec_cmd("hyprpm reload -n &")
	hl.exec_cmd("nm-applet &")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("aw-qt &")
	hl.exec_cmd("wl-paste --type text --watch cliphist -max-items 20 store &")
	hl.exec_cmd("hyprsunset &")
	hl.exec_cmd("waybar &")
	hl.exec_cmd("hyprpaper &")
	hl.exec_cmd("hypridle &")
	hl.exec_cmd("mako &")
end)
