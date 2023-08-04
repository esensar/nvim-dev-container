---@mod devcontainer.internal.runtimes Runtimes module
---@brief [[
---Provides shared interface for runtimes
---@brief ]]

local M = {}

local config = require("devcontainer.config")

local function get_current_container_runtime()
  if config.container_runtime == "docker" then
    return require("devcontainer.internal.runtimes.container.docker")
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

---Pull passed image using docker pull
---@param image string Docker image to pull
---@param opts ContainerPullOpts Additional options including callbacks
---@usage `require("devcontainer.docker").pull("alpine", { on_success = function() end, on_fail = function() end})`
function M.container.pull(image, opts)
  get_current_container_runtime().pull(image, opts)
end

---Build image from passed dockerfile using docker build
---@param file string Path to Dockerfile to build
---@param path string Path to the workspace, vim.lsp.buf.list_workspace_folders()[1] by default
---@param opts ContainerBuildOpts Additional options including callbacks and tag
---@usage `docker.build("Dockerfile", { on_success = function(image_id) end, on_fail = function() end })`
function M.container.build(file, path, opts)
  get_current_container_runtime().build(file, path, opts)
end

---Run passed image using docker run
---NOTE: If terminal_handler is passed, then it needs to start the process too - default termopen does just that
---@param image string Docker image to run
---@param opts ContainerRunOpts Additional options including callbacks
---@usage `docker.run("alpine", { on_success = function(id) end, on_fail = function() end })`
function M.container.run(image, opts)
  get_current_container_runtime().run(image, opts)
end

---Run command on a container using docker exec
---Useful for attaching to neovim
---NOTE: If terminal_handler is passed, then it needs to start the process too - default termopen does just that
---@param container_id string Docker container to exec on
---@param opts ContainerExecOpts Additional options including callbacks
---@usage `docker.exec("some_id", { command = "nvim", on_success = function() end, on_fail = function() end })`
function M.container.exec(container_id, opts)
  get_current_container_runtime().exec(container_id, opts)
end

---Stop passed containers
---@param containers table[string] ids of containers to stop
---@param opts ContainerStopOpts Additional options including callbacks
---@usage `docker.container_stop({ "some_id" }, { on_success = function() end, on_fail = function() end })`
function M.container.container_stop(containers, opts)
  get_current_container_runtime().container_stop(containers, opts)
end

---Removes passed images
---@param images table[string] ids of images to remove
---@param opts ImageRmOpts Additional options including callbacks
---@usage `docker.image_rm({ "some_id" }, { on_success = function() end, on_fail = function() end })`
function M.container.image_rm(images, opts)
  get_current_container_runtime().image_rm(images, opts)
end

---Removes passed containers
---@param containers table[string] ids of containers to remove
---@param opts ContainerRmOpts Additional options including callbacks
---@usage `docker.container_rm({ "some_id" }, { on_success = function() end, on_fail = function() end })`
function M.container.container_rm(containers, opts)
  get_current_container_runtime().container_rm(containers, opts)
end

M.compose = {}

---Run docker-compose up with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts ComposeUpOpts Additional options including callbacks
---@usage `require("devcontainer.docker-compose").up("docker-compose.yml")`
function M.compose.up(compose_file, opts)
  get_current_compose_runtime().up(compose_file, opts)
end

---Run docker-compose down with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts ComposeDownOpts Additional options including callbacks
---@usage `require("devcontainer.docker-compose").down("docker-compose.yml")`
function M.compose.down(compose_file, opts)
  get_current_compose_runtime().down(compose_file, opts)
end

---Run docker-compose ps with passed file and service to get its container_id
---@param compose_file string|table path to docker-compose.yml file or files
---@param service string service name
---@param opts ComposeGetContainerIdOpts Additional options including callbacks
---@usage `docker_compose.get_container_id("docker-compose.yml", { on_success = function(container_id) end })`
function M.compose.get_container_id(compose_file, service, opts)
  get_current_compose_runtime().get_container_id(compose_file, service, opts)
end

return M
