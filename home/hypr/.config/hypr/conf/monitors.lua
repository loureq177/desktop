hl.monitor({
	output = "eDP-1",
	mode = "highres",
	position = "0x0",
})
hl.monitor({
	output = "",
	mode = "highres",
	position = "auto",
})

hl.bind("switch:on:Lid Switch", function()
	hl.monitor({ output = "eDP-1", disabled = true })

	hl.timer(function()
		local idx = 1
		for _, m in ipairs(hl.get_monitors()) do
			if m.name ~= "eDP-1" then
				hl.dispatch(hl.dsp.workspace.rename(m.active_workspace.id .. " " .. idx))
				idx = idx + 1
			end
		end
	end, { timeout = 500, type = "oneshot" })
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
	hl.monitor({ output = "eDP-1", disabled = false, mode = "highres", position = "0x0" })

	for _, ws in ipairs(hl.get_workspaces()) do
		hl.dispatch(hl.dsp.workspace.rename(ws.id .. " " .. ws.id))
	end
end, { locked = true })
