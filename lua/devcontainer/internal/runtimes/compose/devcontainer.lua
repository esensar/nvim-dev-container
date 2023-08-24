---@mod devcontainer.internal.runtimes.compose.devcontainer Devcontainer CLI compose runtime module
---@brief [[
---Provides functions related to compose control
---@brief ]]
local devcontainer_cli = require("devcontainer.internal.runtimes.container.devcontainer")
local log = require("devcontainer.internal.log")

local M = {}

---Run compose up with passed file
---@param _ string|table path to docker-compose.yml file or files - ignored
---@param opts ComposeUpOpts Additional options including callbacks
function M.up(_, opts)
  devcontainer_cli.run("", { on_success = opts.on_success, on_fail = opts.on_fail })
end

log.wrap(M)
return M
