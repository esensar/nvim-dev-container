local function clean_jsonc(jsonc_content)
	local result, _ = string.gsub(jsonc_content, "//.-\n", "\n")
	return vim.fn.substitute(result, ",\\_s*}", "}", "g")
end

local function parse_jsonc(jsonc_content)
	local clean_content = clean_jsonc(jsonc_content)
	return vim.json.decode(clean_content)
end

return {
	parse_jsonc = parse_jsonc,
}
