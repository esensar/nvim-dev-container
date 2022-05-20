---@mod devcontainer.docker-compose Docker-compose module
---@brief [[
---Provides functions related to docker-compose control
---@brief ]]
local exe = require("devcontainer.internal.executor")
local v = require("devcontainer.internal.validation")
local log = require("devcontainer.internal.log")

local M = {}

---Runs docker command with passed arguments
---@param args string[]
---@param opts RunCommandOpts|nil
---@param onexit function(code, signal)
local function run_docker_compose(args, opts, onexit)
	exe.ensure_executable("docker-compose")

	opts = opts or {}
	exe.run_command(
		"docker-compose",
		vim.tbl_extend("force", opts, {
			args = args,
			stderr = vim.schedule_wrap(function(err, data)
				if data then
					log.fmt_error("Docker-compose command (%s): %s", args, data)
				end
				if opts.stderr then
					opts.stderr(err, data)
				end
			end),
		}),
		onexit
	)
end

---Prepare compose command arguments with file or files
---@param compose_file string|table
local function get_compose_files_command(compose_file)
	local command = nil
	if type(compose_file) == "table" then
		command = {}
		for _, file in ipairs(compose_file) do
			table.insert(command, "-f")
			table.insert(command, file)
		end
	elseif type(compose_file) == "string" then
		command = { "-f", compose_file }
	end
	return command
end

---@class DockerComposeUpOpts
---@field args table|nil list of additional arguments to up command
---@field on_success function() success callback
---@field on_fail function() failure callback

---Run docker-compose up with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts DockerComposeUpOpts Additional options including callbacks
---@usage `require("devcontainer.docker-compose").up("docker-compose.yml")`
function M.up(compose_file, opts)
	vim.validate({
		compose_file = { compose_file, { "string", "table" } },
	})
	opts = opts or {}
	v.validate_callbacks(opts)
	local on_success = opts.on_success
		or function()
			vim.notify("Successfully started services from " .. compose_file)
		end
	local on_fail = opts.on_fail
		or function()
			vim.notify("Starting services from " .. compose_file .. " failed!", vim.log.levels.ERROR)
		end
	local command = get_compose_files_command(compose_file)
	vim.list_extend(command, { "up", "-d" })
	vim.list_extend(command, opts.args or {})
	run_docker_compose(command, nil, function(code, _)
		if code == 0 then
			on_success()
		else
			on_fail()
		end
	end)
end

---@class DockerComposeDownOpts
---@field on_success function() success callback
---@field on_fail function() failure callback

---Run docker-compose down with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts DockerComposeDownOpts Additional options including callbacks
---@usage `require("devcontainer.docker-compose").down("docker-compose.yml")`
function M.down(compose_file, opts)
	vim.validate({
		compose_file = { compose_file, { "string", "table" } },
	})
	opts = opts or {}
	v.validate_callbacks(opts)
	local on_success = opts.on_success
		or function()
			vim.notify("Successfully stopped services from " .. compose_file)
		end
	local on_fail = opts.on_fail
		or function()
			vim.notify("Stopping services from " .. compose_file .. " failed!", vim.log.levels.ERROR)
		end
	local command = get_compose_files_command(compose_file)
	vim.list_extend(command, { "down" })
	run_docker_compose(command, nil, function(code, _)
		if code == 0 then
			on_success()
		else
			on_fail()
		end
	end)
end

---@class DockerComposeGetContainerIdOpts
---@field on_success function(container_id) success callback
---@field on_fail function() failure callback

---Run docker-compose ps with passed file and service to get its container_id
---@param compose_file string|table path to docker-compose.yml file or files
---@param service string service name
---@param opts DockerComposeGetContainerIdOpts Additional options including callbacks
---@usage `docker_compose.get_container_id("docker-compose.yml", { on_success = function(container_id) end })`
function M.get_container_id(compose_file, service, opts)
	vim.validate({
		compose_file = { compose_file, { "string", "table" } },
		service = { service, "string" },
	})
	opts = opts or {}
	v.validate_callbacks(opts)
	local on_success = opts.on_success
		or function(container_id)
			vim.notify("Container id of service " .. service .. " from " .. compose_file .. " is " .. container_id)
		end
	local on_fail = opts.on_fail
		or function()
			vim.notify(
				"Fetching container id for " .. service .. " from " .. compose_file .. " failed!",
				vim.log.levels.ERROR
			)
		end
	local command = get_compose_files_command(compose_file)
	vim.list_extend(command, { "ps", "-q", service })
	local container_id = nil
	run_docker_compose(command, {
		stdout = function(_, data)
			if data then
				container_id = vim.split(data, "\n")[1]
			end
		end,
	}, function(code, _)
		if code == 0 then
			on_success(container_id)
		else
			on_fail()
		end
	end)
end

log.wrap(M)
return M
