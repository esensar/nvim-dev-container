local M = {}

M.path_sep = package.config:sub(1, 1)

function M.add_constructor(table)
  table.new = function()
    local new_instance = {}
    setmetatable(new_instance, { __index = table })
    return new_instance
  end
  return table
end

return M
