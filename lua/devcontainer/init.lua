---@mod devcontainer Main devcontainer module - used to setup the plugin
---@brief [[
---Provides setup function
---@brief ]]
local M = {}

local config = require("devcontainer.config")
local commands = require("devcontainer.commands")
local log = require("devcontainer.internal.log")
local parse = require("devcontainer.config_file.parse")
local v = require("devcontainer.internal.validation")

local configured = false

---@class DevcontainerAutocommandOpts
---@field init boolean|nil set to true to enable automatic devcontainer start
---@field clean boolean|nil set to true to enable automatic devcontainer stop and clean
---@field update boolean|nil set to true to enable automatic devcontainer update when config file is changed

---@class DevcontainerSetupOpts
---@field config_search_start function|nil provides starting point for .devcontainer.json seach
---@field workspace_folder_provider function|nil provides current workspace folder
---@field terminal_handler function|nil handles terminal command requests, useful for floating terminals and similar
---@field nvim_dockerfile_template function|nil provides dockerfile template based on passed base_image - returns string
---@field devcontainer_json_template function|nil provides template for new .devcontainer.json files - returns table
---@field generate_commands boolean|nil can be set to false to prevent plugin from creating commands (true by default)
---@field autocommands DevcontainerAutocommandOpts|nil can be set to enable autocommands, disabled by default
---@field log_level log_level|nil can be used to override library logging level
---@field container_env table|nil can be used to override containerEnv for all started containers
---@field remote_env table|nil can be used to override remoteEnv when attaching to containers
---@field disable_recursive_config_search boolean|nil can be used to disable recursive .devcontainer search
---@field attach_mounts AttachMountsOpts|nil can be used to configure mounts when adding neovim to containers
---@field always_mount List[string]|nil list of mounts to add to every container

