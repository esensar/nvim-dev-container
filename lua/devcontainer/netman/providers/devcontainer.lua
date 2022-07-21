---@mod devcontainer.netman.providers.devcontainer Devcontainer provider for Netman.nvim
---@brief [[
---Provides netman.nvim support for devcontainer
---When this module is used with netman.nvim, it enables access to devcontainer:// protocol for accesing files
---@brief ]]
local executor = require("devcontainer.internal.executor")
local api_flags = require("netman.options").api
local string_generator = require("netman.utils").generate_string
local local_files = require("netman.utils").files_dir
local u = require("devcontainer.internal.utils")

local container_pattern = "^([%a%c%d%s%-_%.]*)"
local path_pattern = "^([\\/]?)(.*)$"
local protocol_pattern = "^(.*)://"

local function parse_uri(uri)
	local details = {
		base_uri = uri,
		command = nil,
		protocol = nil,
		container = nil,
		path = nil,
		file_type = nil,
		return_type = nil,
		parent = nil,
		local_file = nil,
	}
	details.protocol = uri:match(protocol_pattern)
	uri = uri:gsub(protocol_pattern, "")
	details.container = uri:match(container_pattern) or ""
	uri = uri:gsub(container_pattern, "")
	local path_head, path_body = uri:match(path_pattern)
	path_body = path_body or ""
	if path_head:len() ~= 1 then
		-- TODO: Add default path
		details.path = u.path_sep .. path_body
	else
		details.path = u.path_sep .. path_body
	end
	if details.path:sub(-1) == u.path_sep or details.path:sub(-1) == "." then
		details.file_type = api_flags.ATTRIBUTES.DIRECTORY
		details.return_type = api_flags.READ_TYPE.EXPLORE
	else
		details.file_type = api_flags.ATTRIBUTES.FILE
		details.return_type = api_flags.READ_TYPE.FILE
		details.unique_name = string_generator(11)
		details.local_file = local_files .. details.unique_name
	end
	local parts = vim.split(details.path, u.path_sep)
	table.remove(parts, #parts)
	details.parent = table.concat(parts, u.path_sep)
	return details
end

local M = {}

M.protocol_patterns = { "devcontainer" }
M.name = "devcontainer"
M.version = 0.1

function M:read(uri, cache)
	if next(cache) == nil then
		cache = parse_uri(uri)
	end
	return true
end

function M:init(_)
	return executor.is_executable("docker") and executor.is_executable("docker-compose")
end

return M
