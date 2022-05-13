local health = require("health")

local function vim_version_string()
	local v = vim.version()
	return v.major .. "." .. v.minor .. "." .. v.patch
end

return {
	check = function()
		health.report_start("Neovim version")

		if not vim.fn.has("nvim-0.7") then
			health.report_error("Please upgrade Neovim to latest version")
		else
			health.report_ok("Neovim version tested and supported: " .. vim_version_string())
		end

		health.report_start("External dependencies")

		local required_executables = { "docker", "docker-compose" }
		for _, executable in ipairs(required_executables) do
			if vim.fn.has("win32") == 1 then
				executable = executable .. ".exe"
			end
			if vim.fn.executable(executable) == 0 then
				health.report_error(
					executable .. " is not executable! It is required for full functionality of this plugin!"
				)
			else
				local handle = io.popen(executable .. " --version")
				local version = handle:read("*a")
				handle:close()
				health.report_ok(version)
			end
		end
	end,
}
