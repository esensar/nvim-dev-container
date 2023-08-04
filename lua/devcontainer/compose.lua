---@mod devcontainer.compose Compose module
---@brief [[
---Provides functions related to compose control
---@brief ]]
local v = require("devcontainer.internal.validation")
local log = require("devcontainer.internal.log")
local runtimes = require("devcontainer.internal.runtimes")

local M = {}

---@class ComposeUpOpts
---@field args? table list of additional arguments to up command
---@field on_success function() success callback
---@field on_fail function() failure callback

---Run docker-compose up with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts ComposeUpOpts Additional options including callbacks
---@usage `require("devcontainer.compose").up("docker-compose.yml")`
function M.up(compose_file, opts)
  vim.validate({
    compose_file = { compose_file, { "string", "table" } },
  })
  opts = opts or {}
  v.validate_callbacks(opts)
  opts.on_success = opts.on_success
    or function()
      vim.notify("Successfully started services from " .. compose_file)
    end
  opts.on_fail = opts.on_fail
    or function()
      vim.notify("Starting services from " .. compose_file .. " failed!", vim.log.levels.ERROR)
    end

  runtimes.compose.up(compose_file, opts)
end

---@class ComposeDownOpts
---@field on_success function() success callback
---@field on_fail function() failure callback

---Run docker-compose down with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts ComposeDownOpts Additional options including callbacks
---@usage `require("devcontainer.compose").down("docker-compose.yml")`
function M.down(compose_file, opts)
  vim.validate({
    compose_file = { compose_file, { "string", "table" } },
  })
  opts = opts or {}
  v.validate_callbacks(opts)
  opts.on_success = opts.on_success
    or function()
      vim.notify("Successfully stopped services from " .. compose_file)
    end
  opts.on_fail = opts.on_fail
    or function()
      vim.notify("Stopping services from " .. compose_file .. " failed!", vim.log.levels.ERROR)
    end

  runtimes.compose.down(compose_file, opts)
end

---@class ComposeGetContainerIdOpts
---@field on_success? function(container_id) success callback
---@field on_fail? function() failure callback

---Run docker-compose ps with passed file and service to get its container_id
---@param compose_file string|table path to docker-compose.yml file or files
---@param service string service name
---@param opts ComposeGetContainerIdOpts Additional options including callbacks
---@usage [[
---require("devcontainer.compose").get_container_id(
---  "docker-compose.yml",
---  { on_success = function(container_id) end }
---)
---@usage ]]
function M.get_container_id(compose_file, service, opts)
  vim.validate({
    compose_file = { compose_file, { "string", "table" } },
    service = { service, "string" },
  })
  opts = opts or {}
  v.validate_callbacks(opts)
  opts.on_success = opts.on_success
    or function(container_id)
      vim.notify("Container id of service " .. service .. " from " .. compose_file .. " is " .. container_id)
    end
  opts.on_fail = opts.on_fail
    or function()
      vim.notify(
        "Fetching container id for " .. service .. " from " .. compose_file .. " failed!",
        vim.log.levels.ERROR
      )
    end

  runtimes.compose.get_container_id(compose_file, service, opts)
end

log.wrap(M)
return M
