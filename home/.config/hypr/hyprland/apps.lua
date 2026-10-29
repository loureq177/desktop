-- The browser and the special workspaces apply-apps renders (~/.config/apps/apps.lua);
-- Firefox and no specials until it has run. dofile, as require errors even in pcall.

local config = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local ok, apps = pcall(dofile, config .. "/apps/apps.lua")
if not ok or type(apps) ~= "table" then
	apps = {}
end

return {
	browser = type(apps.browser) == "table" and apps.browser or { exec = "firefox" },
	specials = type(apps.specials) == "table" and apps.specials or {},
	background = type(apps.background) == "table" and apps.background or {},
}
