---@mod devcontainer.config_file.parse Devcontainer config file parsing module
---@brief [[
---Provides support for parsing specific devcontainer.json files as well as
---automatic discovery and parsing of nearest file
---Ensures basic configuration required for the plugin to work is present in files
---@brief ]]
local jsonc = require("devcontainer.config_file.jsonc")
local uv = vim.loop

local M = {}

local function readFileSync(path)
	local fd = assert(uv.fs_open(path, "r", 438))
	local stat = assert(uv.fs_fstat(fd))
	local data = assert(uv.fs_read(fd, stat.size, 0))
	assert(uv.fs_close(fd))
	return data
end

---Parse specific devcontainer.json file into a Lua table
---Ensures that at least one of "image", "dockerFile" or "dockerComposeFile" keys is present
---@param config_file_path string
---@return table
---@usage `require("devcontainer.config_file.parse").parse_devcontainer_config([[{ "image": "test" }]])`
function M.parse_devcontainer_config(config_file_path)
	local content = readFileSync(config_file_path)
	local config = vim.tbl_extend("keep", jsonc.parse_jsonc(content), { build = {}, hostRequirements = {} })
	if
		config.image == nil
		and config.dockerFile == nil
		and (config.build.dockerfile == nil)
		and config.dockerComposeFile == nil
	then
		error("Either image, dockerFile or dockerComposeFile need to be present in the file")
	end
	return vim.tbl_deep_extend("force", config, { metadata = { file_path = config_file_path } })
end

---Parse nearest devcontainer.json file into a Lua table
---Prefers .devcontainer.json over .devcontainer/devcontainer.json
---Looks in CWD first and then moves up all the way until root
---Fails if no devcontainer.json files were found, or if the first one found is invalid
---@return table
---@usage `require("devcontainer.config_file.parse").parse_nearest_devcontainer_config()`
function M.parse_nearest_devcontainer_config()
	local directory = uv.cwd()
	local last_ino = nil
	while true do
		local dir_exists, directory_info = pcall(uv.fs_stat, directory)
		if not dir_exists or directory_info == nil or directory_info.ino == last_ino then
			error("No devcontainer files found!")
		end
		last_ino = directory_info.ino
		for _, file in pairs({ ".devcontainer.json", ".devcontainer/devcontainer.json" }) do
			local path = directory .. "/" .. file
			local success, data = pcall(uv.fs_stat, path)
			if success and data ~= nil then
				return M.parse_devcontainer_config(path)
			end
		end
		directory = directory .. "/.."
	end
end

return M
