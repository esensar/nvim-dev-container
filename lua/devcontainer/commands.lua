---@mod devcontainer.commands High level devcontainer commands
---@brief [[
---Provides functions representing high level devcontainer commands
---@brief ]]
local compose_runtime = require("devcontainer.compose")
local container_runtime = require("devcontainer.container")
local nvim = require("devcontainer.internal.nvim")
local container_utils = require("devcontainer.container_utils")
local config_file = require("devcontainer.config_file.parse")
local log = require("devcontainer.internal.log")
local status = require("devcontainer.status")
local plugin_config = require("devcontainer.config")
local u = require("devcontainer.internal.utils")
local executor = require("devcontainer.internal.executor")

local M = {}

local sockets_dir = vim.fn.tempname()
vim.fn.mkdir(sockets_dir)

local function get_nearest_devcontainer_config(callback)
  config_file.parse_nearest_devcontainer_config(vim.schedule_wrap(function(err, data)
    if err then
      vim.notify("Parsing devcontainer config failed: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end

    callback(config_file.fill_defaults(data))
  end))
end

local function generate_build_command_args(data)
  local build_args = nil
  if data.build.args then
    build_args = build_args or {}
    for k, v in pairs(data.build.args) do
      table.insert(build_args, "--build-arg")
      table.insert(build_args, k .. "=" .. v)
    end
  end
  if data.build.target then
    build_args = build_args or {}
    table.insert(build_args, "--target")
    table.insert(build_args, data.build.target)
  end
  if data.build.cacheFrom then
    build_args = build_args or {}
    if type(data.build.cacheFrom) == "string" then
      table.insert(build_args, "--cache-from")
      table.insert(build_args, data.build.cacheFrom)
    elseif type(data.build.cacheFrom) == "table" then
      for _, v in ipairs(data.build.cacheFrom) do
        table.insert(build_args, "--cache-from")
        table.insert(build_args, v)
      end
    end
  end
  return build_args
end

local function generate_common_run_command_args(data)
  local run_args = nil
  if data.forwardPorts then
    run_args = run_args or {}
    for _, v in ipairs(data.forwardPorts) do
      table.insert(run_args, "--publish")
      table.insert(run_args, v)
    end
  end
  return run_args
end

local function mount_to_string(mount)
  if type(mount) == "table" then
    local items = {}
    for k, v in pairs(mount) do
      table.insert(items, k .. "=" .. v)
    end
    return vim.fn.join(items, ",")
  else
    return mount
  end
end

local function generate_run_command_args(data, image, continuation)
  local function fill_args_from_config_and_run()
    local run_args = generate_common_run_command_args(data)
    if data.containerUser then
      run_args = run_args or {}
      table.insert(run_args, "--user")
      table.insert(run_args, data.containerUser)
    end

    local env_vars = nil
    if data.containerEnv then
      env_vars = env_vars or {}
      env_vars = vim.tbl_extend("force", env_vars, data.containerEnv)
    end
    if plugin_config.container_env then
      env_vars = env_vars or {}
      env_vars = vim.tbl_extend("force", env_vars, plugin_config.container_env)
    end
    if env_vars then
      run_args = run_args or {}
      for k, v in pairs(env_vars) do
        table.insert(run_args, "--env")
        table.insert(run_args, k .. "=" .. v)
      end
    end
    if data.workspaceFolder and data.workspaceMount then
      -- if data.workspaceMount == nil or data.workspaceFolder == nil then
      -- 	vim.notify("workspaceFolder and workspaceMount have to both be defined to be used!", vim.log.levels.WARN)
      -- else
      run_args = run_args or {}
      table.insert(run_args, "--mount")
      table.insert(run_args, mount_to_string(data.workspaceMount))
      -- end
    else
      run_args = run_args or {}
      table.insert(run_args, "--mount")
      table.insert(run_args, "source=" .. plugin_config.workspace_folder_provider() .. ",target=/workspace,type=bind")
    end
    if data.mounts then
      run_args = run_args or {}
      for _, v in ipairs(data.mounts) do
        table.insert(run_args, "--mount")
        table.insert(run_args, mount_to_string(v))
      end
    end
    if plugin_config.always_mount then
      run_args = run_args or {}
      for _, v in ipairs(plugin_config.always_mount) do
        table.insert(run_args, "--mount")
        table.insert(run_args, mount_to_string(v))
      end
    end

    -- mount dir for neovim attaching
    table.insert(run_args, "--mount")
    table.insert(run_args, "source=" .. sockets_dir .. ",target=/tmp/nvim-dev-container,type=bind")

    if plugin_config.attach_mounts then
      run_args = run_args or {}
      local am = plugin_config.attach_mounts

      local function build_mount(stdpath_location, options, target)
        local bind_opts = nil
        if options and #options > 0 then
          bind_opts = table.concat(options, ",")
        end
        local mount = {
          "type=bind",
          "source=" .. vim.fn.stdpath(stdpath_location),
          "target=" .. target,
        }
        if bind_opts then
          table.insert(mount, bind_opts)
        end
        return table.concat(mount, ",")
      end

      local home_path
      if data.remoteUser then
        home_path = "/home/" .. data.remoteUser .. "/"
      elseif data.containerUser then
        home_path = "/home/" .. data.containerUser .. "/"
      else
        home_path = "/root/"
      end
      if am.neovim_config and am.neovim_config.enabled then
        table.insert(run_args, "--mount")
        table.insert(run_args, build_mount("config", am.neovim_config.options, home_path .. ".config/nvim"))
      end
      if am.neovim_data and am.neovim_data.enabled then
        table.insert(run_args, "--mount")
        table.insert(run_args, build_mount("data", am.neovim_data.options, home_path .. ".local/share/nvim"))
      end
      if am.neovim_state and am.neovim_state.enabled then
        table.insert(run_args, "--mount")
        table.insert(run_args, build_mount("state", am.neovim_state.options, home_path .. ".local/state/nvim"))
      end
    end
    if data.runArgs then
      run_args = run_args or {}
      vim.list_extend(run_args, data.runArgs)
    end
    if data.appPort then
      run_args = run_args or {}
      if type(data.appPort) == "table" then
        for _, v in ipairs(data.appPort) do
          table.insert(run_args, "--publish")
          table.insert(run_args, v)
        end
      else
        table.insert(run_args, "--publish")
        table.insert(run_args, data.appPort)
      end
    end
    if data.overrideCommand then
      table.insert(run_args, "--entrypoint")
      table.insert(run_args, "")
    end
    continuation(run_args)
  end
  if config_file.container_workspace_folder_needs_fill(data) then
    if data.workspaceFolder or data.workspaceMount then
      data = config_file.fill_container_workspace_folder(data, data.workspaceFolder)
      fill_args_from_config_and_run()
    else
      container_utils.get_image_workspace(image, {
        on_success = function(container_workspace_folder)
          data = config_file.fill_container_workspace_folder(data, container_workspace_folder)
          fill_args_from_config_and_run()
        end,
        on_fail = function()
          vim.notify("Loading container workspace dir failed, continuing with default dir", vim.log.levels.WARN)
          data = config_file.fill_container_workspace_folder(data, "/")
          fill_args_from_config_and_run()
        end,
      })
    end
  else
    fill_args_from_config_and_run()
  end
end

local function generate_image_run_command(data)
  if data.overrideCommand then
    local command = {}
    table.insert(command, "/bin/sh")
    table.insert(command, "-c")
    table.insert(command, "while sleep 1000; do :; done")
    return command
  else
    return nil
  end
end

local function generate_exec_command_args(container_id, data, continuation)
  local exec_args = nil
  if data.remoteUser then
    exec_args = exec_args or {}
    table.insert(exec_args, "--user")
    table.insert(exec_args, data.remoteUser)
  elseif data.containerUser then
    exec_args = exec_args or {}
    table.insert(exec_args, "--user")
    table.insert(exec_args, data.containerUser)
  end
  if data.workspaceFolder or data.workspaceMount then
    -- if data.workspaceMount == nil or data.workspaceFolder == nil then
    -- 	vim.notify("workspaceFolder and workspaceMount have to both be defined to be used!", vim.log.levels.WARN)
    -- else
    exec_args = exec_args or {}
    table.insert(exec_args, "--workdir")
    local container = status.find_container({ container_id = container_id })
    if container and container.workspace_dir then
      table.insert(exec_args, container.workspace_dir)
    else
      table.insert(exec_args, data.workspaceFolder)
    end
    -- end
  end

  local function continue_with_env(current_exec_args, env_vars)
    for k, v in pairs(env_vars) do
      table.insert(current_exec_args, "--env")
      table.insert(current_exec_args, k .. "=" .. v)
    end
    continuation(current_exec_args)
  end

  -- Env is filled asynchronously, due to dependency on current container state
  local env_vars = nil
  if data.remoteEnv then
    env_vars = env_vars or {}
    env_vars = vim.tbl_extend("force", env_vars, data.remoteEnv)
  end
  if plugin_config.remote_env then
    env_vars = env_vars or {}
    env_vars = vim.tbl_extend("force", env_vars, plugin_config.remote_env)
  end
  if env_vars then
    exec_args = exec_args or {}
    if config_file.remote_env_needs_fill(env_vars) then
      container_utils.get_container_env(container_id, {
        on_success = function(env_map)
          env_vars = config_file.fill_remote_env(env_vars, env_map)
          continue_with_env(exec_args, env_vars)
        end,
        on_fail = function()
          vim.notify("Loading container env failed, continuing with missing env", vim.log.levels.WARN)
          continue_with_env(exec_args, env_vars)
        end,
      })
    else
      continue_with_env(exec_args, env_vars)
    end
  else
    continuation(exec_args)
  end
end

local function generate_compose_up_command_args(data)
  local run_args = nil
  if data.runServices then
    run_args = run_args or {}
    vim.list_extend(run_args, data.runServices)
  end
  return run_args
end

---Run docker-compose up from nearest devcontainer.json file
---@param callback? function called on success - parsed devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").compose_up()`
function M.compose_up(callback)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })

  local on_success = callback
    or function(config)
      vim.notify("Successfully started services from " .. config.metadata.file_path)
    end

  get_nearest_devcontainer_config(function(data)
    if not data.dockerComposeFile then
      vim.notify(
        "Parsed devcontainer file (" .. data.metadata.file_path .. ") does not contain docker compose definition!",
        vim.log.levels.ERROR
      )
      return
    end

    compose_runtime.up(data.dockerComposeFile, {
      args = generate_compose_up_command_args(data),
      on_success = function()
        on_success(data)
      end,
      on_fail = function()
        vim.notify("Docker compose up failed!", vim.log.levels.ERROR)
      end,
    })
  end)
