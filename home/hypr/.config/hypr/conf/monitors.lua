------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
	output = "eDP-1",
	mode = "1920x1080@165",
	position = "0x0",
	scale = "1",
})

hl.monitor({
	output = "DP-1",
	mode = "2560x1440@60",
	position = "1920x0",
	scale = "1",
})

hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "1",
})
