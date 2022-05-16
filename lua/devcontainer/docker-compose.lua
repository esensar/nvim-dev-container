---@mod devcontainer.docker-compose Docker-compose module
---@brief [[
---Provides functions related to docker-compose control
---@brief ]]
local exe = require("devcontainer.internal.executor")
local v = require("devcontainer.internal.validation")

local M = {}

---Runs docker command with passed arguments
---@param args string[]
---@param opts RunCommandOpts|nil
---@param onexit function(code, signal)
local function run_docker_compose(args, opts, onexit)
	exe.ensure_executable("docker-compose")

	exe.run_command(
		"docker-compose",
		vim.tbl_extend("force", opts or {}, {
			args = args,
		}),
		onexit
	)
end

---@class DockerComposeUpOpts
---@field on_success function() success callback
---@field on_fail function() failure callback

---Run docker-compose up with passed file
---@param compose_file string path to docker-compose.yml file
---@param opts DockerComposeUpOpts Additional options including callbacks
---@usage `require("devcontainer.docker-compose").up("docker-compose.yml")`
function M.up(compose_file, opts)
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
	run_docker_compose({ "-f", compose_file, "up", "-d" }, nil, function(code, _)
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
---@param compose_file string path to docker-compose.yml file
---@param opts DockerComposeDownOpts Additional options including callbacks
---@usage `require("devcontainer.docker-compose").down("docker-compose.yml")`
function M.down(compose_file, opts)
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
	run_docker_compose({ "-f", compose_file, "down" }, nil, function(code, _)
		if code == 0 then
			on_success()
		else
			on_fail()
		end
	end)
end

---@class DockerComposeRmOpts
---@field on_success function() success callback
---@field on_fail function() failure callback

---Run docker-compose rm with passed file
---@param compose_file string path to docker-compose.yml file
---@param opts DockerComposeRmOpts Additional options including callbacks
---@usage `require("devcontainer.docker-compose").rm("docker-compose.yml")`
function M.rm(compose_file, opts)
	opts = opts or {}
	v.validate_callbacks(opts)
	local on_success = opts.on_success
		or function()
			vim.notify("Successfully removed containers from " .. compose_file)
		end
	local on_fail = opts.on_fail
		or function()
			vim.notify("Removing containers from " .. compose_file .. " failed!", vim.log.levels.ERROR)
		end
	run_docker_compose({ "-f", compose_file, "rm", "-fsv" }, nil, function(code, _)
		if code == 0 then
			on_success()
		else
			on_fail()
		end
	end)
end

return M
