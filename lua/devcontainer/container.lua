---@mod devcontainer.container Container module
---@brief [[
---Provides functions related to container control:
--- - building
--- - attaching
--- - running
---@brief ]]
local v = require("devcontainer.internal.validation")
local log = require("devcontainer.internal.log")
local runtimes = require("devcontainer.internal.runtimes")

local M = {}

-- TODO: Move to utils
local function command_to_repr(command)
  if type(command) == "string" then
    return command
  elseif type(command) == "table" then
    return table.concat(command, " ")
  end
  return ""
end

---@class ContainerPullOpts
---@field on_success function() success callback
---@field on_fail function() failure callback

---Pull passed image using docker pull
---@param image string Docker image to pull
---@param opts ContainerPullOpts Additional options including callbacks
---@usage `require("devcontainer.container").pull("alpine", { on_success = function() end, on_fail = function() end})`
function M.pull(image, opts)
  vim.validate({
    image = { image, "string" },
    opts = { opts, { "table", "nil" } },
  })
  opts = opts or {}
  v.validate_callbacks(opts)
  opts.on_success = opts.on_success or function()
    vim.notify("Successfully pulled image " .. image)
  end
  opts.on_fail = opts.on_fail
    or function()
      vim.notify("Pulling image " .. image .. " failed!", vim.log.levels.ERROR)
    end

  runtimes.container.pull(image, opts)
end

---@class ContainerBuildOpts
---@field tag? string tag for the image built
---@field args? table list of additional arguments to build command
---@field on_success function(image_id) success callback taking the image_id of the built image
---@field on_progress? function(DevcontainerBuildStatus) callback taking build status object
---@field on_fail function() failure callback

---Build image from passed dockerfile using docker build
---@param file string Path to Dockerfile to build
---@param path? string Path to the workspace, vim.lsp.buf.list_workspace_folders()[1] by default
---@param opts ContainerBuildOpts Additional options including callbacks and tag
---@usage [[
---require("devcontainer.container").build(
---  "Dockerfile",
---  { on_success = function(image_id) end, on_fail = function() end }
---)
---@usage ]]
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
    args = function(x)
      return x == nil or vim.tbl_islist(x)
    end,
  })
  opts.on_success = opts.on_success
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
  local user_on_success = opts.on_success
  opts.on_success = function(image_id)
    vim.api.nvim_exec_autocmds(
      "User",
      { pattern = "DevcontainerImageBuilt", modeline = false, data = { image_id = image_id } }
    )
    user_on_success(image_id)
  end
  opts.on_fail = opts.on_fail
    or function()
      vim.notify("Building image from file " .. file .. " failed!", vim.log.levels.ERROR)
    end
  local original_on_progress = opts.on_progress
  opts.on_progress = function(build_status)
    vim.api.nvim_exec_autocmds("User", { pattern = "DevcontainerBuildProgress", modeline = false })
    if original_on_progress then
      original_on_progress(build_status)
    end
  end

  runtimes.container.build(file, path, opts)
end

---@class ContainerRunOpts
---@field autoremove? boolean automatically remove container after stopping - true by default
---@field command string|table|nil command to run in container
---@field args? table list of additional arguments to run command
---@field on_success function(container_id) success callback taking the id of the started container - not invoked if tty
---@field on_fail function() failure callback

---Run passed image using docker run
---NOTE: If terminal_handler is passed, then it needs to start the process too - default termopen does just that
---@param image string Docker image to run
---@param opts ContainerRunOpts Additional options including callbacks
---@usage `require("devcontainer.container").run("alpine", { on_success = function(id) end, on_fail = function() end })`
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
  opts.on_success = opts.on_success or function(_)
    vim.notify("Successfully started image " .. image)
  end
  local user_on_success = opts.on_success
  opts.on_success = function(container_id)
    vim.api.nvim_exec_autocmds(
      "User",
      { pattern = "DevcontainerContainerStarted", modeline = false, data = { container_id = container_id } }
    )
    user_on_success(container_id)
  end
  opts.on_fail = opts.on_fail
    or function()
      vim.notify("Starting image " .. image .. " failed!", vim.log.levels.ERROR)
    end

  runtimes.container.run(image, opts)
end

---@class ContainerExecOpts
---@field tty? boolean attach to container TTY and display it in terminal buffer, using configured terminal handler
---@field terminal_handler? function override to open terminal in a different way, :tabnew + termopen by default
---@field capture_output? boolean if true captures output and passes it to success callback - incompatible with tty
---@field command string|table|nil command to run in container
---@field args? table list of additional arguments to exec command
---@field on_success? function(output?) success callback - not called if tty
---@field on_fail? function() failure callback - not called if tty

