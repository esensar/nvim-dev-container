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
setmetatable(M, { __index = common })

log.wrap(M)
return M
