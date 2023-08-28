---@mod devcontainer.internal.runtimes Runtimes module
---@brief [[
---Provides shared interface for runtimes
---Expects valid inputs and does not do any validation on its own
---@brief ]]

local M = {}

local config = require("devcontainer.config")

local function get_current_container_runtime()
  if config.container_runtime == "docker" then
    return require("devcontainer.internal.runtimes.container.docker")
  elseif config.container_runtime == "podman" then
    return require("devcontainer.internal.runtimes.container.podman")
  elseif config.container_runtime == "devcontainer-cli" then
    return require("devcontainer.internal.runtimes.container.devcontainer")
  end
  -- Default
  return require("devcontainer.internal.runtimes.helpers.common_container").new({ runtime = config.container_runtime })
end

local function get_backup_container_runtime()
  if config.backup_runtime == "docker" then
    return require("devcontainer.internal.runtimes.container.docker")
  elseif config.backup_runtime == "podman" then
    return require("devcontainer.internal.runtimes.container.podman")
  elseif config.backup_runtime == "devcontainer-cli" then
    return require("devcontainer.internal.runtimes.container.devcontainer")
  end
  -- Default
  return require("devcontainer.internal.runtimes.helpers.common_container").new({ runtime = config.backup_runtime })
end

local function get_current_compose_runtime()
  if config.compose_command == "docker-compose" then
    return require("devcontainer.internal.runtimes.compose.docker-compose")
  elseif config.compose_command == "podman-compose" then
    return require("devcontainer.internal.runtimes.compose.podman-compose")
  elseif config.compose_command == "docker compose" then
    return require("devcontainer.internal.runtimes.compose.docker")
  elseif config.compose_command == "devcontainer-cli" then
    return require("devcontainer.internal.runtimes.compose.devcontainer")
  end
  -- Default
  return require("devcontainer.internal.runtimes.helpers.common_compose").new({ runtime = config.compose_command })
end

local function get_backup_compose_runtime()
  if config.backup_compose_command == "docker-compose" then
    return require("devcontainer.internal.runtimes.compose.docker-compose")
  elseif config.backup_compose_command == "podman-compose" then
    return require("devcontainer.internal.runtimes.compose.podman-compose")
  elseif config.backup_compose_command == "docker compose" then
    return require("devcontainer.internal.runtimes.compose.docker")
  elseif config.backup_compose_command == "devcontainer-cli" then
    return require("devcontainer.internal.runtimes.compose.devcontainer")
  end
  -- Default
  return require("devcontainer.internal.runtimes.helpers.common_compose").new({
    runtime = config.backup_compose_command,
  })
end

local function run_with_container(required_func, callback)
  local current = get_current_container_runtime()
  if current[required_func] then
    return callback(current, current[required_func])
  else
    local backup = get_backup_container_runtime()
    if backup[required_func] then
      return callback(backup, backup[required_func])
    else
      vim.notify(
        "Function "
          .. required_func
          .. " is not supported on either "
          .. config.container_runtime
          .. " or "
          .. config.backup_runtime
      )
      return nil
    end
  end
end

local function run_with_compose(required_func, callback)
  local current = get_current_compose_runtime()
  if current[required_func] then
    return callback(current, current[required_func])
  else
    local backup = get_backup_compose_runtime()
    if backup[required_func] then
      return callback(backup, backup[required_func])
    else
      vim.notify(
        "Function "
          .. required_func
          .. " is not supported on either "
          .. config.compose_command
          .. " or "
          .. config.backup_compose_command
      )
      return nil
    end
  end
end

M.container = {}

---Pull passed image using current container runtime
---@param image string Image to pull
---@param opts ContainerPullOpts Additional options including callbacks
function M.container.pull(image, opts)
  return run_with_container("pull", function(instance, func)
    func(instance, image, opts)
  end)
end

---Build image from passed dockerfile using current container runtime
---@param file string Path to file (Dockerfile or something else) to build
---@param path string Path to the workspace, vim.lsp.buf.list_workspace_folders()[1] by default
---@param opts ContainerBuildOpts Additional options including callbacks and tag
function M.container.build(file, path, opts)
  return run_with_container("build", function(instance, func)
    func(instance, file, path, opts)
  end)
end

---Run passed image using current container runtime
---NOTE: If terminal_handler is passed, then it needs to start the process too - default termopen does just that
---@param image string Image to run
---@param opts ContainerRunOpts Additional options including callbacks
function M.container.run(image, opts)
  return run_with_container("run", function(instance, func)
    func(instance, image, opts)
  end)
end

---Run command on a container using current container runtime
---Useful for attaching to neovim, or running arbitrary commands in container
---NOTE: If terminal_handler is passed, then it needs to start the process too - default termopen does just that
---@param container_id string Container to exec on
---@param opts ContainerExecOpts Additional options including callbacks
function M.container.exec(container_id, opts)
  return run_with_container("exec", function(instance, func)
    func(instance, container_id, opts)
  end)
end

---Stop passed containers
---@param containers table[string] ids of containers to stop
---@param opts ContainerStopOpts Additional options including callbacks
function M.container.container_stop(containers, opts)
  return run_with_container("container_stop", function(instance, func)
    func(instance, containers, opts)
  end)
end

---Commit passed container
---@param container string id of container to commit
---@param opts ContainerCommitOpts Additional options including callbacks
function M.container.container_commit(container, opts)
  return run_with_container("container_commit", function(instance, func)
    func(instance, container, opts)
  end)
end

---Checks if image contains another image
---@param parent_image string id of image that should contain other image
---@param child_image string id of image that should be contained in the parent image
---@param opts ImageContainsOpts Additional options including callbacks
function M.container.image_contains(parent_image, child_image, opts)
  return run_with_container("image_contains", function(instance, func)
    func(instance, parent_image, child_image, opts)
  end)
end

---Removes passed images
---@param images table[string] ids of images to remove
---@param opts ImageRmOpts Additional options including callbacks
function M.container.image_rm(images, opts)
  return run_with_container("image_rm", function(instance, func)
    func(instance, images, opts)
  end)
end

---Removes passed containers
---@param containers table[string] ids of containers to remove
---@param opts ContainerRmOpts Additional options including callbacks
function M.container.container_rm(containers, opts)
  return run_with_container("container_rm", function(instance, func)
    func(instance, containers, opts)
  end)
end

---Lists containers
---@param opts ContainerLsOpts Additional options including callbacks
function M.container.container_ls(opts)
  return run_with_container("container_ls", function(instance, func)
    func(instance, opts)
  end)
end

M.compose = {}

---Run compose up with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts ComposeUpOpts Additional options including callbacks
function M.compose.up(compose_file, opts)
  return run_with_compose("up", function(instance, func)
    func(instance, compose_file, opts)
  end)
end

---Run compose down with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts ComposeDownOpts Additional options including callbacks
function M.compose.down(compose_file, opts)
  return run_with_compose("down", function(instance, func)
    func(instance, compose_file, opts)
  end)
end

---Run compose ps with passed file and service to get its container_id
---@param compose_file string|table path to docker-compose.yml file or files
---@param service string service name
---@param opts ComposeGetContainerIdOpts Additional options including callbacks
function M.compose.get_container_id(compose_file, service, opts)
  return run_with_compose("get_container_id", function(instance, func)
    func(instance, compose_file, service, opts)
  end)
end

return M
