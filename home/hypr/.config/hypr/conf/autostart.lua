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
	hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'")
	hl.exec_cmd("gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font Mono 13'")

	hl.exec_cmd("systemctl --user start hyprpolkitagent")

	hl.exec_cmd("wl-paste --type text --watch cliphist -max-items 50 store &")
	hl.exec_cmd("wl-paste --type image/png --watch cliphist -max-items 10 store &")
	hl.exec_cmd("hyprsunset &")
	hl.exec_cmd("waybar &")
	hl.exec_cmd("swaybg -i ~/Pictures/Wallpapers/hyprland.png -m fill")
	hl.exec_cmd("hypridle &")
	hl.exec_cmd("mako &")
end)
