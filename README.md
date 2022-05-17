# devcontainer

Goal of this plugin is to provide functionality similar to VSCode's [remote container development](https://code.visualstudio.com/docs/remote/containers) plugin and other functionality that enables development in docker container. This plugin is inspired by [jamestthompson3/nvim-remote-containers](https://github.com/jamestthompson3/nvim-remote-containers), but aims to enable having neovim embedded in docker container.

**WORK IN PROGRESS**

## Requirements

- [NeoVim](https://neovim.io) version 0.7.0+ (previous versions may be supported, but are not tested)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with included `jsonc` parser (or manually installed jsonc parser)

## Installation

Install using favourite plugin manager.

e.g. Using [Packer.nvim](https://github.com/wbthomason/packer.nvim)

```
use {
  'esensar/nvim-dev-container',
  requires = { 'nvim-treesitter/nvim-treesitter' }
}
```

or assuming `nvim-treesitter` is already available:

```
use { 'esensar/nvim-dev-container' }
```

## Usage

**TODO**

### Commands

**TODO**

### Keymaps

**TODO**

### Functions

**TODO**

## Contributing

Check out [contributing guidelines](CONTRIBUTING.md).

## License

[MIT](LICENSE)
