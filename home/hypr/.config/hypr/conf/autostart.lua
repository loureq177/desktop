local gsettings = "gsettings set org.gnome.desktop.interface"
local env_vars = table.concat({
	"DISPLAY",
	"WAYLAND_DISPLAY",
	"XDG_CURRENT_DESKTOP",
	"XDG_SESSION_TYPE",
	"XDG_SESSION_DESKTOP",
	"GTK_THEME",
	"GTK_USE_PORTAL",
	"ELECTRON_OZONE_PLATFORM_HINT",
	"__GLX_VENDOR_LIBRARY_NAME",
	"LIBVA_DRIVER_NAME",
	"GBM_BACKEND",
	"GDK_BACKEND",
}, " ")

hl.on("hyprland.start", function()
	local cmds = {
		"dbus-update-activation-environment --systemd " .. env_vars,
		"systemctl --user import-environment " .. env_vars,
		gsettings .. " cursor-theme 'Bibata-Modern-Classic'",
		gsettings .. " icon-theme 'Papirus-Dark'",
		gsettings .. " font-name 'Adwaita Sans 13'",
		gsettings .. " color-scheme 'prefer-dark'",
		gsettings .. " gtk-theme 'Adwaita-dark'",
		gsettings .. " monospace-font-name 'JetBrainsMono Nerd Font Mono 13'",
		"systemctl --user start graphical-session.target",
		"systemctl --user start xdg-desktop-portal-hyprland "
			.. "xdg-desktop-portal-gtk xdg-desktop-portal",
		"wl-paste --type text --watch cliphist -max-items 50 store &",
		"wl-paste --type image/png --watch cliphist -max-items 10 store &",
		"wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.4",
		"waybar &",
		"swaybg -i ~/Pictures/Wallpapers/hyprland-dark.png &",
		"swaync &",
		"hypridle &",
		"hyprsunset &",
	}

	for _, cmd in ipairs(cmds) do
		hl.exec_cmd(cmd)
	end
end)