end

---Run docker-compose down from nearest devcontainer.json file
---@param callback? function called on success - parsed devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").compose_down()`
function M.compose_down(callback)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })

  local on_success = callback
    or function(config)
      vim.notify("Successfully stopped services from " .. config.metadata.file_path)
    end

  get_nearest_devcontainer_config(function(data)
    if not data.dockerComposeFile then
      vim.notify(
        "Parsed devcontainer file (" .. data.metadata.file_path .. ") does not contain docker compose definition!",
        vim.log.levels.ERROR
      )
      return
    end

    compose_runtime.down(data.dockerComposeFile, {
      on_success = function()
        on_success(data)
      end,
      on_fail = function()
        vim.notify("Docker compose down failed!", vim.log.levels.ERROR)
      end,
    })
  end)
end

---Run docker-compose rm from nearest devcontainer.json file
---@param callback? function called on success - parsed devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").compose_rm()`
function M.compose_rm(callback)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })

  local on_success = callback
    or function(config)
      vim.notify("Successfully removed services from " .. config.metadata.file_path)
    end

  get_nearest_devcontainer_config(function(data)
    if not data.dockerComposeFile then
      vim.notify(
        "Parsed devcontainer file (" .. data.metadata.file_path .. ") does not contain docker compose definition!",
        vim.log.levels.ERROR
      )
      return
    end

    compose_runtime.rm(data.dockerComposeFile, {
      on_success = function()
        on_success(data)
      end,
      on_fail = function()
        vim.notify("Docker compose rm failed!", vim.log.levels.ERROR)
      end,
    })
  end)
