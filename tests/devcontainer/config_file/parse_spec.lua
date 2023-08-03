local mock = require("luassert.mock")
local match = require("luassert.match")

local function mock_file_read(uv_mock, result, opts)
  opts = opts or {}
  uv_mock.fs_open.returns(opts.fd or 1)
  uv_mock.fs_fstat.returns(opts.fstat or { size = string.len(result) })
  uv_mock.fs_read.returns(result)
  uv_mock.fs_close.returns(true)
  uv_mock.hrtime.returns(0)
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
          mock_file_read(uv_mock, file_content, { fd = mock_fd, fstat = fstat })

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
          local config_mock = mock(require("devcontainer.config"), true)
          mock_file_read(uv_mock, result)
          config_mock.config_search_start.returns(cwd)
          uv_mock.fs_stat.on_call_with(cwd).returns({ ino = 123 })
          uv_mock.fs_stat.on_call_with(cwd .. "/.devcontainer.json").returns({ ino = 456 })

          local data = subject.parse_nearest_devcontainer_config()

          block(data, uv_mock)

          mock.revert(uv_mock)
          mock.revert(config_mock)
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
          local config_mock = mock(require("devcontainer.config"), true)
          config_mock.config_search_start.returns(cwd)
          uv_mock.fs_stat.on_call_with(cwd).returns({ ino = 123 })
          uv_mock.fs_stat.on_call_with(cwd .. "/.devcontainer.json").invokes(missing_file_func)
          uv_mock.fs_stat.on_call_with(cwd .. "/.devcontainer/devcontainer.json").returns({ ino = 456 })

          local data = subject.parse_nearest_devcontainer_config()

          block(data, uv_mock)

          mock.revert(uv_mock)
          mock.revert(config_mock)
        end)
      end

      test_it("should return value from parse_devcontainer_config", function(data, _)
        assert.are.same(subject.parse_devcontainer_config("./.devcontainer/devcontainer.json"), data)
      end)

      test_it("should call parse_devcontainer_config with .devcontainer/devcontainer.json path", function(_, uv_mock)
        assert.stub(uv_mock.fs_open).was_called_with("./.devcontainer/devcontainer.json", "r", match._)
      end)
    end)
  end)

  describe("given no devcontainer files", function()
    describe("parse_nearest_devcontainer_config", function()
      local cwd = "."
      local test_it = function(name, block)
        it(name, function()
          local uv_mock = mock(vim.loop, true)
          local config_mock = mock(require("devcontainer.config"), true)
          config_mock.config_search_start.returns(cwd)
          uv_mock.fs_stat.on_call_with(cwd).returns({ ino = 123 })
          uv_mock.fs_stat.on_call_with(cwd .. "/.devcontainer.json").invokes(missing_file_func)
          uv_mock.fs_stat.on_call_with(cwd .. "/.devcontainer/devcontainer.json").invokes(missing_file_func)
          uv_mock.fs_stat.on_call_with(cwd .. "/..").returns({ ino = 456 })
          uv_mock.fs_stat.on_call_with(cwd .. "/../.devcontainer.json").invokes(missing_file_func)
          uv_mock.fs_stat.on_call_with(cwd .. "/../.devcontainer/devcontainer.json").invokes(missing_file_func)
          uv_mock.fs_stat.on_call_with(cwd .. "/../..").returns({ ino = 456 })

          local success, data = pcall(subject.parse_nearest_devcontainer_config)

          block(success, data, uv_mock)

          mock.revert(uv_mock)
          mock.revert(config_mock)
        end)
      end

      test_it("should return an error that no files were found", function(success, _, _)
        assert.is_not_true(success)
      end)
    end)
  end)

  local function test_dockerfile_updates(given_config_provider, workspace_dir)
    local test_it = function(name, block)
      it(name, function()
        local config_mock = mock(require("devcontainer.config"), true)
        config_mock.workspace_folder_provider.returns(workspace_dir)

        local data = subject.fill_defaults(given_config_provider())

        block(data, config_mock)

        mock.revert(config_mock)
      end)
    end

    test_it("should update build.dockerfile to absolute path", function(data, _)
      assert.are.same("/home/test/projects/devcontainer/.devcontainer/Dockerfile", data.build.dockerfile)
    end)

    test_it("should update dockerFile to the same value", function(data, _)
      assert.are.same(data.build.dockerfile, data.dockerFile)
    end)

    test_it("should set context and build.context to default value", function(data, _)
      assert.are.same("/home/test/projects/devcontainer/.devcontainer/.", data.context)
      assert.are.same(data.context, data.build.context)
    end)

    test_it("should fill out build.args", function(data, _)
      assert.are.same({}, data.build.args)
    end)

    test_it("should fill out build.mounts", function(data, _)
      assert.are.same({}, data.build.mounts)
    end)

    test_it("should fill out runArgs", function(data, _)
      assert.are.same({}, data.runArgs)
    end)

    test_it("should set overrideCommand to true", function(data, _)
      assert.are.same(true, data.overrideCommand)
    end)

    test_it("should fill out forwardPorts", function(data, _)
      assert.are.same({}, data.forwardPorts)
    end)

    test_it("should fill out remoteEnv", function(data, _)
      assert.are.same({}, data.remoteEnv)
    end)
  end

  describe("given devcontainer config with just build.dockerfile", function()
    describe("fill_defaults", function()
      local given_config = function()
        return {
          build = {
            dockerfile = "Dockerfile",
          },
          hostRequirements = {},
          metadata = {
            file_path = "/home/test/projects/devcontainer/.devcontainer/devcontainer.json",
          },
        }
      end
      local workspace_dir = "/home/test/projects/devcontainer"
      test_dockerfile_updates(given_config, workspace_dir)
    end)
  end)

  describe("given devcontainer config with dockerFile", function()
    describe("fill_defaults", function()
      local given_config = function()
        return {
          dockerFile = "Dockerfile",
          build = {},
          hostRequirements = {},
          metadata = {
            file_path = "/home/test/projects/devcontainer/.devcontainer/devcontainer.json",
          },
        }
      end
      local workspace_dir = "/home/test/projects/devcontainer"
      test_dockerfile_updates(given_config, workspace_dir)
    end)
  end)

  describe("given devcontainer config with dockerComposeFile", function()
    describe("fill_defaults", function()
      local test_it = function(name, block)
        it(name, function()
          local given_config = {
            dockerComposeFile = "docker-compose.yml",
            build = {},
            hostRequirements = {},
            metadata = {
              file_path = "/home/test/projects/devcontainer/.devcontainer/devcontainer.json",
            },
          }
          local workspace_dir = "/home/test/projects/devcontainer"
          local config_mock = mock(require("devcontainer.config"), true)
          config_mock.workspace_folder_provider.returns(workspace_dir)

          local data = subject.fill_defaults(given_config)

          block(data, config_mock)

          mock.revert(config_mock)
        end)
      end

      test_it("should update dockerComposeFile to absolute path", function(data, _)
        assert.are.same("/home/test/projects/devcontainer/.devcontainer/docker-compose.yml", data.dockerComposeFile)
      end)

      test_it("should set workspaceFolder to default", function(data, _)
        assert.are.same("/", data.workspaceFolder)
      end)

      test_it("should set overrideCommand to false", function(data, _)
        assert.are.same(false, data.overrideCommand)
      end)

      test_it("should fill out forwardPorts", function(data, _)
        assert.are.same({}, data.forwardPorts)
      end)

      test_it("should fill out remoteEnv", function(data, _)
        assert.are.same({}, data.remoteEnv)
      end)
    end)
  end)

  describe("given devcontainer config with dockerComposeFile list", function()
    describe("fill_defaults", function()
      local test_it = function(name, block)
        it(name, function()
          local given_config = {
            dockerComposeFile = { "docker-compose.yml", "../docker-compose.yml" },
            build = {},
            hostRequirements = {},
            metadata = {
              file_path = "/home/test/projects/devcontainer/.devcontainer/devcontainer.json",
            },
          }
          local workspace_dir = "/home/test/projects/devcontainer"
          local config_mock = mock(require("devcontainer.config"), true)
          config_mock.workspace_folder_provider.returns(workspace_dir)

          local data = subject.fill_defaults(given_config)

          block(data, config_mock)

          mock.revert(config_mock)
        end)
      end

      test_it("should update all entries in dockerComposeFile to absolute path", function(data, _)
        assert.are.same("/home/test/projects/devcontainer/.devcontainer/docker-compose.yml", data.dockerComposeFile[1])
        assert.are.same(
          "/home/test/projects/devcontainer/.devcontainer/../docker-compose.yml",
          data.dockerComposeFile[2]
        )
      end)
    end)
  end)

  describe("given complex devcontainer config", function()
    describe("fill_defaults", function()
      local test_it = function(name, block)
        it(name, function()
          local given_config = {
            name = "test",
            build = {
              dockerfile = "Dockerfile",
            },
            runArgs = {
              "--cap-add=SYS_PTRACE",
              "--security-opt",
              "seccomp=unconfined",
            },
            settings = {
              ["cmake.configureOnOpen"] = true,
              ["editor.formatOnSave"] = true,
            },
            extensions = {},
            containerEnv = {
              TEST_VAR = "${localEnv:TEST_VAR}",
              MISSING_VAR = "${localEnv:MISSING_VAR:someDefault}",
              COMBINED_VARS = "${localEnv:COMBINED_VAR1}-${localEnv:COMBINED_VAR2}",
            },
            workspaceMount = "source=${localWorkspaceFolder},"
              .. "target=/workspaces/${localWorkspaceFolderBasename},"
              .. "type=bind,"
              .. "consistency=delegated",
            workspaceFolder = "/workspaces/${localWorkspaceFolderBasename}",
            metadata = {
              file_path = "/home/test/projects/devcontainer/.devcontainer/devcontainer.json",
            },
          }
          vim.env.TEST_VAR = "test_var_value"
          vim.env.COMBINED_VAR1 = "var1_value"
          vim.env.COMBINED_VAR2 = "var2_value"
          local workspace_dir = "/home/test/projects/devcontainer"
          local config_mock = mock(require("devcontainer.config"), true)
          config_mock.workspace_folder_provider.returns(workspace_dir)

          local data = subject.fill_defaults(given_config)

          block(data, config_mock)

          mock.revert(config_mock)
        end)
      end

      test_it("should update build.dockerfile and dockerFile to absolute paths", function(data, _)
        assert.are.same("/home/test/projects/devcontainer/.devcontainer/Dockerfile", data.build.dockerfile)
        assert.are.same(data.build.dockerfile, data.dockerFile)
      end)

      test_it("should update workspaceMount with replaced variables", function(data, _)
        assert.are.same(
          "source=/home/test/projects/devcontainer,"
            .. "target=/workspaces/devcontainer,"
            .. "type=bind,"
            .. "consistency=delegated",
          data.workspaceMount
        )
      end)

      test_it("should update workspaceFolder with replaced variables", function(data, _)
        assert.are.same("/workspaces/devcontainer", data.workspaceFolder)
      end)

      test_it("should update containerEnv with replaced variables", function(data, _)
        assert.are.same("test_var_value", data.containerEnv.TEST_VAR)
        assert.are.same("var1_value-var2_value", data.containerEnv.COMBINED_VARS)
      end)

      test_it("should use defaults for missing variables", function(data, _)
        assert.are.same("someDefault", data.containerEnv.MISSING_VAR)
      end)
    end)
  end)

  describe("given disabled recursive search", function()
    describe("parse_nearest_devcontainer_config", function()
      local cwd = "."
      local test_it = function(name, block)
        it(name, function()
          local result = '{ "image": "value" }'
          local uv_mock = mock(vim.loop, true)
          mock_file_read(uv_mock, result, {})
          local config_mock = mock(require("devcontainer.config"), true)
          config_mock.config_search_start.returns(cwd)
          config_mock.disable_recursive_config_search = true
          uv_mock.fs_stat.on_call_with(cwd).returns({ ino = 123 })
          uv_mock.fs_stat.on_call_with(cwd .. "/.devcontainer.json").invokes(missing_file_func)
          uv_mock.fs_stat.on_call_with(cwd .. "/.devcontainer/devcontainer.json").invokes(missing_file_func)
          uv_mock.fs_stat.on_call_with(cwd .. "/..").returns({ ino = 456 })
          uv_mock.fs_stat.on_call_with(cwd .. "/../.devcontainer.json").returns({ ino = 789 })
          uv_mock.fs_stat.on_call_with(cwd .. "/../.devcontainer/devcontainer.json").returns({ ino = 987 })

          local success, data = pcall(subject.parse_nearest_devcontainer_config)

          block(success, data, uv_mock)

          mock.revert(uv_mock)
          mock.revert(config_mock)
          config_mock.disable_recursive_config_search = false
        end)
      end

      test_it("should return an error that no files were found", function(success, _, _)
        assert.is_not_true(success)
      end)
    end)
  end)

  describe("given remoteEnv", function()
    describe("fill_remote_env", function()
      local test_it = function(name, block)
        it(name, function()
          local remoteEnv = {
            TEST_VAR = "${containerEnv:TEST_VAR}",
            MISSING_VAR = "${containerEnv:MISSING_VAR:someOtherDefault}",
            COMBINED_VARS = "${containerEnv:COMBINED_VAR1}-${containerEnv:COMBINED_VAR2}",
          }
          local env_map = {
            TEST_VAR = "test_var_value",
            COMBINED_VAR1 = "var1_value",
            COMBINED_VAR2 = "var2_value",
          }

          local data = subject.fill_remote_env(remoteEnv, env_map)

          block(data)
        end)
      end

      test_it("should update remoteEnv with replaced variables", function(data, _)
        assert.are.same("test_var_value", data.TEST_VAR)
        assert.are.same("var1_value-var2_value", data.COMBINED_VARS)
      end)

      test_it("should use defaults for missing variables", function(data, _)
        assert.are.same("someOtherDefault", data.MISSING_VAR)
      end)
    end)
  end)
end)
