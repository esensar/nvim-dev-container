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
  end
  -- Default
  return require("devcontainer.internal.runtimes.container.docker")
end

local function get_current_compose_runtime()
  if config.compose_command == "docker-compose" then
    return require("devcontainer.internal.runtimes.compose.docker-compose")
  end
  -- Default
  return require("devcontainer.internal.runtimes.compose.docker-compose")
end

M.container = {}

---Pull passed image using current container runtime
---@param image string Image to pull
---@param opts ContainerPullOpts Additional options including callbacks
function M.container.pull(image, opts)
  return get_current_container_runtime().pull(image, opts)
end

---Build image from passed dockerfile using current container runtime
---@param file string Path to file (Dockerfile or something else) to build
---@param path string Path to the workspace, vim.lsp.buf.list_workspace_folders()[1] by default
---@param opts ContainerBuildOpts Additional options including callbacks and tag
function M.container.build(file, path, opts)
  return get_current_container_runtime().build(file, path, opts)
end

---Run passed image using current container runtime
---NOTE: If terminal_handler is passed, then it needs to start the process too - default termopen does just that
---@param image string Image to run
---@param opts ContainerRunOpts Additional options including callbacks
function M.container.run(image, opts)
  return get_current_container_runtime().run(image, opts)
end

---Run command on a container using current container runtime
---Useful for attaching to neovim, or running arbitrary commands in container
---NOTE: If terminal_handler is passed, then it needs to start the process too - default termopen does just that
---@param container_id string Container to exec on
---@param opts ContainerExecOpts Additional options including callbacks
function M.container.exec(container_id, opts)
  return get_current_container_runtime().exec(container_id, opts)
end

---Stop passed containers
---@param containers table[string] ids of containers to stop
---@param opts ContainerStopOpts Additional options including callbacks
function M.container.container_stop(containers, opts)
  return get_current_container_runtime().container_stop(containers, opts)
end

---Removes passed images
---@param images table[string] ids of images to remove
---@param opts ImageRmOpts Additional options including callbacks
function M.container.image_rm(images, opts)
  return get_current_container_runtime().image_rm(images, opts)
end

---Removes passed containers
---@param containers table[string] ids of containers to remove
---@param opts ContainerRmOpts Additional options including callbacks
function M.container.container_rm(containers, opts)
  return get_current_container_runtime().container_rm(containers, opts)
end

---Lists containers
---@param opts ContainerLsOpts Additional options including callbacks
function M.container.container_ls(opts)
  return get_current_container_runtime().container_ls(opts)
end

M.compose = {}

---Run compose up with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts ComposeUpOpts Additional options including callbacks
function M.compose.up(compose_file, opts)
  return get_current_compose_runtime().up(compose_file, opts)
end

---Run compose down with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts ComposeDownOpts Additional options including callbacks
function M.compose.down(compose_file, opts)
  return get_current_compose_runtime().down(compose_file, opts)
end

---Run compose ps with passed file and service to get its container_id
---@param compose_file string|table path to docker-compose.yml file or files
---@param service string service name
---@param opts ComposeGetContainerIdOpts Additional options including callbacks
function M.compose.get_container_id(compose_file, service, opts)
  return get_current_compose_runtime().get_container_id(compose_file, service, opts)
end

return M