end

---Run docker build from nearest devcontainer.json file
---@param callback? function called on success - parsed devcontainer config and image id are passed to the callback
---@usage `require("devcontainer.commands").docker_build()`
function M.docker_build(callback)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })

  local on_success = callback
    or function(config, image_id)
      vim.notify("Successfully built docker image (" .. image_id .. ") from " .. config.build.dockerfile)
    end

  get_nearest_devcontainer_config(function(data)
    if not data.build.dockerfile then
      vim.notify(
        "Found devcontainer.json does not have dockerfile specified! - " .. data.metadata.file_path,
        vim.log.levels.ERROR
      )
      return
    end
    container_runtime.build(data.build.dockerfile, data.build.context, {
      args = generate_build_command_args(data),
      on_success = function(image_id)
        on_success(data, image_id)
      end,
      on_fail = function()
        vim.notify("Building from " .. data.build.dockerfile .. " failed!", vim.log.levels.ERROR)
      end,
    })
  end)
end

---Run docker run from nearest devcontainer.json file
---@param callback? function called on success - devcontainer config and container id are passed to the callback
---@usage `require("devcontainer.commands").docker_image_run()`
function M.docker_image_run(callback)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })

  local on_success = callback
    or function(config, container_id)
      vim.notify(
        "Successfully started image ("
          .. config.image
          .. ") from "
          .. config.metadata.file_path
          .. " - container id: "
          .. container_id
      )
    end

  get_nearest_devcontainer_config(function(data)
    if not data.image then
      vim.notify(
        "Found devcontainer.json does not have image specified! - " .. data.metadata.file_path,
        vim.log.levels.ERROR
      )
      return
    end
    generate_run_command_args(data, data.image, function(run_command_args)
      container_runtime.run(data.image, {
        args = run_command_args,
        command = generate_image_run_command(data),
        on_success = function(container_id)
          on_success(data, container_id)
        end,
        on_fail = function()
          vim.notify("Running image " .. data.image .. " failed!", vim.log.levels.ERROR)
        end,
      })
    end)
  end)
