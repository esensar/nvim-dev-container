---@mod devcontainer.internal.runtimes.helpers.common_compose Common commands that should work with compose runtimes
---@brief [[
---Provides functions related to compose control
---@brief ]]
local exe = require("devcontainer.internal.executor")
local log = require("devcontainer.internal.log")
local config = require("devcontainer.config")
local utils = require("devcontainer.internal.utils")

local M = {}

---Runs compose command with passed arguments
---@param args string[]
---@param opts? RunCommandOpts
---@param onexit function(code, signal)
local function run_current_compose_command(self, args, opts, onexit)
  local runtime = tostring(self.runtime) or config.compose_command
  exe.ensure_executable(runtime)

  opts = opts or {}
  exe.run_command(
    runtime,
    vim.tbl_extend("force", opts, {
      args = args,
      stderr = vim.schedule_wrap(function(err, data)
        if data then
          log.fmt_error("%s command (%s): %s", runtime, args, data)
        end
        if opts.stderr then
          opts.stderr(err, data)
        end
      end),
    }),
    onexit
  )
end

---Prepare compose command arguments with file or files
---@param compose_file string|table
local function get_compose_files_command(compose_file)
  local command = nil
  if type(compose_file) == "table" then
    command = {}
    for _, file in ipairs(compose_file) do
      table.insert(command, "-f")
      table.insert(command, file)
    end
  elseif type(compose_file) == "string" then
    command = { "-f", compose_file }
  end
  return command
end

---Run compose up with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts ComposeUpOpts Additional options including callbacks
function M:up(compose_file, opts)
  local command = get_compose_files_command(compose_file)
  vim.list_extend(command, { "up", "-d" })
  vim.list_extend(command, opts.args or {})
  run_current_compose_command(self, command, nil, function(code, _)
    if code == 0 then
      opts.on_success()
    else
      opts.on_fail()
    end
  end)
end

---Run compose down with passed file
---@param compose_file string|table path to docker-compose.yml file or files
---@param opts ComposeDownOpts Additional options including callbacks
function M:down(compose_file, opts)
  local command = get_compose_files_command(compose_file)
  vim.list_extend(command, { "down" })
  run_current_compose_command(self, command, nil, function(code, _)
    if code == 0 then
      opts.on_success()
    else
      opts.on_fail()
    end
  end)
end

---Run compose ps with passed file and service to get its container_id
---@param compose_file string|table path to docker-compose.yml file or files
---@param service string service name
---@param opts ComposeGetContainerIdOpts Additional options including callbacks
function M:get_container_id(compose_file, service, opts)
  local command = get_compose_files_command(compose_file)
  vim.list_extend(command, { "ps", "-q", service })
  local container_id = nil
  run_current_compose_command(self, command, {
    stdout = function(_, data)
      if data then
        container_id = vim.split(data, "\n")[1]
      end
    end,
  }, function(code, _)
    if code == 0 then
      opts.on_success(container_id)
    else
      opts.on_fail()
    end
  end)
end

M = utils.add_constructor(M)
log.wrap(M)
return M
