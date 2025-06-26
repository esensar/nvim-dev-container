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
local executor = require("devcontainer.internal.executor")
local runtime = require("devcontainer.internal.runtimes")
local cmdline = require("devcontainer.internal.cmdline")

local configured = false

---@class DevcontainerAutocommandOpts
---@field init? boolean|string set to true (or "ask" to prompt before stating) to enable automatic devcontainer start
---@field clean? boolean set to true to enable automatic devcontainer stop and clean
---@field update? boolean set to true to enable automatic devcontainer update when config file is changed

---@class DevcontainerSetupOpts
---@field config_search_start? function provides starting point for .devcontainer.json search
---@field workspace_folder_provider? function provides current workspace folder
---@field terminal_handler? function handles terminal command requests, useful for floating terminals and similar
---@field devcontainer_json_template? function provides template for new .devcontainer.json files - returns table
---@field nvim_installation_commands_provider? function provides table of commands for installing neovim in container
---@field generate_commands? boolean can be set to false to prevent plugin from creating commands (true by default)
---@field autocommands? DevcontainerAutocommandOpts can be set to enable autocommands, disabled by default
---@field log_level? LogLevel can be used to override library logging level
---@field container_env? table can be used to override containerEnv for all started containers
---@field remote_env? table can be used to override remoteEnv when attaching to containers
---@field disable_recursive_config_search? boolean can be used to disable recursive .devcontainer search
---@field cache_images? boolean can be used to cache images after adding neovim - true by default
---@field attach_mounts? AttachMountsOpts can be used to configure mounts when adding neovim to containers
---@field always_mount? table[table|string] list of mounts to add to every container
---@field container_runtime? string container runtime to use ("docker", "podman", "devcontainer-cli")
---@field backup_runtime? string container runtime to use when main does not support an action ("docker", "podman")
---@field compose_command? string command to use for compose
---@field backup_compose_command? string command to use for compose when main does not support an action

