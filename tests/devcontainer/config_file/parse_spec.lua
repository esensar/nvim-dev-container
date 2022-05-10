local mock = require("luassert.mock")
local match = require("luassert.match")

describe("devcontainer.config_file.parse:", function()
	local subject = require("devcontainer.config_file.parse")

	describe("given existing file", function()
		describe("parse_devcontainer_config", function()
			local mock_fd = 1
			local result = '{ "image": "value" }'
			local fstat = {
				size = string.len(result),
			}
			local test_it = function(name, block)
				it(name, function()
					local uv_mock = mock(vim.loop, true)
					uv_mock.fs_open.returns(mock_fd)
					uv_mock.fs_fstat.returns(fstat)
					uv_mock.fs_read.returns(result)
					uv_mock.fs_close.returns(true)

					local data = subject.parse_devcontainer_config("test.json")
					block(uv_mock, data)

					mock.revert(uv_mock)
				end)
			end

			test_it("should return contained json", function(_, data)
				assert.are.same("value", data.image)
			end)

			test_it("should return metadata with file_path", function(_, data)
				assert.are.same("test.json", data.metadata.file_path)
			end)

			test_it("should open file in read mode", function(uv_mock, _)
				assert.stub(uv_mock.fs_open).was_called_with("test.json", "r", match._)
			end)

			test_it("should read complete file", function(uv_mock, _)
				assert.stub(uv_mock.fs_read).was_called_with(mock_fd, fstat.size, 0)
			end)

			test_it("should close file", function(uv_mock, _)
				assert.stub(uv_mock.fs_close).was_called_with(mock_fd)
			end)
		end)
	end)

	describe("given missing file", function()
		describe("parse_devcontainer_config", function()
			local test_it = function(name, block)
				it(name, function()
					local uv_mock = mock(vim.loop, true)
					uv_mock.fs_open.returns({ nil, "ENOENT", "ENOENT" })

					local success, data = pcall(subject.parse_devcontainer_config, "test.json")
					block(uv_mock, success, data)

					mock.revert(uv_mock)
				end)
			end

			test_it("should fail", function(_, success, _)
				assert.is_not_true(success)
			end)
		end)
	end)

	describe("given proper file", function()
		describe("parse_devcontainer_config", function()
			local mock_fd = 1
			local it_should_succeed_for_json = function(file_content, key, expected)
				local succeed_string = expected and "succeed" or "fail"
				it("should " .. succeed_string .. " when " .. key .. " is present", function()
					local uv_mock = mock(vim.loop, true)
					local fstat = {
						size = string.len(file_content),
					}
					uv_mock.fs_open.returns(mock_fd)
					uv_mock.fs_fstat.returns(fstat)
					uv_mock.fs_read.returns(file_content)
					uv_mock.fs_close.returns(true)

					local success, _ = pcall(subject.parse_devcontainer_config, "test.json")
					assert.are.same(expected, success)

					mock.revert(uv_mock)
				end)
			end
			local it_should_succeed_for_key = function(key, expected)
				it_should_succeed_for_json('{ "' .. key .. '": "value" }', key, expected)
			end

			it_should_succeed_for_key("image", true)
			it_should_succeed_for_key("dockerFile", true)
			it_should_succeed_for_key("dockerComposeFile", true)
			it_should_succeed_for_json('{ "build" : { "dockerfile": "value" } }', "build.dockerfile", true)
			it_should_succeed_for_key("none of these", false)
		end)
	end)
end)
