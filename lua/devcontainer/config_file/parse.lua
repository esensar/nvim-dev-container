---@mod devcontainer.config_file.parse Devcontainer config file parsing module
---@brief [[
---Provides support for parsing specific devcontainer.json files as well as
---automatic discovery and parsing of nearest file
---Ensures basic configuration required for the plugin to work is present in files
---@brief ]]
local jsonc = require("devcontainer.config_file.jsonc")
local config = require("devcontainer.config")
local u = require("devcontainer.internal.utils")
local log = require("devcontainer.internal.log")
local uv = vim.loop

local M = {}

local function readFileAsync(path, callback)
  uv.fs_open(path, "r", 438, function(err_open, fd)
    if err_open or not fd then
      return callback(err_open, nil)
    end
    uv.fs_fstat(fd, function(err_stat, stat)
      if err_stat or not stat then
        return callback(err_stat, nil)
      end
      uv.fs_read(fd, stat.size, 0, function(err_read, data)
        if err_read then
          return callback(err_read, nil)
        end
        uv.fs_close(fd, function(err_close)
          if err_close then
            return callback(err_close, nil)
          end
          return callback(nil, data)
        end)
      end)
    end)
  end)
end

local function readFileSync(path)
  local fd = assert(uv.fs_open(path, "r", 438))
  local stat = assert(uv.fs_fstat(fd))
  local data = assert(uv.fs_read(fd, stat.size, 0))
  assert(uv.fs_close(fd))
  return data
end

local function invoke_callback(callback, success, data)
  if success then
    callback(nil, data)
  else
    callback(data, nil)
  end
end

local function parse_devcontainer_content(config_file_path, content)
  local parsed_config = vim.tbl_extend("keep", jsonc.parse_jsonc(content), { build = {}, hostRequirements = {} })
  if
    parsed_config.image == nil
    and parsed_config.dockerFile == nil
    and (parsed_config.build.dockerfile == nil)
    and parsed_config.dockerComposeFile == nil
  then
    error("Either image, dockerFile or dockerComposeFile need to be present in the file")
  end
  return vim.tbl_deep_extend("force", parsed_config, { metadata = { file_path = config_file_path } })
end

---Parse specific devcontainer.json file into a Lua table
---Ensures that at least one of "image", "dockerFile" or "dockerComposeFile" keys is present
---@param config_file_path string
---@param callback? function if nil run sync, otherwise run async and pass result to the callback(err, data)
---@return table? result or nil if running async
---@usage `require("devcontainer.config_file.parse").parse_devcontainer_config([[{ "image": "test" }]])`
function M.parse_devcontainer_config(config_file_path, callback)
  vim.validate({
    config_file_path = { config_file_path, "string" },
    callback = { callback, { "function", "nil" } },
  })
  if callback then
    readFileAsync(
      config_file_path,
      vim.schedule_wrap(function(err, content)
        if err then
          callback(err, nil)
        else
          local success, data = pcall(parse_devcontainer_content, config_file_path, content)
          invoke_callback(callback, success, data)
        end
      end)
    )
    return nil
  end
  local content = readFileSync(config_file_path)
  return parse_devcontainer_content(config_file_path, content)
end

local function find_nearest_devcontainer_file_async(callback)
  local directory = config.config_search_start()
  local last_ino = nil

  local function recur_dir(err, data)
    if err or data == nil or data.ino == last_ino or config.disable_recursive_config_search then
      callback("No devcontainer files found!", nil)
    end
    last_ino = data.ino
    local files = { ".devcontainer.json", ".devcontainer" .. u.path_sep .. "devcontainer.json" }
    local index = 1
    local function file_callback(_, file_data)
      if file_data then
        local path = directory .. u.path_sep .. files[index]
        callback(nil, path)
      else
        index = index + 1
        if index > #files then
          directory = directory .. u.path_sep .. ".."
          uv.fs_stat(directory, recur_dir)
        else
          local path = directory .. u.path_sep .. files[index]
          uv.fs_stat(path, file_callback)
        end
      end
    end

    local path = directory .. u.path_sep .. files[index]
    uv.fs_stat(path, file_callback)
  end

  uv.fs_stat(directory, recur_dir)
