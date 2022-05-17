---@mod devcontainer Main devcontainer module - used to setup the plugin
---@brief [[
---Provides setup function
---@brief ]]
local M = {}

local config = require("devcontainer.config")
local commands = require("devcontainer.commands")

local configured = false

---@class DevcontainerSetupOpts
---@field config_search_start function|nil provides starting point for .devcontainer.json seach
---@field workspace_folder_provider function|nil provides current workspace folder
---@field terminal_handler function|nil handles terminal command requests, useful for floating terminals and similar
---@field nvim_dockerfile_template function|nil provides dockerfile template based on passed base_image
---@field generate_commands boolean|nil can be set to false to prevent plugin from creating commands

---Starts the plugin and sets it up with provided options
---@param opts DevcontainerSetupOpts|nil
function M.setup(opts)
	if configured then
		return
	end
	configured = true

	config.terminal_hander = opts.terminal_handler or config.terminal_handler
	config.nvim_dockerfile_template = opts.nvim_dockerfile_template or config.nvim_dockerfile_template
	config.workspace_folder_provider = opts.workspace_folder_provider or config.workspace_folder_provider
	config.config_search_start = opts.config_search_start or config.config_search_start

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
			desc = "Run docker-compose up based on .devcontainer.json",
		})
		vim.api.nvim_create_user_command("DevcontainerComposeDown", function(_)
			commands.compose_up()
		end, {
			nargs = 0,
			desc = "Run docker-compose down based on .devcontainer.json",
		})
		vim.api.nvim_create_user_command("DevcontainerComposeRm", function(_)
			commands.compose_rm()
		end, {
			nargs = 0,
			desc = "Run docker-compose rm based on .devcontainer.json",
		})

		-- Automatic
		vim.api.nvim_create_user_command("DevcontainerStartAuto", function(_)
			commands.start_auto()
		end, {
			nargs = 0,
			desc = "Start either compose, dockerfile or image from .devcontainer.json",
		})
	end
end

return M
