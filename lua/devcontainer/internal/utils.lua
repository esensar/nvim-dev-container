local plugin_config = require("devcontainer.config")

local M = {}

M.path_sep = package.config:sub(1, 1)

function M.add_constructor(table)
  table.new = function(extras)
    local new_instance = {}
    setmetatable(new_instance, { __index = table })
    if extras and type(extras) == "table" and not vim.islist(extras) then
      for k, v in pairs(extras) do
        new_instance[k] = v
      end
    end
    return new_instance
  end
  return table
end

function M.get_image_cache_tag()
  local tag = plugin_config.workspace_folder_provider()
  tag = string.gsub(tag, "[%/%s%-%\\%:]", "")
  return "nvim_dev_container_" .. string.lower(tag)
end

return M
