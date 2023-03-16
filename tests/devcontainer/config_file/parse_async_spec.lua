local mock = require("luassert.mock")
local stub = require("luassert.stub")
local match = require("luassert.match")

local function mock_file_read(uv_mock, result, opts)
  opts = opts or {}
  uv_mock.fs_open.invokes(function(_, _, _, callback)
    local val = opts.fd or 1
    if callback then
      callback(nil, val)
    else
      return val
    end
  end)
  uv_mock.fs_fstat.invokes(function(_, callback)
    local val = opts.fstat or { size = string.len(result) }
    if callback then
      callback(nil, opts.fstat or { size = string.len(result) })
    else
      return val
    end
  end)
  uv_mock.fs_read.invokes(function(_, _, _, callback)
    if callback then
      callback(nil, result)
    else
      return result
    end
  end)
  uv_mock.fs_close.invokes(function(_, callback)
    if callback then
      callback(nil, true)
    else
      return true
    end
  end)
end

local function missing_file_func(_, _, _, callback)
  callback("ENOENT", nil)
end

local vim_schedule_mock = stub(vim, "schedule_wrap")
vim_schedule_mock.invokes(function(func)
  return func
end)

describe("devcontainer.config_file.parse(async):", function()
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

          subject.parse_devcontainer_config("test.json", function(err, data)
            if err then
              mock.revert(uv_mock)
              error(err)
            end
            block(uv_mock, data)
            mock.revert(uv_mock)
          end)
        end)
      end

      test_it("should return contained json", function(_, data)
        assert.are.same("value", data.image)
      end)

      test_it("should return metadata with file_path", function(_, data)
        assert.are.same("test.json", data.metadata.file_path)
      end)

      test_it("should open file in read mode", function(uv_mock, _)
        assert.stub(uv_mock.fs_open).was_called_with("test.json", "r", match._, match._)
      end)

      test_it("should read complete file", function(uv_mock, _)
        assert.stub(uv_mock.fs_read).was_called_with(mock_fd, fstat.size, 0, match._)
      end)

      test_it("should close file", function(uv_mock, _)
        assert.stub(uv_mock.fs_close).was_called_with(mock_fd, match._)
      end)
    end)
  end)

  describe("given missing file", function()
    describe("parse_devcontainer_config", function()
      local test_it = function(name, block)
        it(name, function()
          local uv_mock = mock(vim.loop, true)
          uv_mock.fs_open.invokes(missing_file_func)

          subject.parse_devcontainer_config("test.json", function(err, data)
            block(uv_mock, not err, data or err)
            mock.revert(uv_mock)
          end)
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
          mock_file_read(uv_mock, file_content, {
            fd = mock_fd,
            fstat = fstat,
          })

          subject.parse_devcontainer_config("test.json", function(err, _)
            assert.are.same(expected, not err)
            mock.revert(uv_mock)
          end)
        end)
      end
      local function it_should_succeed_for_key(key, expected)
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
          uv_mock.fs_stat.invokes(function(path, callback)
            if path == cwd then
              callback(nil, { ino = 123 })
            elseif path == cwd .. "/.devcontainer.json" then
              callback(nil, { ino = 456 })
            else
              callback("error", nil)
            end
          end)

          subject.parse_nearest_devcontainer_config(function(err, data)
            if err then
              mock.revert(uv_mock)
              error(err)
            end
            block(data, uv_mock)
            mock.revert(uv_mock)
          end)
        end)
      end

      test_it("should return value from parse_devcontainer_config", function(data, _)
        assert.are.same(subject.parse_devcontainer_config("./.devcontainer.json"), data)
      end)

      test_it("should call parse_devcontainer_config with .devcontainer.json path", function(_, uv_mock)
        assert.stub(uv_mock.fs_open).was_called_with("./.devcontainer.json", "r", match._, match._)
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
          uv_mock.fs_stat.invokes(function(path, callback)
            if path == cwd then
              callback(nil, { ino = 123 })
            elseif path == cwd .. "/.devcontainer.json" then
              callback("ENOENT", nil)
            elseif path == cwd .. "/.devcontainer/devcontainer.json" then
              callback(nil, { ino = 456 })
            else
              callback("error", nil)
            end
          end)

          subject.parse_nearest_devcontainer_config(function(err, data)
            if err then
              mock.revert(uv_mock)
              error(err)
            end
            block(data, uv_mock)
            mock.revert(uv_mock)
          end)
        end)
      end

      test_it("should return value from parse_devcontainer_config", function(data, _)
        assert.are.same(subject.parse_devcontainer_config("./.devcontainer/devcontainer.json"), data)
      end)

      test_it("should call parse_devcontainer_config with .devcontainer/devcontainer.json path", function(_, uv_mock)
        assert.stub(uv_mock.fs_open).was_called_with("./.devcontainer/devcontainer.json", "r", match._, match._)
      end)
    end)
  end)

  describe("given no devcontainer files", function()
    describe("parse_nearest_devcontainer_config", function()
      local cwd = "."
      local test_it = function(name, block)
        it(name, function()
          local uv_mock = mock(vim.loop, true)
          uv_mock.cwd.returns(cwd)
          uv_mock.fs_stat.invokes(function(path, callback)
            if path == cwd then
              callback(nil, { ino = 123 })
            elseif path == cwd .. "/.devcontainer.json" then
              callback("ENOENT", nil)
            elseif path == cwd .. "/.devcontainer/devcontainer.json" then
              callback("ENOENT", nil)
            elseif path == cwd .. "/.." then
              callback(nil, { ino = 456 })
            elseif path == cwd .. "/../.devcontainer.json" then
              callback("ENOENT", nil)
            elseif path == cwd .. "/../.devcontainer/devcontainer.json" then
              callback("ENOENT", nil)
            elseif path == cwd .. "/../.." then
              callback(nil, { ino = 456 })
            else
              callback("error", nil)
            end
          end)

          subject.parse_nearest_devcontainer_config(function(err, data)
            block(not err, data or err, uv_mock)
            mock.revert(uv_mock)
          end)
        end)
      end

      test_it("should return an error that no files were found", function(success, _, _)
        assert.is_not_true(success)
      end)
    end)
  end)
end)
