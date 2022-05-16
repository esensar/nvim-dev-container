---@mod devcontainer.docker Docker module
---@brief [[
---Provides functions related to docker control:
--- - building
--- - attaching
--- - running
---@brief ]]
local exe = require("devcontainer.internal.executor")

local M = {}

---Runs docker command with passed arguments
---@param args string[]
---@param opts RunCommandOpts|nil
---@param onexit function(code, signal)
local function run_docker(args, opts, onexit)
	exe.ensure_executable("docker")

	exe.run_command(
		"docker",
		vim.tbl_extend("force", opts or {}, {
			args = args,
		}),
		onexit
	)
end

---@class DockerPullOpts
---@field on_success function() success callback
---@field on_fail function() failure callback

---Pull passed image using docker pull
---@param image string Docker image to pull
---@param opts DockerPullOpts Additional options including callbacks
---@usage `require("devcontainer.docker").pull("alpine", { on_success = function() end, on_fail = function() end})`
function M.pull(image, opts)
	opts = opts or {}
	local on_success = opts.on_success or function()
		vim.notify("Successfully pulled image " .. image)
	end
	local on_fail = opts.on_fail
		or function()
			vim.notify("Pulling image " .. image .. " failed!", vim.log.levels.ERROR)
		end
	run_docker({ "pull", image }, nil, function(code, _)
		if code == 0 then
			on_success()
		else
			on_fail()
		end
	end)
end

---@class DockerBuildOpts
---@field tag string|nil tag for the image built
---@field on_success function(image_id) success callback taking the image_id of the built image
---@field on_fail function() failure callback

---Build image from passed dockerfile using docker build
---@param file string Path to Dockerfile to build
---@param path string|nil Path to the workspace, vim.lsp.buf.list_workspace_folders()[1] by default
---@param opts DockerBuildOpts Additional options including callbacks and tag
---@usage `docker.build("Dockerfile", { on_success = function(image_id) end, on_fail = function() end })`
function M.build(file, path, opts)
	path = path or vim.lsp.buf.list_workspace_folders()[1]
	opts = opts or {}
	local on_success = opts.on_success
		or function(tag)
			vim.notify("Successfully built image from " .. file .. " - tag: " .. tag)
		end
	local on_fail = opts.on_fail
		or function()
			vim.notify("Building image from file " .. file .. " failed!", vim.log.levels.ERROR)
		end
	local command = { "build", "-f", file, path }
	if opts.tag then
		table.insert(command, "-t")
		table.insert(command, opts.tag)
	end
	local image_id = nil
	run_docker(command, {
		stdout = function(_, data)
			if data then
				local lines = vim.split(data, "\n")
				local result_line = vim.split(lines[#lines], " ")
				image_id = result_line[#result_line]
			end
		end,
	}, function(code, _)
		if code == 0 then
			on_success(image_id)
		else
			on_fail()
		end
	end)
end

local function default_terminal_handler(command)
	local laststatus = vim.o.laststatus
	vim.cmd("tabnew")
	local bufnr = vim.api.nvim_get_current_buf()
	vim.o.laststatus = 0
	local au_id = vim.api.nvim_create_augroup("devcontainer.docker.terminal", {})
	vim.api.nvim_create_autocmd("BufEnter", {
		buffer = bufnr,
		group = au_id,
		callback = function()
			vim.o.laststatus = 0
		end,
	})
	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = bufnr,
		group = au_id,
		callback = function()
			vim.o.laststatus = laststatus
		end,
	})
	vim.api.nvim_create_autocmd("BufDelete", {
		buffer = bufnr,
		group = au_id,
		callback = function()
			vim.o.laststatus = laststatus
			vim.api.nvim_del_augroup_by_id(au_id)
		end,
	})
	vim.fn.termopen(command)
end

---@class DockerRunOpts
---@field autoremove boolean automatically remove container after stopping - true by default
---@field tty boolean attach to container TTY and display it in terminal buffer, using configured terminal handler
---@field command string|nil command to run in container
---@field terminal_handler function(command) override to open terminal in a different way, :tabnew + termopen by default
---@field on_success function(container_id) success callback taking the id of the started container - not invoked if tty
---@field on_fail function() failure callback
---@see TODO: terminal handler config

---Run passed image using docker run
---NOTE: If terminal_handler is passed, then it needs to start the process too - default termopen does just that
---@param image string Docker image to run
---@param opts DockerRunOpts Additional options including callbacks
---@usage `docker.run("alpine", { on_success = function(id) end, on_fail = function() end })`
function M.run(image, opts)
	opts = opts or {}
	local on_success = opts.on_success or function()
		vim.notify("Successfully started image " .. image)
	end
	local on_fail = opts.on_fail
		or function()
			vim.notify("Starting image " .. image .. " failed!", vim.log.levels.ERROR)
		end
	local command = { "run", "-i" }
	if opts.tty then
		table.insert(command, "-t")
	else
		table.insert(command, "-d")
	end
	if opts.autoremove ~= false then
		table.insert(command, "--rm")
	end
	table.insert(command, image)
	if opts.command then
		table.insert(command, opts.command)
	end
	if opts.tty then
		(opts.terminal_handler or default_terminal_handler)(vim.list_extend({ "docker" }, command))
	else
		local container_id = nil
		run_docker(command, {
			stdout = function(_, data)
				if data then
					container_id = data
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
end

return M
