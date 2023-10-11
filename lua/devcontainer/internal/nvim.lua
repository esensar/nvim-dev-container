---@mod devcontainer.internal.nvim Neovim in container related commands
---@brief [[
---Provides high level commands related to using neovim inside container
---@brief ]]

local M = {}

local log = require("devcontainer.internal.log")
local v = require("devcontainer.internal.validation")
local u = require("devcontainer.internal.utils")
local status = require("devcontainer.status")
local config = require("devcontainer.config")
local container_executor = require("devcontainer.internal.container_executor")
local container_runtime = require("devcontainer.container")

---@class AddNeovimOpts
---@field on_success? function() success callback
---@field on_step? function(step) step success callback
---@field on_fail? function() failure callback
---@field version? string version of neovim to use - current version by default

---Adds neovim to passed container using exec
---@param container_id string id of container to add neovim to
---@param opts? AddNeovimOpts Additional options including callbacks
function M.add_neovim(container_id, opts)
  vim.validate({
    container_id = { container_id, "string" },
    opts = { opts, { "table", "nil" } },
  })
  opts = opts or {}
  v.validate_callbacks(opts)
  opts.on_success = opts.on_success
    or function()
      vim.notify("Successfully added neovim to container (" .. container_id .. ")")
    end
  opts.on_fail = opts.on_fail
    or function()
      vim.notify("Adding neovim to container (" .. container_id .. ") has failed!", vim.log.levels.ERROR)
    end
  opts.on_step = opts.on_step
    or function(step)
      vim.notify("Executed " .. table.concat(step, " ") .. " on container (" .. container_id .. ")!")
    end

  local function run_commands(commands)
    local build_status = {
      build_title = "Adding neovim to: " .. container_id,
      progress = 0,
      step_count = #commands,
      current_step = 0,
      image_id = nil,
      source_dockerfile = nil,
      build_command = "nvim.add_neovim",
      commands_run = {},
      running = true,
    }
    local current_step = 0
    status.add_build(build_status)

    container_executor.run_all_seq(container_id, commands, {
      on_success = function()
        build_status.running = false
        vim.api.nvim_exec_autocmds("User", { pattern = "DevcontainerBuildProgress", modeline = false })
        if config.cache_images then
          local tag = u.get_image_cache_tag()
          container_runtime.container_commit(container_id, {
            tag = tag,
          })
        end
        opts.on_success()
      end,
      on_step = function(step)
        current_step = current_step + 1
        build_status.current_step = current_step
        build_status.progress = math.floor((build_status.current_step / build_status.step_count) * 100)
        vim.api.nvim_exec_autocmds("User", { pattern = "DevcontainerBuildProgress", modeline = false })
        opts.on_step(step)
      end,
      on_fail = opts.on_fail,
    })
  end

  local version_string = opts.version
  if not version_string then
    local version = vim.version()
    version_string = "v" .. version.major .. "." .. version.minor .. "." .. version.patch
  end
  container_runtime.exec(container_id, {
    command = { "compgen", "-c" },
    on_success = function(result)
      local available_commands = {}
      if result then
        local result_lines = vim.split(result, "\n")
        for _, line in ipairs(result_lines) do
          if v then
            table.insert(available_commands, line)
          end
        end
      end
      local commands = config.nvim_installation_commands_provider(available_commands, version_string)
      run_commands(commands)
    end,
    on_fail = function()
      local commands = config.nvim_installation_commands_provider({}, version_string)
      run_commands(commands)
    end,
  })
end

log.wrap(M)
return M
