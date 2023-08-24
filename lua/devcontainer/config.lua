---@mod devcontainer.config Devcontainer plugin config module
---@brief [[
---Provides current devcontainer plugin configuration
---Don't change directly, use `devcontainer.setup{}` instead
---Can be used for read-only access
---@brief ]]

local M = {}

local function default_terminal_handler(command)
  local laststatus = vim.o.laststatus
  local lastheight = vim.o.cmdheight
  vim.cmd("tabnew")
  local bufnr = vim.api.nvim_get_current_buf()
  vim.o.laststatus = 0
  vim.o.cmdheight = 0
  local au_id = vim.api.nvim_create_augroup("devcontainer.container.terminal", {})
  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = bufnr,
    group = au_id,
    callback = function()
      vim.o.laststatus = 0
      vim.o.cmdheight = 0
    end,
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    group = au_id,
    callback = function()
      vim.o.laststatus = laststatus
      vim.o.cmdheight = lastheight
    end,
  })
  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = bufnr,
    group = au_id,
    callback = function()
      vim.o.laststatus = laststatus
      vim.api.nvim_del_augroup_by_id(au_id)
      vim.o.cmdheight = lastheight
    end,
  })
  vim.fn.termopen(command)
end

local function workspace_folder_provider()
  return vim.lsp.buf.list_workspace_folders()[1] or vim.loop.cwd()
end

local function default_config_search_start()
  return vim.loop.cwd()
end

local function default_devcontainer_json_template()
  return {
    "{",
    [[  "name": "Your Definition Name Here (Community)",]],
    [[// Update the 'image' property with your Docker image name.]],
    [[// "image": "alpine",]],
    [[// Or define build if using Dockerfile.]],
    [[// "build": {]],
    [[//     "dockerfile": "Dockerfile",]],
    [[// [Optional] You can use build args to set options. e.g. 'VARIANT' below affects the image in the Dockerfile]],
    [[//     "args": { "VARIANT: "buster" },]],
    [[// }]],
    [[// Or use docker-compose]],
    [[// Update the 'dockerComposeFile' list if you have more compose files or use different names.]],
    [["dockerComposeFile": "docker-compose.yml",]],
    [[// Use 'forwardPorts' to make a list of ports inside the container available locally.]],
    [[// "forwardPorts": [],]],
    [[// Define mounts.]],
    [[// "mounts": [ "source=${localWorkspaceFolder},target=/workspaces/${localWorkspaceFolderBasename} ]]
      .. [[,type=bind,consistency=delegated" ],]],
    [[// Uncomment when using a ptrace-based debugger like C++, Go, and Rust]],
    [[// "runArgs": [ "--cap-add=SYS_PTRACE", "--security-opt", "seccomp=unconfined" ],]],
    [[}]],
  }
end

---Handles terminal requests (mainly used for attaching to container)
---By default it uses terminal command
---@type function
M.terminal_handler = default_terminal_handler

---Provides docker build path
---By default uses first LSP workplace folder or vim.loop.cwd()
---@type function
M.workspace_folder_provider = workspace_folder_provider

---Provides starting search path for .devcontainer.json
---After this search moves up until root
---By default it uses vim.loop.cwd()
---@type function
M.config_search_start = default_config_search_start

---Flag to disable recursive search for .devcontainer config files
---By default plugin will move up to root looking for .devcontainer files
---This flag can be used to prevent it and only look in M.config_search_start
---@type boolean
M.disable_recursive_config_search = false

---Provides template for creating new .devcontainer.json files
---This function should return a table listing lines of the file
---@type function
M.devcontainer_json_template = default_devcontainer_json_template

---Used to set current container runtime
---By default plugin will try to use "docker" or "podman"
---@type string?
M.container_runtime = nil

---Used to set backup runtime when main runtime does not support a command
---By default plugin will try to use "docker" or "podman"
---@type string?
M.backup_runtime = nil

---Used to set current compose command
---By default plugin will try to use "docker-compose" or "podman-compose"
---@type string?
M.compose_command = nil

---Used to set backup command when main command does not support a command
---By default plugin will try to use "docker-compose" or "podman-compose"
---@type string?
M.backup_compose_command = nil

---@class MountOpts
---@field enabled boolean if true this mount is enabled
---@field options table[string]|nil additional bind options, useful to define { "readonly" }

---@class AttachMountsOpts
---@field neovim_config? MountOpts if true attaches neovim local config to /root/.config/nvim in container
---@field neovim_data? MountOpts if true attaches neovim data to /root/.local/share/nvim in container
---@field neovim_state? MountOpts if true attaches neovim state to /root/.local/state/nvim in container

---Configuration for mounts when using attach command
---NOTE: when attaching in a separate command, it is useful to set
---always to true, since these have to be attached when starting
---Useful to mount neovim configuration into container
---Applicable only to `devcontainer.commands` functions!
---@type AttachMountsOpts
M.attach_mounts = {
  neovim_config = {
    enabled = false,
    options = { "readonly" },
  },
  neovim_data = {
    enabled = false,
    options = {},
  },
  neovim_state = {
    enabled = false,
    options = {},
  },
}

---List of mounts to always add to all containers
---Applicable only to `devcontainer.commands` functions!
---@type table[string]
M.always_mount = {}

---@alias LogLevel
---| '"trace"'
---| '"debug"'
---| '"info"'
---| '"warn"'
---| '"error"'
---| '"fatal"'

---Current log level
---@type LogLevel
M.log_level = "info"

---List of env variables to add to all containers started with this plugin
---Applicable only to `devcontainer.commands` functions!
---NOTE: This does not support "${localEnv:VAR_NAME}" syntax - use vim.env
---@type table[string, string]
M.container_env = {}

---List of env variables to add to all containers when attaching
---Applicable only to `devcontainer.commands` functions!
---NOTE: This supports "${containerEnv:VAR_NAME}" syntax to use variables from container
---@type table[string, string]
M.remote_env = {}

return M
