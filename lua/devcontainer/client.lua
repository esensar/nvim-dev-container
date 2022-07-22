---@mod devcontainer.client Container module
---@brief [[
---Provides functions related to docker control:
--- - building
--- - attaching
--- - running
---@brief ]]
local exe = require("devcontainer.internal.executor")
local config = require("devcontainer.config")
local status = require("devcontainer.status")
local v = require("devcontainer.internal.validation")
local log = require("devcontainer.internal.log")

local M = {}

---Runs docker command with passed arguments
---@param args string[]
---@param opts RunCommandOpts|nil
---@param onexit function(code, signal)
local function run_docker(args, opts, onexit)
	exe.ensure_executable("docker")

	opts = opts or {}
	exe.run_command(
		"docker",
		vim.tbl_extend("force", opts, {
			args = args,
			stderr = vim.schedule_wrap(function(err, data)
				if data then
					log.fmt_error("Container command (%s): %s", args, data)
				end
				if opts.stderr then
					opts.stderr(err, data)
				end
			end),
		}),
		onexit
	)
end

---Runs docker command with passed arguments
---@param image string base image tag
---@param path string docker build path / context
---@param opts ContainerBuildOpts|nil
local function build_with_neovim(original_dockerfile, image, path, opts)
	opts = opts or {}
	local on_fail = opts.on_fail or function() end
	-- Install neovim in the image and then save it
	-- Containerfile template inspired by https://github.com/MashMB/nvim-ide/blob/master/nvim/Dockerfile
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
		_neovim_build = true,
		_original_dockerfile = original_dockerfile,
	})
end

---@class ContainerPullOpts
---@field on_success function() success callback
---@field on_fail function() failure callback

---Pull passed image using docker pull
---@param image string Container image to pull
---@param opts ContainerPullOpts Additional options including callbacks
---@usage `require("devcontainer.client").pull("alpine", { on_success = function() end, on_fail = function() end})`
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

---@class ContainerBuildOpts
---@field tag string|nil tag for the image built
---@field add_neovim boolean|nil install neovim in the image (useful only for attaching to image)
---@field args table|nil list of additional arguments to build command
---@field on_success function(image_id) success callback taking the image_id of the built image
---@field on_progress function(DevcontainerBuildStatus) callback taking build status object
---@field on_fail function() failure callback

