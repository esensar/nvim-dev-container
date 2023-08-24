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

---Run compose down with passed file - not supported with devcontainer
---@param _ string|table path to docker-compose.yml file or files
---@param opts ComposeDownOpts Additional options including callbacks
function M.down(_, opts)
  vim.notify("Compose down with devcontainer CLI is not supported")
  opts.on_fail()
end

---Run compose ps with passed file and service to get its container_id
---@param opts ComposeGetContainerIdOpts Additional options including callbacks
function M.get_container_id(_, _, opts)
  vim.notify("Getting container ID with devcontainer CLI is not supported")
  opts.on_fail()
end

log.wrap(M)
return M
