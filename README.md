# devcontainer

Goal of this plugin is to provide functionality similar to VSCode's [remote container development](https://code.visualstudio.com/docs/remote/containers) plugin and other functionality that enables development in docker container. This plugin is inspired by [jamestthompson3/nvim-remote-containers](https://github.com/jamestthompson3/nvim-remote-containers), but aims to enable having neovim embedded in docker container.

**WORK IN PROGRESS**

## Requirements

- [NeoVim](https://neovim.io) version 0.7.0+ (previous versions may be supported, but are not tested - commands and autocommands will definitely fail)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with included `jsonc` parser (or manually installed jsonc parser)

## Installation

Install using favourite plugin manager.

e.g. Using [Packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'esensar/nvim-dev-container',
  requires = { 'nvim-treesitter/nvim-treesitter' }
}
```

or assuming `nvim-treesitter` is already available:

```lua
use { 'esensar/nvim-dev-container' }
```

## Usage

To use the plugin with defaults just call the `setup` function:

```lua
require("devcontainer").setup{}
```

It is possible to override some of the functionality of the plugin with options passed into `setup`. Everything passed to `setup` is optional. Following block represents default values:

```lua
require("devcontainer").setup {
  config_search_start = function()
    -- By default this function uses vim.loop.cwd()
    -- This is used to find a starting point for .devcontainer.json file search
    -- Since by default, it is searched for recursively
    -- That behavior can also be disabled
  end,
  workspace_folder_provider = function()
    -- By default this function uses first workspace folder for integrated lsp if available and vim.loop.cwd() as a fallback
    -- This is used to replace `${localWorkspaceFolder}` in devcontainer.json
    -- Also used for creating default .devcontainer.json file
  end,
  terminal_handler = function(command)
    -- By default this function creates a terminal in a new tab using :terminal command
    -- It also removes statusline when that tab is active, to prevent double statusline
    -- It can be overridden to provide custom terminal handling
  end,
  nvim_dockerfile_template = function(base_image)
    -- Takes base_image and returns string, which should be used as a Dockerfile
    -- This is used when adding neovim to existing images
    -- Check out default implementation in lua/devcontainer/config.lua
    -- It installs neovim version based on current version
  end,
  devcontainer_json_template = function()
    -- Returns table - list of lines to set when creating new devcontainer.json files
    -- As a template
    -- Used only when using functions from commands module or created commands
  end,
  -- Can be set to false to prevent generating default commands
  -- Default commands are listed below
  generate_commands = true,
  -- By default no autocommands are generated
  -- This option can be used to configure automatic starting and cleaning of containers
  autocommands = {
    -- can be set to true to automatically start containers when devcontainer.json is available
    init = false,
    -- can be set to true to automatically remove any started containers and any built images when exiting vim
    clean = false,
    -- can be set to true to automatically restart containers when devcontainer.json file is updated
    update = false,
  },
  -- can be changed to increase or decrease logging from library
  log_level = "info",
  -- can be set to true to disable recursive search
  -- in that case only .devcontainer.json and .devcontainer/devcontainer.json files will be checked relative
  -- to the directory provided by config_search_start
  disable_recursive_config_search = false,
  -- By default all mounts are added (config, data and state)
  -- This can be changed to disable mounts or change their options
  -- This can be useful to mount local configuration
  -- And any other mounts when attaching to containers with this plugin
  attach_mounts = {
    -- Can be set to true to always mount items defined below
    -- And not only when directly attaching
    -- This can be useful if executing attach command separately
    always = false,
    neovim_config = {
      -- enables mounting local config to /root/.config/nvim in container
      enabled = false,
      -- makes mount readonly in container
      options = { "readonly" }
    },
    neovim_data = {
      -- enables mounting local data to /root/.local/share/nvim in container
      enabled = false,
      -- no options by default
      options = {}
    },
    -- Only useful if using neovim 0.8.0+
    neovim_state = {
      -- enables mounting local state to /root/.local/state/nvim in container
      enabled = false,
      -- no options by default
      options = {}
    },
    -- This takes a list of mounts (strings) that should always be added whenever attaching to containers
    -- This is passed directly as --mount option to docker command
    -- Or multiple --mount options if there are multiple values
    custom_mounts = {}
  },
  -- This takes a list of mounts (strings) that should always be added to every run container
  -- This is passed directly as --mount option to docker command
  -- Or multiple --mount options if there are multiple values
  always_mount = {}
}
```

Check out [wiki](https://github.com/esensar/nvim-dev-container/wiki) for more information.

### Commands

If not disabled by using `generate_commands = false` in setup, this plugin provides the following commands:

- `DevcontainerBuild` - builds image from nearest devcontainer.json
- `DevcontainerImageRun` - runs image from nearest devcontainer.json
- `DevcontainerBuildAndRun` - builds image from nearest devcontainer.json and then runs it
- `DevcontainerBuildRunAndAttach` - builds image from nearest devcontainer.json (with neovim added), runs it and attaches to neovim in it - currently using `terminal_handler`, but in the future with Neovim 0.8.0 maybe directly ([#30](https://github.com/esensar/nvim-dev-container/issues/30))
- `DevcontainerComposeUp` - run docker-compose up based on devcontainer.json
- `DevcontainerComposeDown` - run docker-compose down based on devcontainer.json
- `DevcontainerComposeRm` - run docker-compose rm based on devcontainer.json
- `DevcontainerStartAuto` - start whatever is defined in devcontainer.json
- `DevcontainerStartAutoAndAttach` - start and attach to whatever is defined in devcontainer.json
- `DevcontainerAttachAuto` - attach to whatever is defined in devcontainer.json
- `DevcontainerStopAuto` - stop whatever was started based on devcontainer.json
- `DevcontainerStopAll` - stop everything started with this plugin (in current session)
- `DevcontainerRemoveAll` - remove everything started with this plugin (in current session)
- `DevcontainerLogs` - open plugin log file
- `DevcontainerOpenNearestConfig` - opens nearest devcontainer.json file if it exists
- `DevcontainerEditNearestConfig` - opens nearest devcontainer.json file if it exists, or creates a new one if it does not

### Functions

Check out [:h devcontainer](doc/devcontainer.txt) for full list of functions.

## Contributing

Check out [contributing guidelines](CONTRIBUTING.md).

## License

[MIT](LICENSE)
