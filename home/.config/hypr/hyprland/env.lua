-- Set for Hyprland and exported to the systemd user session at start, where
-- the shell and the other session services run (autostart.lua).

local ui = require("ui")
local machine = require("hyprland.machine")

local exported = { "WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP", "HYPRLAND_INSTANCE_SIGNATURE" }
local function env(name, value)
	hl.env(name, value)
	table.insert(exported, name)
end

local function read(path)
	local f = io.open(path)
	if f == nil then
		return ""
	end
	local out = f:read("*a") or ""
	f:close()
	return (out:gsub("%s+$", ""))
end

-- The kernel has no flag for it: Intel's sits at 00:02.0, and only AMD's discrete GPUs
-- report who made their VRAM.
local function integrated(card)
	local vendor = read(card .. "/device/vendor")
	if vendor == "0x8086" then
		return (io.popen("readlink -f " .. card .. "/device"):read("*a")):find("0000:00:02.0", 1, true) ~= nil
	end
	return vendor == "0x1002" and read(card .. "/device/mem_info_vram_vendor") == ""
end

-- With an integrated GPU the session renders on it, external screens or not, and clients
-- follow; the dGPU is for what asks for it. With one GPU there is nothing to choose.
local function prefer_integrated()
	local igpu, others = nil, {}
	for card in io.popen("ls -d /sys/class/drm/card? 2>/dev/null"):lines() do
		if igpu == nil and integrated(card) then
			igpu = card
		else
			table.insert(others, card)
		end
	end
	if igpu == nil or others[1] == nil then
		return
	end
	local devices = { "/dev/dri/" .. igpu:match("card%d+$") }
	for _, card in ipairs(others) do
		table.insert(devices, "/dev/dri/" .. card:match("card%d+$"))
	end
	-- Kept for the life of the session: a reload must not change it.
	env("AQ_DRM_DEVICES", os.getenv("AQ_DRM_DEVICES") or table.concat(devices, ":"))
	local amd = read(igpu .. "/device/vendor") == "0x1002"
	local icd = "/usr/share/vulkan/icd.d/" .. (amd and "radeon" or "intel") .. "_icd.json"
	if io.open(icd) == nil then
		icd = icd:gsub("_icd.json$", "_icd.x86_64.json")
	end
	env("VK_DRIVER_FILES", icd)
	env("VK_ICD_FILENAMES", icd)
	env("LIBVA_DRIVER_NAME", amd and "radeonsi" or "iHD")
end

prefer_integrated()
machine.env(env)

env("GSK_RENDERER", "gl")
env("GTK_A11Y", "none")
env("XDG_SESSION_DESKTOP", "Hyprland")
env("GDK_WAYLAND_DISABLE", "ext_background_effect_manager_v1")
env("QS_ICON_THEME", ui.theme.icon)
for _, prefix in ipairs({ "XCURSOR", "HYPRCURSOR" }) do
	env(prefix .. "_THEME", ui.theme.cursor)
	env(prefix .. "_SIZE", tostring(ui.font.size_cursor))
end
env("SAL_USE_VCLPLUGIN", "gtk3")
-- Qt programs in the desktop's palette and icons (apply-ui renders qt6ct's files).
env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- NVDEC drops parts of keyframes in wf-recorder's casts: libav decodes H.264.
env("GST_PLUGIN_FEATURE_RANK", "nvh264dec:NONE")

return { set = env, exported = exported }
