local mock = require("luassert.mock")

describe("devcontainer.internal.runtimes.helpers.common_compose:", function()
  local exe = require("devcontainer.internal.executor")
  local subject = require("devcontainer.internal.runtimes.helpers.common_compose")
  describe("given runtime with spaces", function()
    describe("up", function()
      it("should add runtime parts before arguments", function()
        local executor_mock = mock(exe, true)
        executor_mock.run_command = function(command, opts, _onexit)
          assert.are.same("docker", command)
          assert.are.same({ "compose", "-f", "docker-compose.yml", "up", "-d" }, opts.args)
        end

        subject.new({ runtime = "docker compose" }):up("docker-compose.yml", {})
      end)
    end)
  end)
end)