---Starts the plugin and sets it up with provided options
---@param opts? DevcontainerSetupOpts
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
    devcontainer_json_template = "function",
    nvim_installation_commands_provider = "function",
    generate_commands = "boolean",
    autocommands = "table",
    log_level = "string",
    container_env = "table",
    remote_env = "table",
    disable_recursive_config_search = "boolean",
    cache_images = "boolean",
    attach_mounts = "table",
    always_mount = function(t)
      return t == nil or vim.islist(t)
    end,
  })
  if opts.autocommands then
    v.validate_deep(opts.autocommands, "opts.autocommands", {
      init = { "boolean", "string" },
      clean = "boolean",
      update = "boolean",
    })
  end
  local am = opts.attach_mounts
  if am then
    v.validate_deep(am, "opts.attach_mounts", {
      neovim_config = "table",
      neovim_data = "table",
      neovim_state = "table",
    })

    local mount_opts_mapping = {
      enabled = "boolean",
      options = function(t)
        return t == nil or vim.islist(t)
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

  config.terminal_handler = opts.terminal_handler or config.terminal_handler
  config.devcontainer_json_template = opts.devcontainer_json_template or config.devcontainer_json_template
  config.nvim_installation_commands_provider = opts.nvim_installation_commands_provider
    or config.nvim_installation_commands_provider
  config.workspace_folder_provider = opts.workspace_folder_provider or config.workspace_folder_provider
  config.config_search_start = opts.config_search_start or config.config_search_start
  config.always_mount = opts.always_mount or config.always_mount
  config.attach_mounts = opts.attach_mounts or config.attach_mounts
  config.disable_recursive_config_search = opts.disable_recursive_config_search
    or config.disable_recursive_config_search
  if opts.cache_images ~= nil then
    config.cache_images = opts.cache_images
  end
  if vim.env.NVIM_DEVCONTAINER_DEBUG then
    config.log_level = "trace"
  else
    config.log_level = opts.log_level or config.log_level
  end
  config.container_env = opts.container_env or config.container_env
  config.remote_env = opts.remote_env or config.remote_env
  config.container_runtime = opts.container_runtime or config.container_runtime
  config.backup_runtime = opts.backup_runtime or config.backup_runtime
  config.compose_command = opts.compose_command or config.compose_command
  config.backup_compose_command = opts.backup_compose_command or config.backup_compose_command

  if config.compose_command == nil then
    if executor.is_executable("podman-compose") then
      config.compose_command = "podman-compose"
    elseif executor.is_executable("docker-compose") then
      config.compose_command = "docker-compose"
    elseif executor.is_executable("docker compose") then
      config.compose_command = "docker compose"
    end
  end

  if config.backup_compose_command == nil then
    if executor.is_executable("podman-compose") then
      config.backup_compose_command = "podman-compose"
    elseif executor.is_executable("docker-compose") then
      config.backup_compose_command = "docker-compose"
    elseif executor.is_executable("docker compose") then
      config.backup_compose_command = "docker compose"
    end
  end

  if config.container_runtime == nil then
    if executor.is_executable("podman") then
      config.container_runtime = "podman"
    elseif executor.is_executable("docker") then
      config.container_runtime = "docker"
    end
  end

  if config.backup_runtime == nil then
    if executor.is_executable("podman") then
      config.backup_runtime = "podman"
    elseif executor.is_executable("docker") then
      config.backup_runtime = "docker"
    end
  end

  if opts.generate_commands ~= false then
    local container_command_complete = cmdline.complete_parse(function(cmdline_status)
      local command_suggestions = { "nvim", "sh" }
      -- Filling second arg
      if cmdline_status.current_arg == 2 then
        return command_suggestions
      elseif cmdline_status.current_arg == 1 then
        local options = { "devcontainer", "latest" }
        local containers = runtime.container.container_ls({ async = false })
        vim.list_extend(options, containers)

        if cmdline_status.arg_count == 1 then
          vim.list_extend(options, command_suggestions)
        end
        return options
      end
      return {}
    end)

    -- Automatic
    vim.api.nvim_create_user_command("DevcontainerStart", function(_)
      commands.start_auto()
    end, {
      nargs = 0,
      desc = "Start either compose, dockerfile or image from .devcontainer.json",
    })
    vim.api.nvim_create_user_command("DevcontainerAttach", function(args)
      local target = "devcontainer"
      local command = "nvim"
      if #args.fargs == 1 then
        command = args.fargs[1]
      elseif #args.fargs > 1 then
        target = args.fargs[1]
        command = args.fargs
        table.remove(command, 1)
      end
      commands.attach_auto(target, command)
    end, {
      nargs = "*",
      desc = "Attach to either compose, dockerfile or image from .devcontainer.json",
      complete = container_command_complete,
    })
    vim.api.nvim_create_user_command("DevcontainerExec", function(args)
      local target = "devcontainer"
      local command = "nvim"
      if #args.fargs == 1 then
        command = args.fargs[1]
      elseif #args.fargs > 1 then
        target = args.fargs[1]
        command = args.fargs
        table.remove(command, 1)
      end
      commands.exec(target, command)
    end, {
      nargs = "*",
      desc = "Execute a command on running container",
      complete = container_command_complete,
    })
    vim.api.nvim_create_user_command("DevcontainerStop", function(_)
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
        parse.find_nearest_devcontainer_config(vim.schedule_wrap(function(err, data)
          if err == nil and data ~= nil then
            if vim.loop.fs_realpath(data) ~= last_devcontainer_file then
              if opts.autocommands.init == "ask" then
                vim.ui.select(
                  { "Yes", "No" },
                  { prompt = "Devcontainer file found! Would you like to start the container?" },
                  function(choice)
                    if choice == "Yes" then
                      commands.start_auto()
                      last_devcontainer_file = vim.loop.fs_realpath(data)
                    end
                  end
                )
              else
                commands.start_auto()
                last_devcontainer_file = vim.loop.fs_realpath(data)
              end
            end
          end
        end))
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