---Build image from passed dockerfile using docker build
---@param file string Path to Containerfile to build
---@param path string|nil Path to the workspace, vim.lsp.buf.list_workspace_folders()[1] by default
---@param opts ContainerBuildOpts Additional options including callbacks and tag
---@usage `docker.build("Containerfile", { on_success = function(image_id) end, on_fail = function() end })`
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
			return x == nil or vim.tbl_islist(x)
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
	local on_progress = function(build_status)
		vim.api.nvim_exec_autocmds("User", { pattern = "DevcontainerBuildProgress", modeline = false })
		if opts.on_progress then
			opts.on_progress(build_status)
		end
	end

	local command = { "build", "-f", file, path }
	local temptag = nil
	if opts.tag and not opts.add_neovim then
		table.insert(command, "-t")
		table.insert(command, opts.tag)
	elseif opts.add_neovim then
		temptag = "nvim-dev-container-base-" .. os.time()
		log.fmt_debug("Creating temporary image with tag: %s", temptag)
		table.insert(command, "-t")
		table.insert(command, temptag)
	end

	vim.list_extend(command, opts.args or {})

	local build_status = {
		progress = 0,
		step_count = 0,
		current_step = 0,
		image_id = nil,
		source_dockerfile = file,
		build_command = table.concat(vim.list_extend({ "docker" }, command), " "),
		commands_run = {},
		running = true,
	}
	status.add_build(build_status)

	local image_id = nil
	run_docker(command, {
		stdout = vim.schedule_wrap(function(_, data)
			if data then
				local lines = vim.split(data, "\n")
				--TODO: Is there a better way to get image ID
				--There is the --iidfile maybe
				local image_id_regex = vim.regex("Successfully built .*")
				local step_regex = vim.regex("Step [[:digit:]]*/[[:digit:]]* : .*")
				for _, line in ipairs(lines) do
					if not image_id and image_id_regex:match_str(line) then
						local result_line = vim.split(line, " ")
						image_id = result_line[#result_line]
					end
					if step_regex:match_str(line) then
						local step_line = vim.split(line, ":")
						local step_numbers = vim.split(vim.split(step_line[1], " ")[2], "/")
						table.insert(build_status.commands_run, string.sub(step_line[2], 2))
						build_status.current_step = tonumber(step_numbers[1])
						build_status.step_count = tonumber(step_numbers[2])
						build_status.progress = math.floor((build_status.current_step / build_status.step_count) * 100)
						on_progress(vim.deepcopy(build_status))
					end
				end
			end
		end),
	}, function(code, _)
		build_status.running = false
		on_progress(vim.deepcopy(build_status))
		if code == 0 then
			if not opts.add_neovim then
				if opts["_neovim_build"] then
					status.add_image({
						image_id = image_id,
						source_dockerfile = opts["_original_dockerfile"],
						neovim_added = true,
						tmp_dockerfile = file,
					})
				else
					status.add_image({
						image_id = image_id,
						source_dockerfile = file,
						neovim_added = false,
					})
				end
				on_success(image_id)
				return
			end
			build_with_neovim(file, temptag, path, opts)
		else
			on_fail()
		end
	end)
end

---@class ContainerRunOpts
---@field autoremove boolean automatically remove container after stopping - true by default
---@field command string|table|nil command to run in container
---@field args table|nil list of additional arguments to run command
---@field on_success function(container_id) success callback taking the id of the started container - not invoked if tty
---@field on_fail function() failure callback

---Run passed image using docker run
---NOTE: If terminal_handler is passed, then it needs to start the process too - default termopen does just that
---@param image string Container image to run
---@param opts ContainerRunOpts Additional options including callbacks
---@usage `docker.run("alpine", { on_success = function(id) end, on_fail = function() end })`
function M.run(image, opts)
	vim.validate({
		image = { image, "string" },
		opts = { opts, { "table", "nil" } },
	})
	opts = opts or {}
	v.validate_opts_with_callbacks(opts, {
		command = { "string", "table" },
		autoremove = "boolean",
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

	local command = { "run", "-i", "-d" }
	if opts.autoremove ~= false then
		table.insert(command, "--rm")
	end

	vim.list_extend(command, opts.args or {})

	table.insert(command, image)
	if opts.command then
		if type(opts.command) == "string" then
			table.insert(command, opts.command)
		elseif type(opts.command) == "table" then
			vim.list_extend(command, opts.command)
		end
	end

	local container_id = nil
	run_docker(command, {
		stdout = function(_, data)
			if data then
				container_id = vim.split(data, "\n")[1]
			end
		end,
	}, function(code, _)
		if code == 0 then
			status.add_container({
				image_id = image,
				container_id = container_id,
				autoremove = opts.autoremove,
			})
			on_success(container_id)
		else
			on_fail()
		end
	end)
end

---@class ContainerExecOpts
---@field tty boolean attach to container TTY and display it in terminal buffer, using configured terminal handler
---@field terminal_handler function(command) override to open terminal in a different way, :tabnew + termopen by default
---@field capture_output boolean if true captures output and passes it to success callback - incompatible with tty
---@field command string|table|nil command to run in container
---@field args table|nil list of additional arguments to exec command
---@field on_success function() success callback - not called if tty
---@field on_fail function() failure callback - not called if tty

---Run command on a container using docker exec
---Useful for attaching to neovim
---NOTE: If terminal_handler is passed, then it needs to start the process too - default termopen does just that
---@param container_id string Container container to exec on
---@param opts ContainerExecOpts Additional options including callbacks
---@usage `docker.exec("some_id", { command = "nvim", on_success = function() end, on_fail = function() end })`
function M.exec(container_id, opts)
	vim.validate({
		container_id = { container_id, "string" },
		opts = { opts, { "table", "nil" } },
	})
	opts = opts or {}
	v.validate_opts_with_callbacks(opts, {
		command = { "string", "table" },
		tty = "boolean",
		capture_output = "boolean",
		terminal_handler = "function",
		args = function(x)
			return x == nil or vim.tbl_islist(x)
		end,
	})

	local on_success = opts.on_success
		or function()
			vim.notify("Successfully executed command " .. opts.command .. "on container " .. container_id)
		end
	local on_fail = opts.on_fail
		or function()
			vim.notify(
				"Executing command " .. opts.command .. " on container " .. container_id .. " failed!",
				vim.log.levels.ERROR
			)
		end

	local command = { "exec", "-i" }
	if opts.tty then
		table.insert(command, "-t")
	end

	vim.list_extend(command, opts.args or {})

	table.insert(command, container_id)
	if opts.command then
		if type(opts.command) == "string" then
			table.insert(command, opts.command)
		elseif type(opts.command) == "table" then
			vim.list_extend(command, opts.command)
		end
	end

	if opts.tty then
		(opts.terminal_handler or config.terminal_handler)(vim.list_extend({ "docker" }, command))
	else
		local run_opts = nil
		local captured = nil
		if opts.capture_output then
			run_opts = {
				stdout = function(_, data)
					if data then
						captured = data
					end
				end,
			}
		end
		run_docker(command, run_opts, function(code, _)
			if code == 0 then
				if opts.capture_output then
					on_success(captured)
				else
					on_success()
				end
			else
				on_fail()
			end
		end)
	end
end

---@class ContainerContainerStopOpts
---@field on_success function() success callback
---@field on_fail function() failure callback

---Stop passed containers
---@param containers List[string] ids of containers to stop
---@param opts ContainerContainerStopOpts Additional options including callbacks
---@usage `docker.container_stop({ "some_id" }, { on_success = function() end, on_fail = function() end })`
function M.container_stop(containers, opts)
	vim.validate({
		containers = { containers, "table" },
	})
	opts = opts or {}
	v.validate_callbacks(opts)

	local on_success = opts.on_success or function()
		vim.notify("Successfully stopped containers!")
	end
	local on_fail = opts.on_fail or function()
		vim.notify("Stopping containers failed!", vim.log.levels.ERROR)
	end

	local command = { "container", "stop" }

	vim.list_extend(command, containers)
	run_docker(command, nil, function(code, _)
		if code == 0 then
			for _, container in ipairs(containers) do
				status.move_container_to_stopped(container)
			end
			on_success()
		else
			on_fail()
		end
	end)
end

---@class ContainerImageRmOpts
---@field force boolean|nil force deletion
---@field on_success function() success callback
---@field on_fail function() failure callback

---Removes passed images
---@param images List[string] ids of images to remove
---@param opts ContainerImageRmOpts Additional options including callbacks
---@usage `docker.image_rm({ "some_id" }, { on_success = function() end, on_fail = function() end })`
function M.image_rm(images, opts)
	vim.validate({
		images = { images, "table" },
	})
	opts = opts or {}
	v.validate_callbacks(opts)

	local on_success = opts.on_success or function()
		vim.notify("Successfully removed images!")
	end
	local on_fail = opts.on_fail or function()
		vim.notify("Removing images failed!", vim.log.levels.ERROR)
	end

	local command = { "image", "rm" }

	if opts.force then
		table.insert(command, "-f")
	end

	vim.list_extend(command, images)
	run_docker(command, nil, function(code, _)
		if code == 0 then
			for _, image in ipairs(images) do
				status.remove_image(image)
			end
			on_success()
		else
			on_fail()
		end
	end)
end

---@class ContainerContainerRmOpts
---@field force boolean|nil force deletion
---@field on_success function() success callback
---@field on_fail function() failure callback

---Removes passed containers
---@param containers List[string] ids of containers to remove
---@param opts ContainerContainerRmOpts Additional options including callbacks
---@usage `docker.container_rm({ "some_id" }, { on_success = function() end, on_fail = function() end })`
function M.container_rm(containers, opts)
	vim.validate({
		containers = { containers, "table" },
	})
	opts = opts or {}
	v.validate_callbacks(opts)

	local on_success = opts.on_success or function()
		vim.notify("Successfully removed containers!")
	end
	local on_fail = opts.on_fail or function()
		vim.notify("Removing containers failed!", vim.log.levels.ERROR)
	end

	local command = { "container", "rm" }

	if opts.force then
		table.insert(command, "-f")
	end

	vim.list_extend(command, containers)
	run_docker(command, nil, function(code, _)
		if code == 0 then
			for _, container in ipairs(containers) do
				status.remove_container(container)
			end
			on_success()
		else
			on_fail()
		end
	end)
end

log.wrap(M)
return M
