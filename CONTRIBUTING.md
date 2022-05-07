# Contributing to nvim-dev-container

First of all, thanks for taking the time to contribute to the project!

Following is a basic set of guidelines for contributing to this repository and instructions to make it as easy as possible.

> Parts of this guidelines are taken from https://github.com/atom/atom/blob/master/CONTRIBUTING.md

#### Table of contents

- [Asking questions](#asking-questions)
- [Styleguides](#styleguides)
  - [Commit message](#commit-messages)
  - [Lint](#lint)
- [Additional info](#additional-info)

## Asking questions

For asking questions, please make sure to use [**Discussions**](https://github.com/esensar/nvim-dev-container/discussions) instead of **Issues**.

## Styleguides

### Commit messages
 - Use the present tense ("Add feature" not "Added feature")
 - Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
 - Limit the first line to 72 characters or less
 - Reference issues and pull requests liberally after the first line
 - Project uses [Karma commit message format](http://karma-runner.github.io/6.0/dev/git-commit-msg.html)

### Lint

This project uses [luacheck](https://github.com/mpeterv/luacheck) and [stylua](https://github.com/johnnymorganz/stylua). Script is provided to prepare pre-commit hook to check these tools and run tests (`scripts/devsetup`).

## Running tests

Running tests requires [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) and [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) to be checked out in the parent directory of this repository.

Tests can then be run with:
```
nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal.vim'}"
```
