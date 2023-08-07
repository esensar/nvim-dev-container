---@mod devcontainer.internal.runtimes.helpers.common_container Common commands that should work for most runtimes
---@brief [[
---Provides functions related to container control:
--- - building
--- - attaching
--- - running
---@brief ]]
local exe = require("devcontainer.internal.executor")
local config = require("devcontainer.config")
local status = require("devcontainer.status")
local log = require("devcontainer.internal.log")

local M = {}

---Runs command with passed arguments
---@param args string[]
---@param opts? RunCommandOpts
---@param onexit function(code, signal)
local function run_with_current_runtime(args, opts, onexit)
  exe.ensure_executable(config.container_runtime)

  opts = opts or {}
  exe.run_command(
    config.container_runtime,
    vim.tbl_extend("force", opts, {
      args = args,
      stderr = vim.schedule_wrap(function(err, data)
        if data then
          log.fmt_error("%s command (%s): %s", config.container_runtime, args, data)
        end
        if opts.stderr then
          opts.stderr(err, data)
        end
      end),
    }),
    onexit
  )
end

---Pull passed image using
---@param image string image to pull
---@param opts ContainerPullOpts Additional options including callbacks
function M.pull(image, opts)
  run_with_current_runtime({ "pull", image }, nil, function(code, _)
    if code == 0 then
      opts.on_success()
    else
      opts.on_fail()
    end
  end)
end

---Build image from passed dockerfile
---@param file string Path to Dockerfile to build
---@param path string Path to the workspace
---@param opts ContainerBuildOpts Additional options including callbacks and tag
function M.build(file, path, opts)
  local command = { "build", "-f", file, path }
  if opts.tag then
    table.insert(command, "-t")
    table.insert(command, opts.tag)
  end

  local id_temp_file = os.tmpname()
  table.insert(command, "--iidfile")
  table.insert(command, id_temp_file)

  vim.list_extend(command, opts.args or {})

  local build_status = {
    progress = 0,
    step_count = 0,
    current_step = 0,
    image_id = nil,
    source_dockerfile = file,
    build_command = table.concat(vim.list_extend({ config.container_runtime }, command), " "),
    commands_run = {},
    running = true,
  }
  status.add_build(build_status)

  local image_id = nil
  run_with_current_runtime(command, {
    stdout = vim.schedule_wrap(function(_, data)
      if data then
        local lines = vim.split(data, "\n")
        local step_regex = vim.regex("\\cStep [[:digit:]]*/[[:digit:]]* *: .*")
        for _, line in ipairs(lines) do
          ---@diagnostic disable-next-line: need-check-nil
          if step_regex:match_str(line) then
            local step_line = vim.split(line, ":")
            local step_numbers = vim.split(vim.split(step_line[1], " ")[2], "/")
            table.insert(build_status.commands_run, string.sub(step_line[2], 2))
            build_status.current_step = tonumber(step_numbers[1])
            build_status.step_count = tonumber(step_numbers[2])
            build_status.progress = math.floor((build_status.current_step / build_status.step_count) * 100)
            opts.on_progress(vim.deepcopy(build_status))
          end
        end
      end
    end),
  }, function(code, _)
    image_id = vim.fn.readfile(id_temp_file)[1]
    vim.fn.delete(id_temp_file)
    build_status.running = false
    opts.on_progress(vim.deepcopy(build_status))
    if code == 0 then
      status.add_image({
        image_id = image_id,
        source_dockerfile = file,
        neovim_added = false,
      })
      opts.on_success(image_id)
    else
      opts.on_fail()
    end
  end)
end

---Run passed image using
---@param image string image to run
---@param opts ContainerRunOpts Additional options including callbacks
function M.run(image, opts)
  local command = { "run", "-i", "-d" }
  if opts.autoremove ~= false then
    table.insert(command, "--rm")
  end

  vim.list_extend(command, opts.args or {})

  table.insert(command, image)
  if opts.command then
    if type(opts.command) == "string" then
      table.insert(command, opts.command)
    elseif type(opts.command) == "table" then
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.list_extend(command, opts.command)
    end
  end

  local container_id = nil
  run_with_current_runtime(command, {
    stdout = function(_, data)
      if data then
        container_id = vim.split(data, "\n")[1]
      end
    end,
  }, function(code, _)
    if code == 0 then
      status.add_container({
        image_id = image,
        container_id = container_id,
        autoremove = opts.autoremove,
      })
      opts.on_success(container_id)
    else
      opts.on_fail()
    end
  end)
end

---Run command on a container using
---@param container_id string container to exec on
---@param opts ContainerExecOpts Additional options including callbacks
function M.exec(container_id, opts)
  local command = { "exec", "-i" }
  if opts.tty then
    table.insert(command, "-t")
  end

  vim.list_extend(command, opts.args or {})

  table.insert(command, container_id)
  if opts.command then
    if type(opts.command) == "string" then
      table.insert(command, opts.command)
    elseif type(opts.command) == "table" then
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.list_extend(command, opts.command)
    end
  end

  if opts.tty then
    (opts.terminal_handler or config.terminal_handler)(vim.list_extend({ config.container_runtime }, command))
  else
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
end

---Stop passed containers
---@param containers table[string] ids of containers to stop
---@param opts ContainerStopOpts Additional options including callbacks
function M.container_stop(containers, opts)
  local command = { "container", "stop" }

  vim.list_extend(command, containers)
  run_with_current_runtime(command, nil, function(code, _)
    if code == 0 then
      for _, container in ipairs(containers) do
        status.move_container_to_stopped(container)
      end
      opts.on_success()
    else
      opts.on_fail()
    end
  end)
end

---Removes passed images
---@param images table[string] ids of images to remove
---@param opts ImageRmOpts Additional options including callbacks
function M.image_rm(images, opts)
  local command = { "image", "rm" }

  if opts.force then
    table.insert(command, "-f")
  end

  vim.list_extend(command, images)
  run_with_current_runtime(command, nil, function(code, _)
    if code == 0 then
      for _, image in ipairs(images) do
        status.remove_image(image)
      end
      opts.on_success()
    else
      opts.on_fail()
    end
  end)
end

---Removes passed containers
---@param containers table[string] ids of containers to remove
---@param opts ContainerRmOpts Additional options including callbacks
function M.container_rm(containers, opts)
  local command = { "container", "rm" }

  if opts.force then
    table.insert(command, "-f")
  end

  vim.list_extend(command, containers)
  run_with_current_runtime(command, nil, function(code, _)
    if code == 0 then
      for _, container in ipairs(containers) do
        status.remove_container(container)
      end
      opts.on_success()
    else
      opts.on_fail()
    end
  end)
end

---Lists containers
---@param opts ContainerLsOpts Additional options including callbacks
function M.container_ls(opts)
  local command = { "container", "ls", "--format", "{{.ID}}" }

  if opts.all then
    table.insert(command, "-a")
  end

  local containers = {}
  if opts.async ~= false then
    run_with_current_runtime(command, {
      stdout = function(_, data)
        if data then
          local new_containers = vim.split(data, "\n")
          for _, v in ipairs(new_containers) do
            if v then
              table.insert(containers, v)
            end
          end
        end
      end,
    }, function(code, _)
      if code == 0 then
        opts.on_success(containers)
      else
        opts.on_fail()
      end
    end)
  else
    table.insert(command, 1, config.container_runtime)
    local code, result = exe.run_command_sync(command)
    if code == 0 then
      return result
    else
      error("Code: " .. code .. ". Message: " .. result)
    end
  end
end

log.wrap(M)
return M
