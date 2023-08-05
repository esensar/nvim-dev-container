---@mod devcontainer.status Devcontainer plugin config module
---@brief [[
---Provides access to current status and is used internally to update it
---Don't change directly!
---Can be used for read-only access
---@brief ]]

local M = {}

---@class DevcontainerImageStatus
---@field image_id string id of the image
---@field source_dockerfile string path to the file used to build the image
---@field neovim_added boolean true if add_neovim flag was used to add neovim to the image
---@field tmp_dockerfile? string path to temporary dockerfile if add neovim was used
--
---@class DevcontainerImageQuery
---@field image_id? string id of the image
---@field source_dockerfile? string path to the file used to build the image
---@field neovim_added? boolean true if add_neovim flag was used to add neovim to the image
---@field tmp_dockerfile? string path to temporary dockerfile if add neovim was used

---@class DevcontainerContainerStatus
---@field container_id string id of the container
---@field image_id string id of the used image
---@field autoremove boolean true if this container was started with autoremove flag
--
---@class DevcontainerContainerQuery
---@field container_id? string id of the container
---@field image_id? string id of the used image

---@class DevcontainerComposeStatus
---@field file string path to compose file

---@class DevcontainerBuildStatus
---@field progress number 0-100 percentage
---@field step_count number number of steps to build
---@field current_step number current step
---@field image_id? string id of the built image
---@field source_dockerfile string path to the file used to build the image
---@field build_command string command used to build the image
---@field commands_run string list of commands run by build (layers)
---@field running boolean true if still running

---@class DevcontainerStatus
---@field images_built table[DevcontainerImageStatus]
---@field running_containers table[DevcontainerContainerStatus]
---@field stopped_containers table[DevcontainerContainerStatus]
---@field build_status table[DevcontainerBuildStatus]
---@field compose_services table[DevcontainerComposeStatus]

---@type DevcontainerStatus
local current_status = {
  images_built = {},
  running_containers = {},
  stopped_containers = {},
  build_status = {},
  compose_services = {},
}

---Finds container with requested opts
---@param opts DevcontainerContainerQuery required opts
---@return DevcontainerContainerStatus?
local function get_container(opts)
  local all_containers = {}
  vim.list_extend(all_containers, current_status.running_containers)
  vim.list_extend(all_containers, current_status.stopped_containers)
  if not opts then
    return all_containers[1]
  end
  for _, v in ipairs(all_containers) do
    if opts.image_id and v.image_id == opts.image_id then
      return v
    end
    if opts.container_id and v.container_id == opts.container_id then
      return v
    end
  end
  return nil
end

---Finds image with requested opts
---@param opts DevcontainerImageQuery required opts
---@return DevcontainerImageStatus?
local function get_image(opts)
  if not opts then
    return current_status.images_built[1]
  end
  for _, v in ipairs(current_status.images_built) do
    if opts.image_id and v.image_id == opts.image_id then
      return v
    end
    if opts.source_dockerfile and v.source_dockerfile == opts.source_dockerfile then
      return v
    end
    if opts.neovim_added and opts.tmp_dockerfile and v.tmp_dockerfile == opts.tmp_dockerfile then
      return v
    end
  end
  return nil
end

---Finds build with requested opts
---@param opts DevcontainerBuildStatus required opts
---@return DevcontainerBuildStatus?
local function get_build(opts)
  if not opts then
    return current_status.build_status[#current_status.build_status]
  end
  for _, v in ipairs(current_status.build_status) do
    if opts.image_id and v.image_id == opts.image_id then
      return v
    end
    if opts.source_dockerfile and v.source_dockerfile == opts.source_dockerfile then
      return v
    end
    if opts.running and v.running == opts.running then
      return v
    end
  end
  return nil
end

---@private
---Adds image to the status or replaces if item with same image_id exists
---@param image_status DevcontainerImageStatus
function M.add_image(image_status)
  local existing = get_image({ image_id = image_status.image_id })
  if existing then
    existing.neovim_added = image_status.neovim_added
    existing.source_dockerfile = image_status.source_dockerfile
    existing.tmp_dockerfile = image_status.tmp_dockerfile
  else
    table.insert(current_status.images_built, image_status)
  end
end

---@private
---Removes image from the status
---@param image_id string
function M.remove_image(image_id)
  for i, v in ipairs(current_status.images_built) do
    if v.image_id == image_id then
      table.remove(current_status.images_built, i)
      return
    end
  end
end

---@private
---Adds container to the status or replaces if item with same container_id exists
---@param container_status DevcontainerContainerStatus
function M.add_container(container_status)
  local existing = get_container({ container_id = container_status.container_id })
  if existing then
    existing.autoremove = container_status.autoremove
    M.move_container_to_running(container_status.container_id)
  else
    table.insert(current_status.running_containers, container_status)
  end
end

---@private
---Moves container from running_containers to stopped_containers
---@param container_id string
function M.move_container_to_stopped(container_id)
  for i, v in ipairs(current_status.running_containers) do
    if v.container_id == container_id then
      local container_status = table.remove(current_status.running_containers, i)
      if not container_status.autoremove then
        table.insert(current_status.stopped_containers, container_status)
      end
      return
    end
  end
end

---@private
---Moves container from stopped_containers to running_containers
---@param container_id string
function M.move_container_to_running(container_id)
  for i, v in ipairs(current_status.stopped_containers) do
    if v.container_id == container_id then
      local container_status = table.remove(current_status.stopped_containers, i)
      table.insert(current_status.running_containers, container_status)
      return
    end
  end
end

---@private
---Removes container from the status
---@param container_id string
function M.remove_container(container_id)
  for i, v in ipairs(current_status.stopped_containers) do
    if v.container_id == container_id then
      table.remove(current_status.stopped_containers, i)
      return
    end
  end
  for i, v in ipairs(current_status.running_containers) do
    if v.container_id == container_id then
      table.remove(current_status.running_containers, i)
      return
    end
  end
end

---@private
---Adds compose service to the status
---@param compose_status DevcontainerComposeStatus
function M.add_compose(compose_status)
  M.remove_compose(compose_status.file)
  table.insert(current_status.compose_services, compose_status)
end

---@private
---Removes compoes service from the status
---@param compose_file string
function M.remove_compose(compose_file)
  for i, v in ipairs(current_status.compose_services) do
    if v.file == compose_file then
      table.remove(current_status.compose_services, i)
      return
    end
  end
end

---@private
---Adds build to the status
---@param build_status DevcontainerBuildStatus
function M.add_build(build_status)
  table.insert(current_status.build_status, build_status)
end

---Returns current devcontainer status in a table
---@return DevcontainerStatus
function M.get_status()
  return vim.deepcopy(current_status)
end

---Finds container with requested opts
---Read-only
---@param opts DevcontainerContainerQuery required opts
---@return DevcontainerContainerStatus
function M.find_container(opts)
  return vim.deepcopy(get_container(opts))
end

---Returns latest container
---Read-only
---@return DevcontainerContainerStatus
function M.get_latest_container()
  return vim.deepcopy(current_status.running_containers[#current_status.running_containers])
end

---Finds image with requested opts
---Read-only
---@param opts DevcontainerImageQuery required opts
---@return DevcontainerImageStatus
function M.find_image(opts)
  return vim.deepcopy(get_image(opts))
end

---Finds build status with requested opts
---Read-only
---@param opts DevcontainerBuildStatus required opts
---@return DevcontainerBuildStatus
function M.find_build(opts)
  return vim.deepcopy(get_build(opts))
end

return M
