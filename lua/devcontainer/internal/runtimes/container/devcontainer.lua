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
local status = require("devcontainer.status")

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
      stdout = vim.schedule_wrap(function(err, data)
        if opts.stdout then
          opts.stdout(err, data)
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
  local container_id = nil
  local workspace_dir = nil
  local command = { "--workspace-folder", config.workspace_folder_provider(), "up" }
  run_with_current_runtime(command, {
    stdout = function(_, data)
      if data then
        local decoded = vim.json.decode(data)
        container_id = decoded["containerId"]
        workspace_dir = decoded["remoteWorkspaceFolder"]
      end
    end,
  }, function(code, _)
    if code == 0 then
      status.add_container({
        image_id = "devcontainer-custom",
        container_id = container_id,
        workspace_dir = workspace_dir,
        autoremove = opts.autoremove,
      })
      opts.on_success(container_id)
    else
      opts.on_fail()
    end
  end)
end

log.wrap(M)
return M
