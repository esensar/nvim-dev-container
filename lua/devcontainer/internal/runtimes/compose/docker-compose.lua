---@mod devcontainer.internal.runtimes.compose.docker-compose Docker-compose compose runtime module
---@brief [[
---Provides functions related to docker-compose control
---@brief ]]
local log = require("devcontainer.internal.log")
local common = require("devcontainer.internal.runtimes.helpers.common_compose")

local M = {}

---Run docker-compose up with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts ComposeUpOpts Additional options including callbacks
function M.up(compose_file, opts)
  common.up(compose_file, opts)
end

---Run docker-compose down with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts ComposeDownOpts Additional options including callbacks
function M.down(compose_file, opts)
  common.down(compose_file, opts)
end

---Run docker-compose ps with passed file and service to get its container_id
---@param compose_file string|table path to docker-compose.yml file or files
---@param service string service name
---@param opts ComposeGetContainerIdOpts Additional options including callbacks
function M.get_container_id(compose_file, service, opts)
  common.get_container_id(compose_file, service, opts)
end

log.wrap(M)
return M
