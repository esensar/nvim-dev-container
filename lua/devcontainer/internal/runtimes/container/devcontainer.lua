---@mod devcontainer.internal.runtimes.container.devcontainer Devcontainer CLI container runtime module
---@brief [[
---Provides functions related to devcontainer control:
--- - building
--- - attaching
--- - running
---@brief ]]
local log = require("devcontainer.internal.log")
local exe = require("devcontainer.internal.executor")
local config = require("devcontainer.config")

local M = {}

---Runs command with passed arguments
---@param args string[]
---@param opts? RunCommandOpts
---@param onexit function(code, signal)
local function run_with_current_runtime(args, opts, onexit)
  exe.ensure_executable("devcontainer")

  opts = opts or {}
  exe.run_command(
    "devcontainer",
    vim.tbl_extend("force", opts, {
      args = args,
      stderr = vim.schedule_wrap(function(err, data)
        if data then
          log.fmt_error("devcontainer command (%s): %s", args, data)
        end
        if opts.stderr then
          opts.stderr(err, data)
        end
      end),
    }),
    onexit
  )
end

---Build image for passed workspace
---@param _ string Path to Dockerfile to build
---@param path string Path to the workspace
---@param opts ContainerBuildOpts Additional options including callbacks and tag
function M:build(_, path, opts)
  local _ = self
  local command = { "--workspace-folder", path, "build" }
  run_with_current_runtime(command, {}, function(code, _)
    if code == 0 then
      opts.on_success("")
    else
      opts.on_fail()
    end
  end)
end

---Run passed image using devcontainer CLI
---@param _ string image to run - ignored - using workspace folder
---@param opts ContainerRunOpts Additional options including callbacks
function M:run(_, opts)
  local _ = self
  local command = { "--workspace-folder", config.workspace_folder_provider(), "up" }
  run_with_current_runtime(command, {}, function(code, _)
    if code == 0 then
      opts.on_success("")
    else
      opts.on_fail()
    end
  end)
end

---Run command on a container using devcontainer cli
---@param _ string container to exec on - ignored - using workspace folder
---@param opts ContainerExecOpts Additional options including callbacks
function M:exec(_, opts)
  local _ = self
  local command = { "--workspace-folder", config.workspace_folder_provider(), "exec" }
  vim.list_extend(command, opts.args or {})
  local run_opts = nil
  local captured = nil
  if opts.capture_output then
    run_opts = {
      stdout = function(_, data)
        if data then
          captured = data
        end
      end,
    }
  end
  run_with_current_runtime(command, run_opts, function(code, _)
    if code == 0 then
      if opts.capture_output then
        opts.on_success(captured)
      else
        opts.on_success(nil)
      end
    else
      opts.on_fail()
    end
  end)
end

log.wrap(M)
return M
