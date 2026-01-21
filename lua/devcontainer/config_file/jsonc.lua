---@mod devcontainer.config_file.jsonc Jsonc parsing module
---@brief [[
---Vim supports Json parsing by default, but devcontainer config files are Jsonc.
---This module supports Jsonc parsing by removing comments and then parsing as Json.
---Treesitter is used for this and jsonc parser needs to be installed.
---@brief ]]
local log = require("devcontainer.internal.log")
local M = {}

local function clean_jsonc(jsonc_content)
  local parser = vim.treesitter.get_string_parser(jsonc_content, "json")
  local tree = parser:parse()
  local root = tree[1]:root()
  local query = vim.treesitter.query.parse("json", "((comment)+ @c)")
  local lines = vim.split(jsonc_content, "\n")

  ---@diagnostic disable-next-line: missing-parameter
  for _, node, _ in query:iter_captures(root) do
    local row_start, col_start, row_end, col_end = node:range()
    local line = row_start + 1
    local start_part = string.sub(lines[line], 1, col_start)
    local end_part = string.sub(lines[line], col_end + 1)
    lines[line] = start_part .. end_part
    for l = line + 1, row_end, 1 do
      lines[l] = ""
    end
    if row_end + 1 ~= line then
      lines[row_end + 1] = string.sub(lines[line], col_end + 1)
    end
  end
  local result = vim.fn.join(lines, "\n")
  return vim.fn.substitute(result, ",\\_s*}", "}", "g")
end

---Parse Json string into a Lua table
---Usually file should be read and content should be passed as a string into the function
---@param jsonc_content string
---@return table?
---@usage `require("devcontainer.config_file.jsonc").parse_jsonc([[{ "test": "value" }]])`
function M.parse_jsonc(jsonc_content)
  vim.validate({
    jsonc_content = { jsonc_content, "string" },
  })
  local clean_content = clean_jsonc(jsonc_content)
  return vim.json.decode(clean_content)
end

log.wrap(M)
return M
