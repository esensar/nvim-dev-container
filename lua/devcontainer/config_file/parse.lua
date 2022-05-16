---@mod devcontainer.config_file.parse Devcontainer config file parsing module
---@brief [[
---Provides support for parsing specific devcontainer.json files as well as
---automatic discovery and parsing of nearest file
---Ensures basic configuration required for the plugin to work is present in files
---@brief ]]
local jsonc = require("devcontainer.config_file.jsonc")
local config = require("devcontainer.config")
local uv = vim.loop

local M = {}

local function readFileAsync(path, callback)
	uv.fs_open(path, "r", 438, function(err_open, fd)
		if err_open then
			return callback(err_open, nil)
		end
		uv.fs_fstat(fd, function(err_stat, stat)
			if err_stat then
				return callback(err_stat, nil)
			end
			uv.fs_read(fd, stat.size, 0, function(err_read, data)
				if err_read then
					return callback(err_read, nil)
				end
				uv.fs_close(fd, function(err_close)
					if err_close then
						return callback(err_close, nil)
					end
					return callback(nil, data)
				end)
			end)
		end)
	end)
end

local function readFileSync(path)
	local fd = assert(uv.fs_open(path, "r", 438))
	local stat = assert(uv.fs_fstat(fd))
	local data = assert(uv.fs_read(fd, stat.size, 0))
	assert(uv.fs_close(fd))
	return data
end

local function invoke_callback(callback, success, data)
	if success then
		callback(nil, data)
	else
		callback(data, nil)
	end
end

local function parse_devcontainer_content(config_file_path, content)
	local parsed_config = vim.tbl_extend("keep", jsonc.parse_jsonc(content), { build = {}, hostRequirements = {} })
	if
		parsed_config.image == nil
		and parsed_config.dockerFile == nil
		and (parsed_config.build.dockerfile == nil)
		and parsed_config.dockerComposeFile == nil
	then
		error("Either image, dockerFile or dockerComposeFile need to be present in the file")
	end
	return vim.tbl_deep_extend("force", parsed_config, { metadata = { file_path = config_file_path } })
end

---Parse specific devcontainer.json file into a Lua table
---Ensures that at least one of "image", "dockerFile" or "dockerComposeFile" keys is present
---@param config_file_path string
---@param callback function(err,data)|nil if nil run sync, otherwise run async and pass result to the callback
---@return table|nil result or nil if running async
---@usage `require("devcontainer.config_file.parse").parse_devcontainer_config([[{ "image": "test" }]])`
function M.parse_devcontainer_config(config_file_path, callback)
	vim.validate({
		config_file_path = { config_file_path, "string" },
		callback = { callback, { "function", "nil" } },
	})
	if callback then
		readFileAsync(
			config_file_path,
			vim.schedule_wrap(function(err, content)
				if err then
					callback(err, nil)
				else
					local success, data = pcall(parse_devcontainer_content, config_file_path, content)
					invoke_callback(callback, success, data)
				end
			end)
		)
		return nil
	end
	local content = readFileSync(config_file_path)
	return parse_devcontainer_content(config_file_path, content)
end

local function find_nearest_devcontainer_file(callback)
	local directory = config.config_search_start()
	local last_ino = nil

	local function directory_callback(err, data)
		if err or data == nil or data.ino == last_ino then
			if callback then
				return callback("No devcontainer files found!", nil)
			else
				error("No devcontainer files found!")
			end
		end
		last_ino = data.ino
		local files = { ".devcontainer.json", ".devcontainer/devcontainer.json" }
		if callback then
			local index = 1
			local function file_callback(_, file_data)
				if file_data then
					local path = directory .. "/" .. files[index]
					callback(nil, path)
				else
					index = index + 1
					if index > #files then
						directory = directory .. "/.."
						uv.fs_stat(directory, directory_callback)
					else
						local path = directory .. "/" .. files[index]
						uv.fs_stat(path, file_callback)
					end
				end
			end

			local path = directory .. "/" .. files[index]
			return uv.fs_stat(path, file_callback)
		end

		for _, file in pairs(files) do
			local path = directory .. "/" .. file
			local success, stat_data = pcall(uv.fs_stat, path)
			if success and stat_data ~= nil then
				return path
			end
		end
		directory = directory .. "/.."
		local dir_exists, directory_info = pcall(uv.fs_stat, directory)
		local dir_err = nil
		local dir_data = nil
		if dir_exists then
			dir_data = directory_info
		else
			dir_err = directory_info or "Not found"
		end
		return directory_callback(dir_err, dir_data)
	end

	if callback then
		return uv.fs_stat(directory, directory_callback)
	else
		local dir_exists, directory_info = pcall(uv.fs_stat, directory)
		local dir_err = nil
		local dir_data = nil
		if dir_exists then
			dir_data = directory_info
		else
			dir_err = directory_info
		end
		return directory_callback(dir_err, dir_data)
	end
end

---Parse nearest devcontainer.json file into a Lua table
---Prefers .devcontainer.json over .devcontainer/devcontainer.json
---Looks in CWD first and then moves up all the way until root
---Fails if no devcontainer.json files were found, or if the first one found is invalid
---@param callback function(err,data)|nil if nil run sync, otherwise run async and pass result to the callback
---@return table|nil result or nil if running async
---@usage `require("devcontainer.config_file.parse").parse_nearest_devcontainer_config()`
function M.parse_nearest_devcontainer_config(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})
	if callback then
		return find_nearest_devcontainer_file(function(err, data)
			if err then
				callback(err, nil)
			else
				M.parse_devcontainer_config(data, callback)
			end
		end)
	else
		return M.parse_devcontainer_config(find_nearest_devcontainer_file(nil), nil)
	end
end

return M