---Starts the plugin and sets it up with provided options
---@param opts DevcontainerSetupOpts|nil
function M.setup(opts)
	if configured then
		log.info("Already configured, skipping!")
		return
	end

	vim.validate({
		opts = { opts, "table" },
	})
	opts = opts or {}
	v.validate_opts(opts, {
		config_search_start = "function",
		workspace_folder_provider = "function",
		terminal_handler = "function",
		nvim_dockerfile_template = "function",
		devcontainer_json_template = "function",
		generate_commands = "boolean",
		autocommands = "table",
		log_level = "string",
		container_env = "table",
		remote_env = "table",
		disable_recursive_config_search = "boolean",
		attach_mounts = "table",
		always_mount = function(t)
			return t == nil or vim.tbl_islist(t)
		end,
	})
	if opts.autocommands then
		v.validate_deep(opts.autocommands, "opts.autocommands", {
			init = "boolean",
			clean = "boolean",
			update = "boolean",
		})
	end
	if opts.attach_mounts then
		local am = opts.attach_mounts
		v.validate_deep(am, "opts.attach_mounts", {
			always = "boolean",
			neovim_config = "table",
			neovim_data = "table",
			neovim_state = "table",
			custom_mounts = function(t)
				return t == nil or vim.tbl_islist(t)
			end,
		})

		local mount_opts_mapping = {
			enabled = "boolean",
			options = function(t)
				return t == nil or vim.tbl_islist(t)
			end,
		}

		if am.neovim_config then
			v.validate_deep(am.neovim_config, "opts.attach_mounts.neovim_config", mount_opts_mapping)
		end

		if am.neovim_data then
			v.validate_deep(am.neovim_data, "opts.attach_mounts.neovim_data", mount_opts_mapping)
		end

		if am.neovim_state then
			v.validate_deep(am.neovim_state, "opts.attach_mounts.neovim_state", mount_opts_mapping)
		end
	end

	configured = true

	config.terminal_hander = opts.terminal_handler or config.terminal_handler
	config.nvim_dockerfile_template = opts.nvim_dockerfile_template or config.nvim_dockerfile_template
	config.devcontainer_json_template = opts.devcontainer_json_template or config.devcontainer_json_template
	config.workspace_folder_provider = opts.workspace_folder_provider or config.workspace_folder_provider
	config.config_search_start = opts.config_search_start or config.config_search_start
	config.always_mount = opts.always_mount or config.always_mount
	config.attach_mounts = opts.attach_mounts or config.attach_mounts
	config.disable_recursive_config_search = opts.disable_recursive_config_search
		or config.disable_recursive_config_search
	if vim.env.NVIM_DEVCONTAINER_DEBUG then
		config.log_level = "trace"
	else
		config.log_level = opts.log_level or config.log_level
	end
	config.container_env = opts.container_env or config.container_env
	config.remote_env = opts.remote_env or config.remote_env

	if opts.generate_commands ~= false then
		-- Docker
		vim.api.nvim_create_user_command("DevcontainerBuild", function(_)
			commands.docker_build()
		end, {
			nargs = 0,
			desc = "Build image from .devcontainer.json",
		})
		vim.api.nvim_create_user_command("DevcontainerImageRun", function(_)
			commands.docker_image_run()
		end, {
			nargs = 0,
			desc = "Run image from .devcontainer.json",
		})
		vim.api.nvim_create_user_command("DevcontainerBuildAndRun", function(_)
			commands.docker_build_and_run()
		end, {
			nargs = 0,
			desc = "Build image from .devcontainer.json and then run it",
		})
		vim.api.nvim_create_user_command("DevcontainerBuildRunAttach", function(_)
			commands.docker_build_run_and_attach()
		end, {
			nargs = 0,
			desc = "Build image from .devcontainer.json and then run it and attach to neovim in it",
		})

		-- Compose
		vim.api.nvim_create_user_command("DevcontainerComposeUp", function(_)
			commands.compose_up()
		end, {
			nargs = 0,
			desc = "Run compose up based on .devcontainer.json",
		})
		vim.api.nvim_create_user_command("DevcontainerComposeDown", function(_)
			commands.compose_up()
		end, {
			nargs = 0,
			desc = "Run compose down based on .devcontainer.json",
		})
		vim.api.nvim_create_user_command("DevcontainerComposeRm", function(_)
			commands.compose_rm()
		end, {
			nargs = 0,
			desc = "Run compose rm based on .devcontainer.json",
		})

		-- Automatic
		vim.api.nvim_create_user_command("DevcontainerStartAuto", function(_)
			commands.start_auto()
		end, {
			nargs = 0,
			desc = "Start either compose, dockerfile or image from .devcontainer.json",
		})
		vim.api.nvim_create_user_command("DevcontainerStartAutoAndAttach", function(_)
			commands.start_auto(nil, true)
		end, {
			nargs = 0,
			desc = "Start and attach to either compose, dockerfile or image from .devcontainer.json",
		})
		vim.api.nvim_create_user_command("DevcontainerAttachAuto", function(_)
			commands.attach_auto()
		end, {
			nargs = 0,
			desc = "Attach to either compose, dockerfile or image from .devcontainer.json",
		})
		vim.api.nvim_create_user_command("DevcontainerStopAuto", function(_)
			commands.stop_auto()
		end, {
			nargs = 0,
			desc = "Stop either compose, dockerfile or image from .devcontainer.json",
		})

		-- Cleanup
		vim.api.nvim_create_user_command("DevcontainerStopAll", function(_)
			commands.stop_all()
		end, {
			nargs = 0,
			desc = "Stop everything started with devcontainer",
		})
		vim.api.nvim_create_user_command("DevcontainerRemoveAll", function(_)
			commands.remove_all()
		end, {
			nargs = 0,
			desc = "Remove everything started with devcontainer",
		})

		-- Util
		vim.api.nvim_create_user_command("DevcontainerLogs", function(_)
			commands.open_logs()
		end, {
			nargs = 0,
			desc = "Open devcontainer plugin logs in a new buffer",
		})
		vim.api.nvim_create_user_command("DevcontainerOpenNearestConfig", function(_)
			commands.open_nearest_devcontainer_config()
		end, {
			nargs = 0,
			desc = "Open nearest devcontainer.json file in a new buffer",
		})
		vim.api.nvim_create_user_command("DevcontainerEditNearestConfig", function(_)
			commands.edit_devcontainer_config()
		end, {
			nargs = 0,
			desc = "Opens nearest devcontainer.json file in a new buffer or creates one if it does not exist",
		})
	end

	if opts.autocommands then
		local au_id = vim.api.nvim_create_augroup("devcontainer_autostart", {})

		if opts.autocommands.init then
			local last_devcontainer_file = nil

			local function auto_start()
				parse.find_nearest_devcontainer_config(function(err, data)
					if err == nil and data ~= nil then
						if data ~= last_devcontainer_file then
							commands.start_auto()
							last_devcontainer_file = data
						end
					end
				end)
			end

			vim.api.nvim_create_autocmd("BufEnter", {
				pattern = "*",
				group = au_id,
				callback = function()
					auto_start()
				end,
				once = true,
			})

			vim.api.nvim_create_autocmd("DirChanged", {
				pattern = "*",
				group = au_id,
				callback = function()
					auto_start()
				end,
			})
		end

		if opts.autocommands.clean then
			vim.api.nvim_create_autocmd("VimLeavePre", {
				pattern = "*",
				group = au_id,
				callback = function()
					commands.remove_all()
				end,
			})
		end

		if opts.autocommands.update then
			vim.api.nvim_create_autocmd({ "BufWritePost", "FileWritePost" }, {
				pattern = "*devcontainer.json",
				group = au_id,
				callback = function(event)
					parse.find_nearest_devcontainer_config(function(err, data)
						if err == nil and data ~= nil then
							if data == event.match then
								commands.stop_auto(function()
									commands.start_auto()
								end)
							end
						end
					end)
				end,
			})
		end
	end

	log.info("Setup complete!")
end

return M
