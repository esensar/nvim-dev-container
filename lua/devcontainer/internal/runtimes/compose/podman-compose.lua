---@mod devcontainer.internal.runtimes.compose.podman-compose Podman-compose compose runtime module
---@brief [[
---Provides functions related to podman-compose control
---@brief ]]
local log = require("devcontainer.internal.log")
local common = require("devcontainer.internal.runtimes.helpers.common_compose")

local M = common.new({ runtime = "podman-compose" })

log.wrap(M)
return M
