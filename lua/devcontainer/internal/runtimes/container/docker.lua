---@mod devcontainer.internal.runtimes.container.docker Docker container runtime module
---@brief [[
---Provides functions related to docker control:
--- - building
--- - attaching
--- - running
---@brief ]]
local log = require("devcontainer.internal.log")
local common = require("devcontainer.internal.runtimes.helpers.common_container")

local M = common.new()

log.wrap(M)
return M
