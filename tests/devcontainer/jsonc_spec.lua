local subject = require("devcontainer.jsonc")

describe("devcontainer/jsonc:", function()
	describe("parse_jsonc", function()
		it("should have same behavior as json_decode for basic json", function()
			local json = '{ "test": "value", "nested": { "nested_test": "nested_value" } }'
			assert.are.same(vim.fn.json_decode(json), subject.parse_jsonc(json))
		end)

		it("should work even when comments are present", function()
			local json = '{ "test": "value", "nested": { "nested_test": "nested_value" } }'
			local json_with_comments =
				'{ \n//comment in line 1\n"test": //commentafter\n "value", "nested": { "nested_test": "nested_value" } }'
			assert.are.same(vim.fn.json_decode(json), subject.parse_jsonc(json_with_comments))
		end)

		it("should work even when trailing commas are present", function()
			local json = '{ "test": "value", "nested": { "nested_test": "nested_value" } }'
			local json_with_commas = '{ "test": "value", "nested": { "nested_test": "nested_value", } }'
			assert.are.same(vim.fn.json_decode(json), subject.parse_jsonc(json_with_commas))
		end)

		it("should work when text was retrieved from a buffer", function()
			local buffer = vim.api.nvim_create_buf(0, 0)
			vim.api.nvim_buf_set_lines(buffer, 0, -1, 0, {
				"{",
				"  //comment in line 1",
				'  "test": // comment after',
				'  "value", "nested": { "nested_test": "nested_value" } }',
			})
			local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, 0)
			vim.api.nvim_buf_delete(buffer, {})
			local json = '{ "test": "value", "nested": { "nested_test": "nested_value" } }'
			local json_with_comments = vim.fn.join(lines, "\n")
			assert.are.same(vim.fn.json_decode(json), subject.parse_jsonc(json_with_comments))
		end)
		it("should work with block comments too", function()
			local json = '{ "test": "value", "nested": { "nested_test": "nested_value" } }'
			local json_with_comments = [[
      {
        /* comment
        started above
        ends here */
        "test": //inline comment
        "value", "nested": { "nested_test": "nested_value" } }
      ]]
			assert.are.same(vim.fn.json_decode(json), subject.parse_jsonc(json_with_comments))
		end)
	end)
end)
