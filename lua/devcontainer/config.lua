---@mod devcontainer.config Devcontainer plugin config module
---@brief [[
---Provides current devcontainer plugin configuration
---Don't change directly, use `devcontainer.setup{}` instead
---Can be used for read-only access
---@brief ]]

local M = {}

local function default_terminal_handler(command)
	local laststatus = vim.o.laststatus
	vim.cmd("tabnew")
	local bufnr = vim.api.nvim_get_current_buf()
	vim.o.laststatus = 0
	local au_id = vim.api.nvim_create_augroup("devcontainer.docker.terminal", {})
	vim.api.nvim_create_autocmd("BufEnter", {
		buffer = bufnr,
		group = au_id,
		callback = function()
			vim.o.laststatus = 0
		end,
	})
	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = bufnr,
		group = au_id,
		callback = function()
			vim.o.laststatus = laststatus
		end,
	})
	vim.api.nvim_create_autocmd("BufDelete", {
		buffer = bufnr,
		group = au_id,
		callback = function()
			vim.o.laststatus = laststatus
			vim.api.nvim_del_augroup_by_id(au_id)
		end,
	})
	vim.fn.termopen(command)
end

local function default_nvim_dockerfile_template(base_image)
	-- Use current version by default
	local nver = vim.version()
	local version_string = "v" .. nver.major .. "." .. nver.minor .. "." .. nver.patch
	local lines = {
		"FROM " .. base_image,
		"RUN apt-get update && apt-get -y install " .. table.concat({
			"curl",
			"fzf",
			"ripgrep",
			"tree",
			"git",
			"xclip",
			"python3",
			"python3-pip",
			"nodejs",
			"npm",
			"tzdata",
			"ninja-build",
			"gettext",
			"libtool",
			"libtool-bin",
			"autoconf",
			"automake",
			"cmake",
			"g++",
			"pkg-config",
			"zip",
			"unzip",
		}, " "),
		"RUN pip3 install pynvim",
		"RUN npm i -g neovim",
		"RUN mkdir -p /root/TMP",
		"RUN cd /root/TMP && git clone https://github.com/neovim/neovim",
		"RUN cd /root/TMP/neovim && (git checkout " .. version_string .. " || true) && make -j4 && make install",
		"RUN rm -rf /root/TMP",
		"RUN mkdir -p /root/config/nvim",
	}
	return table.concat(lines, "\n")
end

local function workspace_folder_provider()
	return vim.lsp.buf.list_workspace_folders()[1] or vim.loop.cwd()
end

local function default_config_search_start()
	return vim.loop.cwd()
end

---Handles terminal requests (mainly used for attaching to container)
---By default it uses terminal command
---@param command string command to run in terminal
---@type function
M.terminal_handler = default_terminal_handler

---Handles terminal requests (mainly used for attaching to container)
---By default it uses a template which installs neovim from source
---@param base_image string base_image to be used in Dockerfile template (to fill in FROM line)
---@type function
M.nvim_dockerfile_template = default_nvim_dockerfile_template

---Provides docker build path
---By default uses first LSP workplace folder or vim.loop.cwd()
---@type function
M.workspace_folder_provider = workspace_folder_provider

---Provides starting search path for .devcontainer.json
---After this search moves up until root
---By default it uses vim.loop.cwd()
---@type function
M.config_search_start = default_config_search_start

---@alias log_level
---| '"trace"'
---| '"debug"'
---| '"info"'
---| '"warn"'
---| '"error"'
---| '"fatal"'

---Current log level
---@type log_level
M.log_level = "info"

return M
