-- ~/.config/nvim/lua/plugins/github-theme.lua
return {
  "projekt0n/github-nvim-theme",
  lazy = false, -- Load during startup
  priority = 1000, -- Ensure it loads before other plugins
  config = function()
    require('github-theme').setup({
      -- Optional: customize theme options
    })
    vim.cmd('colorscheme github_dark_high_contrast')
  end,
}
