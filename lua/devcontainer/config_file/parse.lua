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
	local config = jsonc.parse_jsonc(content)
	if
		config.image == nil
		and config.dockerFile == nil
		and (config.build == nil or config.build.dockerfile == nil)
		and config.dockerComposeFile == nil
	then
		error("Either image, dockerFile or dockerComposeFile need to be present in the file")
	end
	return vim.tbl_deep_extend("force", config, { metadata = { file_path = config_file_path } })
end

return {
	parse_devcontainer_config = parse_devcontainer_config,
}
