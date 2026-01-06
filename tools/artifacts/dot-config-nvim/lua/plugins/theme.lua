-- lua/plugins/theme.lua

return {
  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 1000,
    config = function()
      require("github-theme").setup({
        groups = {
          github_dark_high_contrast = {
            Normal = { bg = "#000000", fg = "#FFFFFF" },
          },
        },
      })
      vim.cmd("colorscheme github_dark_high_contrast")
    end,
  },
}