end

local function attach_to_container(data, container_id, command, on_success)
  local function attach()
    generate_exec_command_args(container_id, data, function(args)
      if command == "nvim" and vim.fn.has("nvim-0.12") == 1 then
        container_runtime.exec(container_id, {
          tty = false,
          command = {
            "nvim",
            "--headless",
            "--listen",
            "/tmp/nvim-dev-container/" .. u.get_image_cache_tag() .. ".sock",
          },
          args = args,
          on_success = function() end,
          on_fail = function()
            vim.notify("Attaching to container (" .. container_id .. ") failed!", vim.log.levels.ERROR)
          end,
        })
        vim.cmd("sleep 1")
        vim.cmd("connect " .. sockets_dir .. "/" .. u.get_image_cache_tag() .. ".sock")
        vim.notify("Connected to Neovim in container! Use :detach to disconnect and go back to host neovim!")
        on_success()
      else
        container_runtime.exec(container_id, {
          tty = true,
          command = command,
          args = args,
          on_success = on_success,
          on_fail = function()
            vim.notify("Attaching to container (" .. container_id .. ") failed!", vim.log.levels.ERROR)
          end,
        })
      end
    end)
  end
  if command == "nvim" then
    container_runtime.exec(container_id, {
      command = { "nvim", "--version" },
      on_success = function()
        attach()
      end,
      on_fail = function()
        vim.notify("Neovim is not installed in the container. Installing it now.")
        vim.ui.select({ "Yes", "No" }, {
          prompt = "Neovim is not installed in the container. Would you like to install it now?",
          format_item = function(item)
            return item
          end,
        }, function(install_choice)
          if install_choice == "Yes" then
            nvim.add_neovim(container_id, {
              on_success = function()
                vim.ui.select({ "now", "later" }, {
                  prompt = "Installing Neovim in the container done. Do you wish to attach now?",
                  format_item = function(item)
                    return "Attach " .. item
                  end,
                }, function(choice)
                  if choice == "now" then
                    attach()
                  end
                end)
              end,
              install_as_root = plugin_config.nvim_install_as_root,
            })
          end
        end)
      end,
    })
  else
    attach()
  end
end

