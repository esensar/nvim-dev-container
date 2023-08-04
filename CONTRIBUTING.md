# Contributing to nvim-dev-container

First of all, thanks for taking the time to contribute to the project!

Following is a basic set of guidelines for contributing to this repository and instructions to make it as easy as possible.

> Parts of this guidelines are taken from https://github.com/atom/atom/blob/master/CONTRIBUTING.md

If you do not have an account registered and do not want to register one, you can use mailing lists to report bugs, discuss the project and send patches:
 - [discussions mailing list](https://lists.sr.ht/~esensar/nvim-dev-container-discuss)
 - [development mailing list](https://lists.sr.ht/~esensar/nvim-dev-container-devel)

#### Table of contents

- [Asking questions](#asking-questions)
- [Styleguides](#styleguides)
  - [Commit message](#commit-messages)
  - [Lint](#lint)
- [Additional info](#additional-info)

## Reporting bugs

Follow the issue template when reporting a new bug. Also try to provide log which can be found with `DevcontainerLogs` command or with `require("devcontainer.commands").open_logs()` function. Export env variable `NVIM_DEVCONTAINER_DEBUG=1` to produce more logs (e.g. start neovim with `NVIM_DEVCONTAINER_DEBUG=1 nvim`).

## Styleguides

### Commit messages
 - Use the present tense ("Add feature" not "Added feature")
 - Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
 - Limit the first line to 72 characters or less
 - Reference issues and pull requests liberally after the first line
 - Project uses [Karma commit message format](http://karma-runner.github.io/6.0/dev/git-commit-msg.html)

### Lint

This project uses [luacheck](https://github.com/mpeterv/luacheck) and [stylua](https://github.com/johnnymorganz/stylua). Script is provided to prepare pre-commit hook to check these tools and run tests (`scripts/devsetup`).

## Generating documentation

Documentation is generated using [lemmy-help](https://github.com/numToStr/lemmy-help). To generate documentation run `scripts/gendoc`.

## Running tests

Running tests requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) and [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) to be checked out in the parent directory of this repository.

Tests can then be run with:
```
nvim --headless --noplugin -u tests/init.vim -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/init.vim'}"
```
