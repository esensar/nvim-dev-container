---@brief [[
---Internal library for managing and running executables
---@brief ]]
local uv = vim.loop
local log = require("devcontainer.internal.log")

local M = {}

---Checks if passed command is executable - fails if not
---@param command string
---@return boolean true if executable, false otherwise
function M.is_executable(command)
  if string.match(command, " ") then
    vim.fn.system(command)
    return vim.v.shell_error == 0
  end
  if vim.fn.has("win32") == 1 then
    command = command .. ".exe"
  end
  return vim.fn.executable(command) == 1
end

---Ensures that passed command is executable - fails if not executable
---@param command string
---@usage `require("devcontainer.internal.executor").ensure_executable("docker")`
function M.ensure_executable(command)
  if not M.is_executable(command) then
    error(command .. " is not executable. Ensure it is properly installed and available on PATH")
  end
end

local function handle_close(handle)
  if not uv.is_closing(handle) then
    uv.close(handle)
  end
end

---@class RunCommandOpts
---@field stdout? function
---@field stderr? function
---@field args? string[]
---@field uv? table

---Runs passed command and passes arguments to vim.loop.spawn
---Passes all stdout and stderr data to opts.handler.stdout and opts.handler.stderr
---@param command string command to run
---@param opts RunCommandOpts contains stdio handlers as well as optionally options for vim.loop
---@param onexit? function function(code, signal)
---@see vim.loop opts.uv are passed to vim.loop.spawn
---@see https://github.com/luvit/luv/blob/master/docs.md
---@usage `require("devcontainer.internal.executor").run_command("docker", {}, function() end)`
function M.run_command(command, opts, onexit)
  --TODO: test coverage
  local uv_opts = opts.uv or {}

  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local handle, pid
  handle, pid = uv.spawn(
    command,
    vim.tbl_extend("force", uv_opts, {
      stdio = { nil, stdout, stderr },
      args = opts.args,
    }),
    vim.schedule_wrap(function(code, signal)
      handle_close(stdout)
      handle_close(stderr)
      handle_close(handle)

      if code > 0 then
        vim.notify(
          "Process (pid: "
            .. pid
            .. ") `"
            .. command
            .. " "
            .. table.concat(opts.args, " ")
            .. "` exited with code "
            .. code
            .. " - signal "
            .. signal,
          vim.log.levels.ERROR
        )
      end

      if type(onexit) == "function" then
        onexit(code, signal)
      end
    end)
  )
  if stdout then
    uv.read_start(stdout, opts.stdout or function() end)
  end
  if stderr then
    uv.read_start(stderr, opts.stderr or function() end)
  end
end

---@param command string|table command to run
---@return integer status,string output status code (0 = success) and stdout of the command
function M.run_command_sync(command)
  return vim.v.shell_error, vim.fn.system(command)
end

log.wrap(M)
return M