local function get_compose_service_container_id(data, on_success)
  compose_runtime.get_container_id(data.dockerComposeFile, data.service, {
    on_success = on_success,
  })
end

local function attach_to_compose_service(data, command, on_success)
  if not data.service then
    vim.notify(
      "service must be defined in " .. data.metadata.file_path .. " to attach to docker compose",
      vim.log.levels.ERROR
    )
    return
  end
  vim.notify("Found docker compose file definition. Attaching to service: " .. data.service)
  get_compose_service_container_id(data, function(container_id)
    attach_to_container(data, container_id, command, function()
      on_success(data)
    end)
  end)
end

local function run_docker_lifecycle_script(script, data, container_id)
  if type(script) == "string" then
    script = {
      "/bin/sh",
      "-c",
      script,
    }
  end
  if not vim.islist(script) and type(script) == "table" then
    for _, v in ipairs(script) do
      run_docker_lifecycle_script(v, data, container_id)
    end
    return
  end
  generate_exec_command_args(container_id, data, function(args)
    container_runtime.exec(container_id, {
      tty = false,
      command = script,
      args = args,
    })
  end)
end

local function run_docker_lifecycle_scripts(data, container_id)
  if data.onCreateCommand then
    run_docker_lifecycle_script(data.onCreateCommand, data, container_id)
  end
  if data.updateContentCommand then
    run_docker_lifecycle_script(data.updateContentCommand, data, container_id)
  end
  if data.postCreateCommand then
    run_docker_lifecycle_script(data.postCreateCommand, data, container_id)
  end
end

local function run_lifecycle_host_command(host_command)
  if host_command then
    local args = {}
    local command = host_command
    if vim.islist(command) then
      command = command[1]
      args = { unpack(host_command, 2) }
    elseif type(command) == "table" then
      -- Dealing with object type
      for _, v in ipairs(command) do
        run_lifecycle_host_command(v)
      end
      return
    elseif type(command) == "string" then
      command = "/bin/sh"
      args = { "-c", host_command }
    end
    executor.run_command(command, {
      args = args,
      stderr = vim.schedule_wrap(function(_, output)
        if output then
          log.fmt_error("%s command (%s): %s", command, args, output)
        end
      end),
    })
  end
end

local function run_image_with_cache(data, image_id, attach, add_neovim, on_success)
  local function run_and_attach(image)
    generate_run_command_args(data, image, function(run_command_args)
      container_runtime.run(image, {
        args = run_command_args,
        command = generate_image_run_command(data),
        on_success = function(container_id)
          -- Update image_id to original ID for later retrieval
          local container = status.find_container({ container_id = container_id })
          container.image_id = image_id
          status.add_container(container)
          run_docker_lifecycle_scripts(data, container_id)
          local attach_and_notify = function()
            run_lifecycle_host_command(data.postStartCommand)
            if attach then
              attach_to_container(data, container_id, "nvim", function()
                on_success(data, image, container_id)
              end)
            else
              on_success(data, image, container_id)
            end
          end
          if add_neovim then
            nvim.add_neovim(container_id, {
              on_success = attach_and_notify,
              install_as_root = plugin_config.nvim_install_as_root,
            })
          else
            attach_and_notify()
          end
        end,
        on_fail = function()
          vim.notify("Running built image (" .. image_id .. ") failed!", vim.log.levels.ERROR)
        end,
      })
    end)
  end
  local tag = u.get_image_cache_tag()
  container_runtime.image_contains(tag, image_id, {
    on_success = function(contains)
      if contains then
        run_and_attach(tag)
      else
        run_and_attach(image_id)
      end
    end,
    on_fail = function()
      run_and_attach(image_id)
    end,
  })
end

local function spawn_docker_build_and_run(data, on_success, add_neovim, attach)
  container_runtime.build(data.build.dockerfile, data.build.context, {
    args = generate_build_command_args(data),
    on_success = function(image_id)
      run_image_with_cache(data, image_id, attach, add_neovim, on_success)
    end,
    on_fail = function()
      vim.notify("Building image from (" .. data.build.dockerfile .. ") failed!", vim.log.levels.ERROR)
    end,
  })
end

