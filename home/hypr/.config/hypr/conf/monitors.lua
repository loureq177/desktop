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
		local workspace_index = 1
		for _, display_monitor in ipairs(hl.get_monitors()) do
			if display_monitor.name ~= "eDP-1" then
				hl.dispatch(hl.dsp.workspace.rename(display_monitor.active_workspace.id .. " " .. workspace_index))
				workspace_index = workspace_index + 1
			end
		end
	end, { timeout = 500, type = "oneshot" })
end, { locked = true })

hl.bind("switch:off:Lid Switch", function()
	hl.monitor({ output = "eDP-1", disabled = false, mode = "highres", position = "0x0" })

	for _, active_workspace in ipairs(hl.get_workspaces()) do
		hl.dispatch(hl.dsp.workspace.rename(active_workspace.id .. " " .. active_workspace.id))
	end
end, { locked = true })
