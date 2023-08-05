---@mod devcontainer.internal.container_executor Utilities related to executing commands in containers
---@brief [[
---Provides high level commands related to executing commands on container
---@brief ]]

local M = {}

local log = require("devcontainer.internal.log")
local v = require("devcontainer.internal.validation")
local runtimes = require("devcontainer.internal.runtimes")

---@class RunAllOpts
---@field on_success function() success callback
---@field on_step function(step) step success callback
---@field on_fail function() failure callback

---Run all passed commands sequentially on the container
---If any of them fail, on_fail callback will be called immediately
---@param container_id string of container to run commands on
---@param commands table[string] commands to run on the container
---@param opts? RunAllOpts Additional options including callbacks
function M.run_all_seq(container_id, commands, opts)
  vim.validate({
    container_id = { container_id, "string" },
    commands = { commands, "table" },
    opts = { opts, { "table", "nil" } },
  })
  opts = opts or {}
  v.validate_callbacks(opts)
  v.validate_opts(opts, { on_step = "function" })
  opts.on_success = opts.on_success
    or function()
      vim.notify("Successfully ran commands (" .. vim.inspect(commands) .. ") on container (" .. container_id .. ")")
    end
  opts.on_fail = opts.on_fail
    or function()
      vim.notify(
        "Running commands (" .. vim.inspect(commands) .. ") on (" .. container_id .. ") has failed!",
        vim.log.levels.ERROR
      )
    end
  opts.on_step = opts.on_step
    or function(step)
      vim.notify("Successfully ran command (" .. table.concat(step, " ") .. ") on (" .. container_id .. ")!")
    end

  -- Index starts at 1 - first iteration is fake
  local index = 0
  local on_success_step
  on_success_step = function()
    if index > 0 then
      opts.on_step(commands[index])
    end
    if index == #commands then
      opts.on_success()
    else
      index = index + 1
      runtimes.container.exec(container_id, {
        command = commands[index],
        on_success = on_success_step,
        on_fail = opts.on_fail,
      })
    end
  end
  -- Start looping
  on_success_step()
end

log.wrap(M)
return M