local function execute_docker_build_and_run(callback, add_neovim)
  local on_success = callback
    or function(config, image_id, container_id)
      vim.notify(
        "Successfully started image ("
          .. image_id
          .. ") from "
          .. config.metadata.file_path
          .. " - container id: "
          .. container_id
      )
    end

  get_nearest_devcontainer_config(function(data)
    if not data.build.dockerfile then
      vim.notify(
        "Found devcontainer.json does not have dockerfile specified! - " .. data.metadata.file_path,
        vim.log.levels.ERROR
      )
      return
    end
    spawn_docker_build_and_run(data, on_success, add_neovim, add_neovim)
  end)
end

---Run docker run from nearest devcontainer.json file, building before that
---@param callback? function called on success - devcontainer config and container id are passed to the callback
---@usage `require("devcontainer.commands").docker_build_and_run()`
function M.docker_build_and_run(callback)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })

  execute_docker_build_and_run(callback, false)
end

---Run docker run from nearest devcontainer.json file, building before that
---And then attach to the container with neovim added
---@param callback? function called on success - devcontainer config and container id are passed to the callback
---@usage `require("devcontainer.commands").docker_build_run_and_attach()`
function M.docker_build_run_and_attach(callback)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })

  execute_docker_build_and_run(callback, true)
end

---Parses devcontainer.json and starts whatever is defined there
---Looks for dockerComposeFile first
---Then it looks for dockerfile
---And last it looks for image
---@param callback? function called on success - devcontainer config is passed to the callback
---@param attach? boolean if true, automatically attach after starting
---@usage `require("devcontainer.commands").start_auto()`
function M.start_auto(callback, attach)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })

  local on_success = callback
    or function(config)
      vim.notify("Successfully started from " .. config.metadata.file_path)
    end

  get_nearest_devcontainer_config(function(data)
    if data.dockerComposeFile then
      vim.notify("Found docker compose file definition. Running docker compose up...")
      compose_runtime.up(data.dockerComposeFile, {
        args = generate_compose_up_command_args(data),
        on_success = function()
          run_lifecycle_host_command(data.postStartCommand)
          if attach then
            attach_to_compose_service(data, on_success)
          else
            on_success(data)
          end
        end,
        on_fail = function()
          vim.notify("Docker compose up failed!", vim.log.levels.ERROR)
        end,
      })
      return
    end

    if data.build.dockerfile then
      vim.notify("Found dockerfile definition. Running docker build and run...")
      spawn_docker_build_and_run(data, on_success, attach, attach)
      return
    end

    if data.image then
      vim.notify("Found image definition. Running docker run...")
      run_image_with_cache(data, data.image, attach, attach, on_success)
      return
    end
  end)
end

---Parses devcontainer.json and attaches to whatever is defined there
---Looks for dockerComposeFile first
---Then it looks for dockerfile
---And last it looks for image
---@param target string container id, or latest or devcontainer
---@param command string|table command to run on container
---@param callback? function called on success - devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").attach_auto()`
function M.attach_auto(target, command, callback)
  vim.validate({
    target = { target, "string" },
    command = { command, { "string", "table" } },
    callback = { callback, { "function", "nil" } },
  })

  local on_success = callback
    or function(config)
      vim.notify("Successfully attached to container from " .. config.metadata.file_path)
    end

  if target ~= "devcontainer" then
    if target == "latest" then
      target = "-l"
    end

    attach_to_container({}, target, command, function()
      on_success({})
    end)
    return
  end

  get_nearest_devcontainer_config(function(data)
    if data.dockerComposeFile then
      attach_to_compose_service(data, command, function()
        on_success(data)
      end)
      run_lifecycle_host_command(data.postAttachCommand)
      return
    end

    if data.build.dockerfile then
      vim.notify("Found dockerfile definition. Attaching to the container...")
      local image = status.find_image({ source_dockerfile = data.build.dockerfile })
      local container = status.find_container({ image_id = image.image_id })
      attach_to_container(data, container.container_id, command, function()
        on_success(data)
      end)
      run_lifecycle_host_command(data.postAttachCommand)
      return
    end

    if data.image then
      vim.notify("Found image definition. Attaching to the container...")
      local container = status.find_container({ image_id = data.image })
      attach_to_container(data, container.container_id, command, function()
        on_success(data)
      end)
      run_lifecycle_host_command(data.postAttachCommand)
      return
    end
  end)
