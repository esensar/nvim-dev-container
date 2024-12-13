---@mod devcontainer.container-utils High level container utility functions
---@brief [[
---Provides functions for interacting with containers
---High-level functions
---@brief ]]
local container_runtime = require("devcontainer.container")
local v = require("devcontainer.internal.validation")

local M = {}

---@class ContainerUtilsGetContainerEnvOpts
---@field on_success function(table) success callback with env map parameter
---@field on_fail function() failure callback

---Returns env variables from passed container in success callback
---Env variables are retrieved using printenv
---@param container_id string
---@param opts? ContainerUtilsGetContainerEnvOpts
function M.get_container_env(container_id, opts)
  vim.validate({
    container_id = { container_id, "string" },
  })
  opts = opts or {}
  v.validate_callbacks(opts)

  local on_success = opts.on_success or function(_) end
  local on_fail = opts.on_fail or function() end

  container_runtime.exec(container_id, {
    capture_output = true,
    command = "printenv",
    on_success = function(output)
      local env_map = {}
      local lines = vim.split(output, "\n")
      for _, line in ipairs(lines) do
        local items = vim.split(line, "=")
        local key = table.remove(items, 1)
        local value = table.concat(items, "=")
        env_map[key] = value
      end
      on_success(env_map)
    end,
    on_fail = on_fail,
  })
end

---@class ContainerUtilsGetContainerWorkspaceFolderOpts
---@field on_success function(string) success callback with container workspace folder
---@field on_fail function() failure callback

---Returns workspace folder of passed image in success callback
---Retrieved using image inspect
---@param image_id string
---@param opts? ContainerUtilsGetContainerWorkspaceFolderOpts
function M.get_image_workspace(image_id, opts)
  vim.validate({
    image_id = { image_id, "string" },
  })
  opts = opts or {}
  v.validate_callbacks(opts)

  local on_success = opts.on_success or function(_) end
  local on_fail = opts.on_fail or function() end

  container_runtime.image_inspect(image_id, {
    format = "{{.Config.WorkingDir}}",
    on_success = on_success,
    on_fail = on_fail,
  })
end

return M
