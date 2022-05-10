local function clean_jsonc(jsonc_content)
	local parser = vim.treesitter.get_string_parser(jsonc_content, "jsonc")
	local tree = parser:parse()
	local root = tree[1]:root()
	local query = vim.treesitter.parse_query("jsonc", "((comment)+ @c)")
	local lines = vim.split(jsonc_content, "\n")

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

local function parse_jsonc(jsonc_content)
	local clean_content = clean_jsonc(jsonc_content)
	return vim.json.decode(clean_content)
end

return {
	parse_jsonc = parse_jsonc,
}
