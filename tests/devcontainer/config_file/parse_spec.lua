local mock = require("luassert.mock")
local match = require("luassert.match")

local function mock_file_read(uv_mock, result, opts)
	opts = opts or {}
	uv_mock.fs_open.returns(opts.fd or 1)
	uv_mock.fs_fstat.returns(opts.fstat or { size = string.len(result) })
	uv_mock.fs_read.returns(result)
	uv_mock.fs_close.returns(true)
end

local function missing_file_func()
	error("ENOENT")
end

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
					mock_file_read(uv_mock, result, {
						fd = mock_fd,
						fstat = fstat,
					})

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
					uv_mock.fs_open.invokes(missing_file_func)

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

	describe("given existing .devcontainer.json", function()
		describe("parse_nearest_devcontainer_config", function()
			local result = '{ "image": "value" }'
			local cwd = "."
			local test_it = function(name, block)
				it(name, function()
					local uv_mock = mock(vim.loop, true)
					mock_file_read(uv_mock, result)
					uv_mock.cwd.returns(cwd)
					uv_mock.fs_stat.on_call_with(cwd).returns({ ino = 123 })
					uv_mock.fs_stat.on_call_with(cwd .. "/.devcontainer.json").returns({ ino = 456 })

					local data = subject.parse_nearest_devcontainer_config()

					block(data, uv_mock)

					mock.revert(uv_mock)
				end)
			end

			test_it("should return value from parse_devcontainer_config", function(data, _)
				assert.are.same(subject.parse_devcontainer_config("./.devcontainer.json"), data)
			end)

			test_it("should call parse_devcontainer_config with .devcontainer.json path", function(_, uv_mock)
				assert.stub(uv_mock.fs_open).was_called_with("./.devcontainer.json", "r", match._)
			end)
		end)
	end)

	describe("given existing .devcontainer/devcontainer.json", function()
		describe("parse_nearest_devcontainer_config", function()
			local result = '{ "image": "value" }'
			local cwd = "."
			local test_it = function(name, block)
				it(name, function()
					local uv_mock = mock(vim.loop, true)
					mock_file_read(uv_mock, result)
					uv_mock.cwd.returns(cwd)
					uv_mock.fs_stat.on_call_with(cwd).returns({ ino = 123 })
					uv_mock.fs_stat.on_call_with(cwd .. "/.devcontainer.json").invokes(missing_file_func)
					uv_mock.fs_stat.on_call_with(cwd .. "/.devcontainer/devcontainer.json").returns({ ino = 456 })

					local data = subject.parse_nearest_devcontainer_config()

					block(data, uv_mock)

					mock.revert(uv_mock)
				end)
			end

			test_it("should return value from parse_devcontainer_config", function(data, _)
				assert.are.same(subject.parse_devcontainer_config("./.devcontainer/devcontainer.json"), data)
			end)

			test_it(
				"should call parse_devcontainer_config with .devcontainer/devcontainer.json path",
				function(_, uv_mock)
					assert.stub(uv_mock.fs_open).was_called_with("./.devcontainer/devcontainer.json", "r", match._)
				end
			)
		end)
	end)

	describe("given no devcontainer files", function()
		describe("parse_nearest_devcontainer_config", function()
			local cwd = "."
			local test_it = function(name, block)
				it(name, function()
					local uv_mock = mock(vim.loop, true)
					uv_mock.cwd.returns(cwd)
					uv_mock.fs_stat.on_call_with(cwd).returns({ ino = 123 })
					uv_mock.fs_stat.on_call_with(cwd .. "/.devcontainer.json").invokes(missing_file_func)
					uv_mock.fs_stat.on_call_with(cwd .. "/.devcontainer/devcontainer.json").invokes(missing_file_func)
					uv_mock.fs_stat.on_call_with(cwd .. "/..").returns({ ino = 456 })
					uv_mock.fs_stat.on_call_with(cwd .. "/../.devcontainer.json").invokes(missing_file_func)
					uv_mock.fs_stat.on_call_with(cwd .. "/../.devcontainer/devcontainer.json").invokes(
						missing_file_func
					)
					uv_mock.fs_stat.on_call_with(cwd .. "/../..").returns({ ino = 456 })

					local success, data = pcall(subject.parse_nearest_devcontainer_config)

					block(success, data, uv_mock)

					mock.revert(uv_mock)
				end)
			end

			test_it("should return an error that no files were found", function(success, _, _)
				assert.is_not_true(success)
			end)
		end)
	end)
end)