end

local function find_nearest_devcontainer_file()
  local directory = config.config_search_start()
  local last_ino = nil

  local function recur_dir(err, data)
    if err or data == nil or data.ino == last_ino or config.disable_recursive_config_search then
      error("No devcontainer files found!")
    end
    last_ino = data.ino
    local files = { ".devcontainer.json", ".devcontainer" .. u.path_sep .. "devcontainer.json" }

    for _, file in pairs(files) do
      local path = directory .. u.path_sep .. file
      local success, stat_data = pcall(uv.fs_stat, path)
      if success and stat_data ~= nil then
        return path
      end
    end
    directory = directory .. u.path_sep .. ".."
    local dir_exists, directory_info = pcall(uv.fs_stat, directory)
    local dir_err = nil
    local dir_data = nil
    if dir_exists then
      dir_data = directory_info
    else
      dir_err = directory_info or "Not found"
    end
    return recur_dir(dir_err, dir_data)
  end

  local dir_exists, directory_info = pcall(uv.fs_stat, directory)
  local dir_err = nil
  local dir_data = nil
  if dir_exists then
    dir_data = directory_info
  else
    dir_err = directory_info
  end
  return recur_dir(dir_err, dir_data)
end

---Parse nearest devcontainer.json file into a Lua table
---Prefers .devcontainer.json over .devcontainer/devcontainer.json
---Looks in config.config_search_start first and then moves up all the way until root
---Fails if no devcontainer.json files were found, or if the first one found is invalid
---@param callback? function if nil run sync, otherwise run async and pass result to the callback(err, data)
---@return table? result or nil if running async
---@usage `require("devcontainer.config_file.parse").parse_nearest_devcontainer_config()`
function M.parse_nearest_devcontainer_config(callback)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })
  if callback then
    return find_nearest_devcontainer_file_async(function(err, data)
      if err then
        callback(err, nil)
      else
        M.parse_devcontainer_config(data, callback)
      end
    end)
  else
    return M.parse_devcontainer_config(find_nearest_devcontainer_file(), nil)
  end
end

