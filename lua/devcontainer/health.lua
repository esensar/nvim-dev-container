local health
if vim.fn.has("nvim-0.8") == 1 then
  health = vim.health
else
  health = require("health")
end

local function vim_version_string()
  local v = vim.version()
  return v.major .. "." .. v.minor .. "." .. v.patch
end

local config = require("devcontainer.config")
local executor = require("devcontainer.internal.executor")

return {
  check = function()
    health.report_start("Neovim version")

    if vim.fn.has("nvim-0.7") == 0 then
      health.report_warn("Latest Neovim version is recommended for full feature set!")
    else
      health.report_ok("Neovim version tested and supported: " .. vim_version_string())
    end

    health.report_start("Required plugins")

    local has_jsonc, jsonc_info = pcall(vim.treesitter.inspect_language, "jsonc")

    if not has_jsonc then
      health.report_error("Jsonc treesitter parser missing! devcontainer.json files parsing will fail!")
    else
      health.report_ok("Jsonc treesitter parser available. ABI version: " .. jsonc_info._abi_version)
    end

    health.report_start("External dependencies")

    if config.container_runtime ~= nil then
      if executor.is_executable(config.container_runtime) then
        local handle = io.popen(config.container_runtime .. " --version")
        if handle ~= nil then
          local version = handle:read("*a")
          handle:close()
          health.report_ok(version)
        end
      else
        health.report_error(config.container_runtime .. " is not executable. Make sure it is installed!")
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
            health.report_ok("Found " .. executable .. ": " .. version)
          end
        end
      end
      if not has_any then
        health.report_error("No container runtime is available! Install either podman or docker!")
      end
    end

    if config.compose_command ~= nil then
      if executor.is_executable(config.compose_command) then
        local handle = io.popen(config.compose_command .. " --version")
        if handle ~= nil then
          local version = handle:read("*a")
          handle:close()
          health.report_ok(version)
        end
      else
        health.report_error(
          config.compose_command .. " is not executable! It is required for full functionality of this plugin!"
        )
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
            health.report_ok("Found " .. executable .. ": " .. version)
          end
        end
      end
      if not has_any then
        health.report_error("No compose tool is available! Install either podman-compose or docker-compose!")
      end
    end
  end,
}