end

---Parses devcontainer.json and stops whatever is defined there
---Looks for dockerComposeFile first
---Then it looks for dockerfile
---And last it looks for image
---@param target string container id, or latest or devcontainer
---@param command string|table command to run on container
---@param callback? function called on success - devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").exec("devcontainer", "ls", { on_success = function(result) end })`
function M.exec(target, command, callback)
  vim.validate({
    target = { target, "string" },
    command = { command, { "string", "table" } },
    callback = { callback, { "function", "nil" } },
  })

  local on_success = callback
    or function(result)
      vim.notify(
        "Successfully executed command "
          .. vim.inspect(command)
          .. " on container ("
          .. target
          .. ")! Result: \n"
          .. (result or "nil")
      )
    end

  local original_target = target
  local on_fail = function()
    vim.notify(
      "Executing command " .. vim.inspect(command) .. " on container (" .. original_target .. ") failed!",
      vim.log.levels.ERROR
    )
  end

  if target ~= "devcontainer" then
    if target == "latest" then
      target = "-l"
    end
    container_runtime.exec(target, {
      command = command,
      capture_output = true,
      on_success = on_success,
      on_fail = on_fail,
    })
    return
  end

  get_nearest_devcontainer_config(function(data)
    local execution_func = function(final_target)
      generate_exec_command_args(final_target, data, function(args)
        container_runtime.exec(final_target, {
          command = command,
          args = args,
          capture_output = true,
          on_success = on_success,
          on_fail = on_fail,
        })
      end)
    end

    if data.dockerComposeFile then
      get_compose_service_container_id(data, function(container_id)
        execution_func(container_id)
      end)
      return
    end

    if data.build.dockerfile then
      local image = status.find_image({ source_dockerfile = data.build.dockerfile })
      local container = status.find_container({ image_id = image.image_id })
      execution_func(container.container_id)
      return
    end

    if data.image then
      local container = status.find_container({ image_id = data.image })
      execution_func(container.container_id)
      return
    end

    execution_func(target)
  end)
end

---Parses devcontainer.json and stops whatever is defined there
---Looks for dockerComposeFile first
---Then it looks for dockerfile
---And last it looks for image
---@param callback? function called on success - devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").stop_auto()`
function M.stop_auto(callback)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })

  local on_success = callback
    or function(config)
      vim.notify("Successfully stopped services from " .. config.metadata.file_path)
    end

  get_nearest_devcontainer_config(function(data)
    if data.dockerComposeFile then
      vim.notify("Found docker compose file definition. Running docker compose down...")
      compose_runtime.down(data.dockerComposeFile, {
        on_success = function()
          on_success(data)
        end,
        on_fail = function()
          vim.notify("Docker compose down failed!", vim.log.levels.ERROR)
        end,
      })
      return
    end

    if data.build.dockerfile then
      vim.notify("Found dockerfile definition. Running docker container stop...")
      local image = status.find_image({ source_dockerfile = data.build.dockerfile })
      if image then
        local container = status.find_container({ image_id = image.image_id })
        container_runtime.container_stop({ container.container_id }, {
          on_success = function()
            on_success(data)
          end,
          on_fail = function()
            vim.notify("Docker container stop failed!", vim.log.levels.ERROR)
          end,
        })
      else
        log.info("No containers found to stop.")
        on_success(data)
      end
      return
    end

    if data.image then
      vim.notify("Found image definition. Running docker container stop...")
      local container = status.find_container({ image_id = data.image })
      container_runtime.container_stop({ container.container_id }, {
        on_success = function()
          on_success(data)
        end,
        on_fail = function()
          vim.notify("Docker container stop failed!", vim.log.levels.ERROR)
        end,
      })
      return
    end
  end)
end