local function sub_variables(config_string)
  local local_workspace_folder = config.workspace_folder_provider()
  local parts = vim.split(local_workspace_folder, u.path_sep)
  local local_workspace_folder_basename = parts[#parts]
  config_string = string.gsub(config_string, "${localWorkspaceFolder}", local_workspace_folder)
  config_string = string.gsub(config_string, "${localWorkspaceFolderBasename}", local_workspace_folder_basename)
  config_string = string.gsub(
    config_string,
    "${localEnv:[a-zA-Z_]+[a-zA-Z0-9_]*:?[a-zA-Z_]*[a-zA-Z0-9_]*}",
    function(part)
      part = string.gsub(part, "${localEnv:", "")
      part = string.sub(part, 1, #part - 1)
      part = vim.split(part, ":")
      local default = part[2] or ""
      part = part[1]
      return vim.env[part] or default
    end
  )
  -- TODO: containerWorkspaceFolder support
  return config_string
end

local function sub_container_env(config_string, env_map)
  config_string = string.gsub(
    config_string,
    "${containerEnv:[a-zA-Z_]+[a-zA-Z0-9_]*:?[a-zA-Z_]*[a-zA-Z0-9_]*}",
    function(part)
      part = string.gsub(part, "${containerEnv:", "")
      part = string.sub(part, 1, #part - 1)
      part = vim.split(part, ":")
      local default = part[2] or ""
      part = part[1]
      return env_map[part] or default
    end
  )
  return config_string
end

local function sub_variables_recursive(config_table)
  if vim.tbl_islist(config_table) then
    for i, v in ipairs(config_table) do
      if type(v) == "table" then
        config_table[i] = vim.tbl_deep_extend("force", config_table[i], sub_variables_recursive(v))
      elseif type(v) == "string" then
        config_table[i] = sub_variables(v)
      end
    end
  elseif type(config_table) == "table" then
    for k, v in pairs(config_table) do
      if type(v) == "table" then
        config_table[k] = vim.tbl_deep_extend("force", config_table[k], sub_variables_recursive(v))
      elseif type(v) == "string" then
        config_table[k] = sub_variables(v)
      end
    end
  end
  return config_table
end

---Fills passed devcontainer config with defaults based on spec
---Expects a proper config file, parsed with functions from this module
---NOTE: This mutates passed config!
---@param config_file table parsed config
---@return table config with filled defaults and absolute paths
function M.fill_defaults(config_file)
  vim.validate({
    config_file = { config_file, "table" },
  })

  local file_path = config_file.metadata.file_path
  local components = vim.split(file_path, u.path_sep)
  table.remove(components, #components)
  local file_dir = table.concat(components, u.path_sep)

  local function to_absolute(relative_path)
    return file_dir .. u.path_sep .. relative_path
  end

  if config_file.build.dockerfile or config_file.dockerFile then
    config_file.build.dockerfile = config_file.build.dockerfile or config_file.dockerFile
    config_file.dockerFile = config_file.dockerFile or config_file.build.dockerfile
    config_file.context = config_file.context or config_file.build.context or "."
    config_file.build.context = config_file.build.context or config_file.context or "."

    config_file.build.dockerfile = to_absolute(config_file.build.dockerfile)
    config_file.dockerFile = to_absolute(config_file.dockerFile)
    config_file.context = to_absolute(config_file.context)
    config_file.build.context = to_absolute(config_file.build.context)

    config_file.build.args = config_file.build.args or {}
    config_file.build.mounts = config_file.build.mounts or {}
    config_file.runArgs = config_file.runArgs or {}
    if config_file.overrideCommand == nil then
      config_file.overrideCommand = true
    end
  end

  if config_file.dockerComposeFile then
    if type(config_file.dockerComposeFile) == "table" then
      for i, val in ipairs(config_file.dockerComposeFile) do
        config_file.dockerComposeFile[i] = to_absolute(val)
      end
    elseif type(config_file.dockerComposeFile) == "string" then
      config_file.dockerComposeFile = to_absolute(config_file.dockerComposeFile)
    end
    config_file.workspaceFolder = config_file.workspaceFolder or "/"
    config_file.overrideCommand = config_file.overrideCommand or false
  end

  config_file.forwardPorts = config_file.forwardPorts or {}
  config_file.remoteEnv = config_file.remoteEnv or {}

  return sub_variables_recursive(config_file)
end

---Checks if remoteEnv property needs env values to be filled
---This can be used to prevent making needless calls to the container
---@param remote_env table remoteEnv property of parsed config
---@return boolean true if environment is required to fill out remoteEnv
function M.remote_env_needs_fill(remote_env)
  vim.validate({
    remote_env = { remote_env, "table" },
  })

  for _, v in pairs(remote_env) do
    if string.match(v, "${containerEnv:[a-zA-Z_]+[a-zA-Z0-9_]*:?[a-zA-Z_]*[a-zA-Z0-9_]*}") then
      return true
    end
  end
  return false
end

---Fill passed remoteEnv table with values from env_map
---Env_map should usually be generated from environment of the running container
---NOTE: This mutates passed remoteEnv!
---@param remote_env table remoteEnv property of parsed config
---@param env_map table map of container environment
---@return table remoteEnv with replaced containerEnv values
function M.fill_remote_env(remote_env, env_map)
  vim.validate({
    remote_env = { remote_env, "table" },
    env_map = { env_map, "table" },
  })

  for k, v in pairs(remote_env) do
    remote_env[k] = sub_container_env(v, env_map)
  end
  return remote_env
end

---Return path of the nearest devcontainer.json file
---Prefers .devcontainer.json over .devcontainer/devcontainer.json
---Looks in config.config_search_start first and then moves up all the way until root
---Fails if no devcontainer.json files were found, or if the first one found is invalid
---@param callback? function if nil run sync, otherwise run async and pass result to the callback(err, data)
---@return string? result or nil if running async
---@usage `require("devcontainer.config_file.parse").find_nearest_devcontainer_config()`
function M.find_nearest_devcontainer_config(callback)
  vim.validate({
    callback = { callback, { "function", "nil" } },
  })
  if callback then
    find_nearest_devcontainer_file_async()
    return nil
  else
    return find_nearest_devcontainer_file()
  end
end

log.wrap(M)
return M
