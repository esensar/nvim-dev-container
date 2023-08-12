---@mod devcontainer.internal.cmdline Command line related helpers
---@brief [[
---Provides helpers related to Neovim command line
---@brief ]]

local M = {}

---@class CmdLineStatus
---@field arg_count integer total arguments count (not including the command)
---@field current_arg integer index of current argument (1 based index)
---@field current_arg_lead string? current arg lead

---Helper that can be passed into the `complete`
---extra in `nvim_create_user_command` to parse
---arguments and make it easier to decide on completion
---results
---@param callback function(CmdLineStatus)
---@return function
function M.complete_parse(callback)
  return function(arg_lead, cmd_line, cursor_pos)
    -- Remove command part
    local replaced_length = string.match(cmd_line, "%w*%s"):len()

    if replaced_length > cursor_pos then
      return callback({ arg_count = 0, current_arg = 0, current_arg_lead = "" })
    end

    local _, arg_count = string.gsub(cmd_line, "%w%s", "")
    local _, current_arg = string.gsub(string.sub(cmd_line, 1, cursor_pos), "%w%s", "")

    return callback({ arg_count = arg_count, current_arg = current_arg, arg_lead = arg_lead })
  end
end

return M
