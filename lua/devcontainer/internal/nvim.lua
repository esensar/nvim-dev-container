---@mod devcontainer.internal.nvim Neovim in container related commands
---@brief [[
---Provides high level commands related to using neovim inside container
---@brief ]]

local M = {}

local log = require("devcontainer.internal.log")
local v = require("devcontainer.internal.validation")
local container_executor = require("devcontainer.internal.container_executor")

---@class AddNeovimOpts
---@field on_success? function() success callback
---@field on_step? function(step) step success callback
---@field on_fail? function() failure callback
---@field version? string version of neovim to use - current version by default

---Adds neovim to passed container using exec
---@param container_id string id of container to add neovim to
---@param opts? AddNeovimOpts Additional options including callbacks
function M.add_neovim(container_id, opts)
  vim.validate({
    container_id = { container_id, "string" },
    opts = { opts, { "table", "nil" } },
  })
  opts = opts or {}
  v.validate_callbacks(opts)
  opts.on_success = opts.on_success
    or function()
      vim.notify("Successfully added neovim to container (" .. container_id .. ")")
    end
  opts.on_fail = opts.on_fail
    or function()
      vim.notify("Adding neovim to container (" .. container_id .. ") has failed!", vim.log.levels.ERROR)
    end
  opts.on_step = opts.on_step
    or function(step)
      vim.notify(
        "Executed " .. table.concat(step, " ") .. " on container (" .. container_id .. ")!",
        vim.log.levels.ERROR
      )
    end

  local version_string = opts.version
  if not version_string then
    local version = vim.version()
    version_string = "v" .. version.major .. "." .. version.minor .. "." .. version.patch
  end
  local commands = {
    {
      "apt-get",
      "update",
    },
    {
      "apt-get",
      "-y",
      "install",
      "curl",
      "fzf",
      "ripgrep",
      "tree",
      "git",
      "xclip",
      "python3",
      "python3-pip",
      "python3-pynvim",
      "nodejs",
      "npm",
      "tzdata",
      "ninja-build",
      "gettext",
      "libtool",
      "libtool-bin",
      "autoconf",
      "automake",
      "cmake",
      "g++",
      "pkg-config",
      "zip",
      "unzip",
    },
    { "npm", "i", "-g", "neovim" },
    { "mkdir", "-p", "/root/TMP" },
    { "sh", "-c", "cd /root/TMP && git clone https://github.com/neovim/neovim" },
    {
      "sh",
      "-c",
      "cd /root/TMP/neovim && (git checkout " .. version_string .. " || true) && make -j4 && make install",
    },
    { "rm", "-rf", "/root/TMP" },
  }

  container_executor.run_all_seq(
    container_id,
    commands,
    { on_success = opts.on_success, on_step = opts.on_step, on_fail = opts.on_fail }
  )
end

log.wrap(M)
return M