---Stops everything started with devcontainer plugin
---@param callback? function called on success
---@usage `require("devcontainer.commands").stop_all()`
function M.stop_all(callback)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })

  local on_success = callback or function()
    vim.notify("Successfully stopped all services!")
  end
  local success_count = 0
  local success_wrapper = function()
    success_count = success_count + 1
    if success_count == 2 then
      on_success()
    end
  end

  local all_status = status.get_status()
  local containers_to_stop = vim.tbl_map(function(cstatus)
    return cstatus.container_id
  end, all_status.running_containers)
  if #containers_to_stop > 0 then
    container_runtime.container_stop(containers_to_stop, {
      on_success = success_wrapper,
      on_fail = function()
        vim.notify("Docker container stop failed!", vim.log.levels.ERROR)
      end,
    })
  else
    success_wrapper()
  end
  local compose_services_to_stop = vim.tbl_map(function(cstatus)
    return cstatus.file
  end, all_status.compose_services)
  if #compose_services_to_stop > 0 then
    compose_runtime.down(compose_services_to_stop, {
      on_success = success_wrapper,
      on_fail = function()
        vim.notify("Docker compose down failed!", vim.log.levels.ERROR)
      end,
    })
  else
    success_wrapper()
  end
end

---Removes everything started with devcontainer plugin
---@param callback? function called on success
---@usage `require("devcontainer.commands").remove_all()`
function M.remove_all(callback)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })

  local on_success = callback or function()
    vim.notify("Successfully removed all containers and images!")
  end

  local all_status = status.get_status()
  local images_to_remove = vim.tbl_map(function(cstatus)
    return cstatus.image_id
  end, all_status.images_built)
  local containers_to_remove = vim.tbl_map(function(cstatus)
    return cstatus.container_id
  end, all_status.running_containers)
  local compose_services_to_remove = vim.tbl_map(function(cstatus)
    return cstatus.file
  end, all_status.compose_services)

  local success_count = 0
  local success_wrapper
  success_wrapper = function()
    success_count = success_count + 1
    if success_count == 2 then
      if #images_to_remove > 0 then
        container_runtime.image_rm(images_to_remove, {
          force = true,
          on_success = success_wrapper,
          on_fail = function()
            vim.notify("Docker image remove failed!", vim.log.levels.ERROR)
          end,
        })
      else
        success_wrapper()
      end
    end
    if success_count == 3 then
      on_success()
    end
  end
  if #containers_to_remove > 0 then
    container_runtime.container_rm(containers_to_remove, {
      force = true,
      on_success = success_wrapper,
      on_fail = function()
        vim.notify("Docker container remove failed!", vim.log.levels.ERROR)
      end,
    })
  else
    success_wrapper()
  end
  if #compose_services_to_remove > 0 then
    compose_runtime.rm(compose_services_to_remove, {
      on_success = success_wrapper,
      on_fail = function()
        vim.notify("Docker compose remove failed!", vim.log.levels.ERROR)
      end,
    })
  else
    success_wrapper()
  end
end

---Opens log file in a new buffer
---@usage `require("devcontainer.commands").open_logs()`
function M.open_logs()
  vim.cmd("edit " .. log.logfile)
end

---Opens nearest devcontainer config in a new buffer
---@usage `require("devcontainer.commands").open_nearest_devcontainer_config()`
function M.open_nearest_devcontainer_config()
  config_file.find_nearest_devcontainer_config(vim.schedule_wrap(function(err, data)
    if err then
      vim.notify("Can't find devcontainer config: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end
    vim.cmd("edit " .. data)
    vim.cmd("setlocal filetype=jsonc")
  end))
end

---Opens nearest devcontainer config in a new buffer or creates a new one in .devcontainer/devcontainer.json
---@usage `require("devcontainer.commands").edit_devcontainer_config()`
function M.edit_devcontainer_config()
  config_file.find_nearest_devcontainer_config(vim.schedule_wrap(function(err, data)
    local path = data
    if err then
      local project_root = plugin_config.workspace_folder_provider()
      vim.fn.mkdir(project_root .. u.path_sep .. ".devcontainer", "p")
      path = project_root .. u.path_sep .. ".devcontainer" .. u.path_sep .. "devcontainer.json"
    end
    vim.cmd("edit " .. path)
    if err then
      vim.api.nvim_buf_set_lines(0, 0, -1, false, plugin_config.devcontainer_json_template())
    end
    vim.cmd("setlocal filetype=jsonc")
  end))
end

log.wrap(M)
return M
