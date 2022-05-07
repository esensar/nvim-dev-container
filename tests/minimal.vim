set rtp+=.
set rtp+=../plenary.nvim
set rtp+=../nvim-treesitter

runtime! plugin/plenary.vim
runtime! plugin/nvim-treesitter.vim

lua << EOF
require'nvim-treesitter.configs'.setup {
  ensure_installed = { "jsonc" },
  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = true,
}
EOF
