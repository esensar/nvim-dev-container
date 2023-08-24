---@mod devcontainer.internal.runtimes.compose.docker-compose Docker-compose compose runtime module
---@brief [[
---Provides functions related to docker-compose control
---@brief ]]
local log = require("devcontainer.internal.log")
local common = require("devcontainer.internal.runtimes.helpers.common_compose")

local M = common.new()

log.wrap(M)
return M
