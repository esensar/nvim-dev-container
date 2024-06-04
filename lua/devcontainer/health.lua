local function vim_version_string()
  local v = vim.version()
  return v.major .. "." .. v.minor .. "." .. v.patch
end

local config = require("devcontainer.config")
local executor = require("devcontainer.internal.executor")

return {
  check = function()
    local start
    if vim.fn.has("nvim-0.10") == 1 then
      start = vim.health.start
    else
      start = vim.health.report_start
    end
    local warn
    if vim.fn.has("nvim-0.10") == 1 then
      warn = vim.health.warn
    else
      warn = vim.health.report_warn
    end
    local ok
    if vim.fn.has("nvim-0.10") == 1 then
      ok = vim.health.ok
    else
      ok = vim.health.report_ok
    end
    local error
    if vim.fn.has("nvim-0.10") == 1 then
      error = vim.health.error
    else
      error = vim.health.report_error
    end

    start("Neovim version")

    if vim.fn.has("nvim-0.10") == 0 then
      warn("Latest Neovim version is recommended for full feature set!")
    else
      ok("Neovim version tested and supported: " .. vim_version_string())
    end

    start("Required plugins")

    local has_jsonc, jsonc_info = pcall(vim.treesitter.language.inspect, "jsonc")

    if not has_jsonc then
      error("Jsonc treesitter parser missing! devcontainer.json files parsing will fail!")
    else
      ok("Jsonc treesitter parser available. ABI version: " .. jsonc_info._abi_version)
    end

    start("External dependencies")

    if config.container_runtime ~= nil then
      if executor.is_executable(config.container_runtime) then
        local handle = io.popen(config.container_runtime .. " --version")
        if handle ~= nil then
          local version = handle:read("*a")
          handle:close()
          ok(version)
        end
      else
        error(config.container_runtime .. " is not executable. Make sure it is installed!")
      end
    else
      local runtimes = { "podman", "docker" }
      local has_any = false
      for _, executable in ipairs(runtimes) do
        if executor.is_executable(executable) then
          has_any = true
          local handle = io.popen(executable .. " --version")
          if handle ~= nil then
            local version = handle:read("*a")
            handle:close()
            ok("Found " .. executable .. ": " .. version)
          end
        end
      end
      if not has_any then
        error("No container runtime is available! Install either podman or docker!")
      end
    end

    if config.compose_command ~= nil then
      if executor.is_executable(config.compose_command) then
        local handle = io.popen(config.compose_command .. " --version")
        if handle ~= nil then
          local version = handle:read("*a")
          handle:close()
          ok(version)
        end
      else
        error(config.compose_command .. " is not executable! It is required for full functionality of this plugin!")
      end
    else
      local compose_runtimes = { "podman-compose", "docker-compose", "docker compose" }
      local has_any = false
      for _, executable in ipairs(compose_runtimes) do
        if executor.is_executable(executable) then
          has_any = true
          local handle = io.popen(executable .. " --version")
          if handle ~= nil then
            local version = handle:read("*a")
            handle:close()
            ok("Found " .. executable .. ": " .. version)
          end
        end
      end
      if not has_any then
        error("No compose tool is available! Install either podman-compose or docker-compose!")
      end
    end
  end,
}
