local function vim_version_string()
  local v = vim.version()
  return v.major .. "." .. v.minor .. "." .. v.patch
end

local config = require("devcontainer.config")
local executor = require("devcontainer.internal.executor")

return {
  check = function()
    vim.health.start("Neovim version")

    if vim.fn.has("nvim-0.11") == 0 then
      vim.health.warn("Latest Neovim version is recommended for full feature set!")
    else
      vim.health.ok("Neovim version tested and supported: " .. vim_version_string())
    end

    vim.health.start("Required plugins")

    local has_jsonc, jsonc_info = pcall(vim.treesitter.language.inspect, "jsonc")

    if not has_jsonc then
      vim.health.error("Jsonc treesitter parser missing! devcontainer.json files parsing will fail!")
    else
      vim.health.ok("Jsonc treesitter parser available. ABI version: " .. jsonc_info._abi_version)
    end

    vim.health.start("External dependencies")

    if config.container_runtime ~= nil then
      if executor.is_executable(config.container_runtime) then
        local handle = io.popen(config.container_runtime .. " --version")
        if handle ~= nil then
          local version = handle:read("*a")
          handle:close()
          vim.health.ok(version)
        end
      else
        vim.health.error(config.container_runtime .. " is not executable. Make sure it is installed!")
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
            vim.health.ok("Found " .. executable .. ": " .. version)
          end
        end
      end
      if not has_any then
        vim.health.error("No container runtime is available! Install either podman or docker!")
      end
    end

    if config.compose_command ~= nil then
      if executor.is_executable(config.compose_command) then
        local handle = io.popen(config.compose_command .. " --version")
        if handle ~= nil then
          local version = handle:read("*a")
          handle:close()
          vim.health.ok(version)
        end
      else
        vim.health.error(
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
            vim.health.ok("Found " .. executable .. ": " .. version)
          end
        end
      end
      if not has_any then
        vim.health.error("No compose tool is available! Install either podman-compose or docker-compose!")
      end
    end
  end,
}
