---@mod devcontainer.internal.runtimes.container.docker Docker container runtime module
---@brief [[
---Provides functions related to docker control:
--- - building
--- - attaching
--- - running
---@brief ]]
local log = require("devcontainer.internal.log")
local common = require("devcontainer.internal.runtimes.helpers.common_container")

local M = {}

---Pull passed image using docker pull
---@param image string image to pull
---@param opts ContainerPullOpts Additional options including callbacks
function M.pull(image, opts)
  common.pull(image, opts)
end

---Build image from passed dockerfile using docker build
---@param file string Path to Dockerfile to build
---@param path string Path to the workspace
---@param opts ContainerBuildOpts Additional options including callbacks and tag
function M.build(file, path, opts)
  common.build(file, path, opts)
end

---Run passed image using docker run
---@param image string image to run
---@param opts ContainerRunOpts Additional options including callbacks
function M.run(image, opts)
  common.run(image, opts)
end

---Run command on a container using docker exec
---@param container_id string container to exec on
---@param opts ContainerExecOpts Additional options including callbacks
function M.exec(container_id, opts)
  common.exec(container_id, opts)
end

---Stop passed containers
---@param containers table[string] ids of containers to stop
---@param opts ContainerStopOpts Additional options including callbacks
function M.container_stop(containers, opts)
  common.container_stop(containers, opts)
end

---Removes passed images
---@param images table[string] ids of images to remove
---@param opts ImageRmOpts Additional options including callbacks
function M.image_rm(images, opts)
  common.image_rm(images, opts)
end

---Removes passed containers
---@param containers table[string] ids of containers to remove
---@param opts ContainerRmOpts Additional options including callbacks
function M.container_rm(containers, opts)
  common.container_rm(containers, opts)
end

log.wrap(M)
return M
