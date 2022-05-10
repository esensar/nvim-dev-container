local jsonc = require("devcontainer.config_file.jsonc")
local uv = vim.loop

local function readFileSync(path)
	local fd = assert(uv.fs_open(path, "r", 438))
	local stat = assert(uv.fs_fstat(fd))
	local data = assert(uv.fs_read(fd, stat.size, 0))
	assert(uv.fs_close(fd))
	return data
end

local function parse_devcontainer_config(config_file_path)
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

local function parse_nearest_devcontainer_config()
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
				return parse_devcontainer_config(path)
			end
		end
		directory = directory .. "/.."
	end
end

return {
	parse_devcontainer_config = parse_devcontainer_config,
	parse_nearest_devcontainer_config = parse_nearest_devcontainer_config,
}
