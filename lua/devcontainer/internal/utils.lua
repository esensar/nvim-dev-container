local M = {}

M.path_sep = package.config:sub(1, 1)

function M.add_constructor(table)
  table.new = function(extras)
    local new_instance = {}
    setmetatable(new_instance, { __index = table })
    if extras and type(extras) == "table" and not vim.tbl_islist(extras) then
      for k, v in pairs(extras) do
        new_instance[k] = v
      end
    end
    return new_instance
  end
  return table
end

return M
