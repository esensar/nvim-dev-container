set rtp=.,../plenary.nvim,../nvim-treesitter,$VIMRUNTIME

runtime! plugin/plenary.vim
runtime! plugin/nvim-treesitter.vim

lua << EOF
require'nvim-treesitter.configs'.setup {
  ensure_installed = { "json" },
  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = true,
}

-- Changing path_sep for tests - for Windows tests compatibility
require("devcontainer.internal.utils").path_sep = "/"
EOF

function! StatusLine()
  lua << EOF
local build_status_last = require("devcontainer.status").find_build({ running = true })
if build_status_last then
  local status
  status =
  (build_status_last.build_title or "")
  .. "["
  .. (build_status_last.current_step or "")
  .. "/"
  .. (build_status_last.step_count or "")
  .. "]"
  .. (build_status_last.progress and "(" .. build_status_last.progress .. "%%)" or "")
  vim.g.mystatus = status
else
  vim.g.mystatus = "NONE"
end
EOF
  return g:mystatus
endfunction

function! SetupStatusLineAutocommand()
  set statusline=%!StatusLine()
  autocmd User DevcontainerBuildProgress redrawstatus
endfunction
