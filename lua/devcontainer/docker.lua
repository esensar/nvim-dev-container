---@mod devcontainer.docker Docker module
---@brief [[
---Provides functions related to docker control:
--- - building
--- - attaching
--- - running
---@brief ]]
local exe = require("devcontainer.internal.executor")
local config = require("devcontainer.config")
local v = require("devcontainer.internal.validation")

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

---Runs docker command with passed arguments
---@param image string base image tag
---@param path string docker build path / context
---@param opts DockerBuildOpts|nil
local function build_with_neovim(image, path, opts)
	opts = opts or {}
	local on_fail = opts.on_fail or function() end
	-- Install neovim in the image and then save it
	-- Dockerfile template inspired by https://github.com/MashMB/nvim-ide/blob/master/nvim/Dockerfile
	local temp_dockerfile = os.tmpname()
	local dockerfile = io.open(temp_dockerfile, "w")
	if not dockerfile then
		on_fail()
		return
	end
	local write_success = dockerfile:write(config.nvim_dockerfile_template(image))
	local close_success = dockerfile:close()
	if not write_success or not close_success then
		on_fail()
		return
	end

	-- Now build the new dockerfile
	M.build(temp_dockerfile, path, {
		on_fail = opts.on_fail,
		on_success = opts.on_success,
		tag = opts.tag,
		add_neovim = false,
	})
end

---@class DockerPullOpts
---@field on_success function() success callback
---@field on_fail function() failure callback

---Pull passed image using docker pull
---@param image string Docker image to pull
---@param opts DockerPullOpts Additional options including callbacks
---@usage `require("devcontainer.docker").pull("alpine", { on_success = function() end, on_fail = function() end})`
function M.pull(image, opts)
	vim.validate({
		image = { image, "string" },
		opts = { opts, { "table", "nil" } },
	})
	opts = opts or {}
	v.validate_callbacks(opts)

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
---@field add_neovim boolean|nil install neovim in the image (useful only for attaching to image)
---@field args table|nil list of additional arguments to build command
---@field on_success function(image_id) success callback taking the image_id of the built image
---@field on_fail function() failure callback

---Build image from passed dockerfile using docker build
---@param file string Path to Dockerfile to build
---@param path string|nil Path to the workspace, vim.lsp.buf.list_workspace_folders()[1] by default
---@param opts DockerBuildOpts Additional options including callbacks and tag
---@usage `docker.build("Dockerfile", { on_success = function(image_id) end, on_fail = function() end })`
function M.build(file, path, opts)
	vim.validate({
		file = { file, "string" },
		path = { path, { "string", "nil" } },
		opts = { opts, { "table", "nil" } },
	})
	path = path or vim.lsp.buf.list_workspace_folders()[1]
	opts = opts or {}
	v.validate_opts_with_callbacks(opts, {
		tag = "string",
		add_neovim = "boolean",
		args = function(x)
			return vim.tbl_islist(x)
		end,
	})

	local on_success = opts.on_success
		or function(image_id)
			local message = "Successfully built image from " .. file
			if image_id then
				message = message .. " - image_id: " .. image_id
			end
			if opts.tag then
				message = message .. " - tag: " .. opts.tag
			end
			vim.notify(message)
		end
	local on_fail = opts.on_fail
		or function()
			vim.notify("Building image from file " .. file .. " failed!", vim.log.levels.ERROR)
		end

	local command = { "build", "-f", file, path }
	local temptag = nil
	if opts.tag and not opts.add_neovim then
		table.insert(command, "-t")
		table.insert(command, opts.tag)
	elseif opts.add_neovim then
		temptag = "nvim-dev-container-base-" .. os.time()
		table.insert(command, "-t")
		table.insert(command, temptag)
	end

	vim.list_extend(command, opts.args or {})

	local image_id = nil
	run_docker(command, {
		stdout = vim.schedule_wrap(function(_, data)
			if data then
				local lines = vim.split(data, "\n")
				--TODO: Is there a better way to get image ID
				--There is the --iidfile maybe
				local image_id_regex = vim.regex("Successfully built .*")
				for _, line in ipairs(lines) do
					if image_id_regex:match_str(line) then
						local result_line = vim.split(line, " ")
						image_id = result_line[#result_line]
						return
					end
				end
			end
		end),
	}, function(code, _)
		if code == 0 then
			if not opts.add_neovim then
				on_success(image_id)
				return
			end
			build_with_neovim(temptag, path, opts)
		else
			on_fail()
		end
	end)
end

---@class DockerRunOpts
---@field autoremove boolean automatically remove container after stopping - true by default
---@field tty boolean attach to container TTY and display it in terminal buffer, using configured terminal handler
---@field command string|nil command to run in container
---@field args table|nil list of additional arguments to run command
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
	vim.validate({
		image = { image, "string" },
		opts = { opts, { "table", "nil" } },
	})
	opts = opts or {}
	v.validate_opts_with_callbacks(opts, {
		command = "string",
		autoremove = "boolean",
		tty = "boolean",
		terminal_handler = "function",
		args = function(x)
			return vim.tbl_islist(x)
		end,
	})

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

	vim.list_extend(command, opts.args or {})

	if opts.tty then
		(opts.terminal_handler or config.terminal_handler)(vim.list_extend({ "docker" }, command))
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
