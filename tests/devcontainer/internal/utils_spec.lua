local mock = require("luassert.mock")

describe("devcontainer.internal.utils:", function()
  local subject = require("devcontainer.internal.utils")
  local plugin_config = require("devcontainer.config")

  describe("get_image_cache_tag", function()
    local mock_workspace_folder = function(folder)
      local plugin_config_mock = mock(plugin_config, true)
      plugin_config_mock.workspace_folder_provider = function()
        return folder
      end
    end

    it("should replace slashes", function()
      mock_workspace_folder("/home/nvim/test")
      assert.are.same("nvim_dev_container_homenvimtest", subject.get_image_cache_tag())
    end)

    it("should replace backslashes", function()
      mock_workspace_folder("\\test\\dir")
      assert.are.same("nvim_dev_container_testdir", subject.get_image_cache_tag())
    end)

    it("should replace colons", function()
      mock_workspace_folder("D:\\test\\dir")
      assert.are.same("nvim_dev_container_dtestdir", subject.get_image_cache_tag())
    end)
  end)
end)
