---@brief [[
---Internal library for validation
---@brief ]]

local M = {}

M.callbacks_validations = {
	on_success = "function",
	on_fail = "function",
}

function M.validate_opts_with_callbacks(opts, mapping)
	M.validate_opts(opts, vim.tbl_extend("error", M.callbacks_validations, mapping))
end

function M.validate_callbacks(opts)
	M.validate_opts(opts, M.callbacks_validations)
end

function M.validate_opts(opts, mapping)
	local validation = {}
	for k, v in pairs(mapping) do
		if type(v) == "function" then
			validation["opts." .. k] = { opts[k], v }
		elseif type(v) == "table" then
			validation["opts." .. k] = { opts[k], vim.list_extend(v, { "nil" }) }
		else
			validation["opts." .. k] = { opts[k], { v, "nil" } }
		end
	end
	vim.validate(validation)
end

return M
