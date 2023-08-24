---@mod devcontainer.internal.runtimes.container.podman Podman container runtime module
---@brief [[
---Provides functions related to podman control:
--- - building
--- - attaching
--- - running
---@brief ]]
local log = require("devcontainer.internal.log")
local common = require("devcontainer.internal.runtimes.helpers.common_container")

local M = common.new()

---Run passed image using podman run
---@param image string image to run
---@param opts ContainerRunOpts Additional options including callbacks
function M.run(image, opts)
  local args = opts.args
  if args then
    local next = false
    for k, v in ipairs(args) do
      if next then
        next = false
        local mount = v
        if not string.match(mount, "z=true") then
          mount = mount .. ",z=true"
          args[k] = mount
        end
      end
      if v == "--mount" then
        next = true
      end
    end
  end
  return common.run(image, opts)
end

log.wrap(M)
return M
