---@mod devcontainer.commands High level devcontainer commands
---@brief [[
---Provides functions representing high level devcontainer commands
---@brief ]]
local docker_compose = require("devcontainer.docker-compose")
local config_file = require("devcontainer.config_file.parse")

local M = {}

local function get_compose_file_from_nearest_config(callback)
	config_file.parse_nearest_devcontainer_config(function(err, data)
		if err then
			vim.notify("Parsing devcontainer config failed: " .. vim.inspect(err))
			return
		end
		if not data.dockerComposeFile then
			vim.notify(
				"Parsed devcontainer file ("
					.. data.metadata.file_path
					.. ") does not contain docker compose definition!"
			)
			return
		end

		callback(config_file.fill_defaults(data))
	end)
end

---Run docker-compose up from nearest devcontainer.json file
---@param callback function|nil called on success - parsed devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").compose_up()`
function M.compose_up(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	local on_success = callback
		or function(config)
			vim.notify("Successfully started services from " .. config.metadata.file_path)
		end

	get_compose_file_from_nearest_config(function(data)
		docker_compose.up(data.dockerComposeFile, {
			on_success = function()
				on_success(data)
			end,
			on_fail = function()
				vim.notify("Docker compose up failed!")
			end,
		})
	end)
end

---Run docker-compose down from nearest devcontainer.json file
---@param callback function|nil called on success - parsed devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").compose_down()`
function M.compose_down(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	local on_success = callback
		or function(config)
			vim.notify("Successfully stopped services from " .. config.metadata.file_path)
		end

	get_compose_file_from_nearest_config(function(data)
		docker_compose.down(data.dockerComposeFile, {
			on_success = function()
				on_success(data)
			end,
			on_fail = function()
				vim.notify("Docker compose down failed!")
			end,
		})
	end)
end

---Run docker-compose rm from nearest devcontainer.json file
---@param callback function|nil called on success - parsed devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").compose_down()`
function M.compose_rm(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	local on_success = callback
		or function(config)
			vim.notify("Successfully removed services from " .. config.metadata.file_path)
		end

	get_compose_file_from_nearest_config(function(data)
		docker_compose.rm(data.dockerComposeFile, {
			on_success = function()
				on_success(data)
			end,
			on_fail = function()
				vim.notify("Docker compose down failed!")
			end,
		})
	end)
end

return M