---Run command on a container using docker exec
---Useful for attaching to neovim
---NOTE: If terminal_handler is passed, then it needs to start the process too - default termopen does just that
---@param container_id string Docker container to exec on
---@param opts ContainerExecOpts Additional options including callbacks
---@usage[[
---require("devcontainer.container").exec(
---  "some_id",
---  { command = "nvim", on_success = function() end, on_fail = function() end }
---)
---@usage]]
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
  opts.on_success = opts.on_success
    or function(_)
      vim.notify("Successfully executed command " .. command_to_repr(opts.command) .. " on container " .. container_id)
    end
  opts.on_fail = opts.on_fail
    or function()
      vim.notify(
        "Executing command " .. command_to_repr(opts.command) .. " on container " .. container_id .. " failed!",
        vim.log.levels.ERROR
      )
    end

  return runtimes.container.exec(container_id, opts)
end

---@class ContainerStopOpts
---@field on_success function() success callback
---@field on_fail function() failure callback

---Stop passed containers
---@param containers table[string] ids of containers to stop
---@param opts ContainerStopOpts Additional options including callbacks
---@usage [[
---require("devcontainer.container").container_stop(
---  { "some_id" },
---  { on_success = function() end, on_fail = function() end }
---)
---@usage ]]
function M.container_stop(containers, opts)
  vim.validate({
    containers = { containers, "table" },
  })
  opts = opts or {}
  v.validate_callbacks(opts)
  opts.on_success = opts.on_success or function()
    vim.notify("Successfully stopped containers!")
  end
  local user_on_success = opts.on_success
  opts.on_success = function()
    for _, container_id in ipairs(containers) do
      vim.api.nvim_exec_autocmds(
        "User",
        { pattern = "DevcontainerContainerStopped", modeline = false, data = { container_id = container_id } }
      )
    end
    user_on_success()
  end
  opts.on_fail = opts.on_fail or function()
    vim.notify("Stopping containers failed!", vim.log.levels.ERROR)
  end

  runtimes.container.container_stop(containers, opts)
end

---@class ImageRmOpts
---@field force? boolean force deletion
---@field on_success function() success callback
---@field on_fail function() failure callback

---Removes passed images
---@param images table[string] ids of images to remove
---@param opts ImageRmOpts Additional options including callbacks
---@usage[[
---require("devcontainer.container").image_rm(
---  { "some_id" },
---  { on_success = function() end, on_fail = function() end }
---)
---@usage]]
function M.image_rm(images, opts)
  vim.validate({
    images = { images, "table" },
  })
  opts = opts or {}
  v.validate_callbacks(opts)
  opts.on_success = opts.on_success or function()
    vim.notify("Successfully removed images!")
  end
  local user_on_success = opts.on_success
  opts.on_success = function()
    for _, image_id in ipairs(images) do
      vim.api.nvim_exec_autocmds(
        "User",
        { pattern = "DevcontainerImageRemoved", modeline = false, data = { image_id = image_id } }
      )
    end
    user_on_success()
  end
  opts.on_fail = opts.on_fail or function()
    vim.notify("Removing images failed!", vim.log.levels.ERROR)
  end

  runtimes.container.image_rm(images, opts)
end

---@class ContainerRmOpts
---@field force? boolean force deletion
---@field on_success function() success callback
---@field on_fail function() failure callback

---Removes passed containers
---@param containers table[string] ids of containers to remove
---@param opts ContainerRmOpts Additional options including callbacks
---@usage[[
---require("devcontainer.container").container_rm(
---  { "some_id" },
---  { on_success = function() end, on_fail = function() end }
---)
---@usage]]
function M.container_rm(containers, opts)
  vim.validate({
    containers = { containers, "table" },
  })
  opts = opts or {}
  v.validate_callbacks(opts)
  opts.on_success = opts.on_success or function()
    vim.notify("Successfully removed containers!")
  end
  local user_on_success = opts.on_success
  opts.on_success = function()
    for _, container_id in ipairs(containers) do
      vim.api.nvim_exec_autocmds(
        "User",
        { pattern = "DevcontainerContainerRemoved", modeline = false, data = { container_id = container_id } }
      )
    end
    user_on_success()
  end
  opts.on_fail = opts.on_fail or function()
    vim.notify("Removing containers failed!", vim.log.levels.ERROR)
  end

  runtimes.container.container_rm(containers, opts)
end

---@class ContainerLsOpts
---@field all? boolean show all containers, not only running
---@field async? boolean run async - true by default
---@field on_success function(containers_list) success callback
---@field on_fail function() failure callback

---Lists containers
---@param opts ContainerLsOpts Additional options including callbacks
---@usage[[
---require("devcontainer.container").container_ls(
---  { on_success = function(containers) end, on_fail = function() end }
---)
---@usage]]
function M.container_ls(opts)
  opts = opts or {}
  v.validate_callbacks(opts)
  v.validate_opts(opts, { all = { "boolean", "nil" } })
  opts.on_success = opts.on_success
    or function(containers)
      vim.notify("Containers: " .. table.concat(containers, ", "))
    end
  opts.on_fail = opts.on_fail or function()
    vim.notify("Loading containers failed!", vim.log.levels.ERROR)
  end

  return runtimes.container.container_ls(opts)
end

log.wrap(M)
return M
