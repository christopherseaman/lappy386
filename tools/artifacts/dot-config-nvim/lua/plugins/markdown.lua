return {
  -- Enhanced markdown editing with smart lists, tables, and more
  {
    "bullets-vim/bullets.vim",
    ft = { "markdown", "text", "gitcommit" },
    config = function()
      vim.g.bullets_enabled_file_types = { "markdown", "text", "gitcommit" }
      vim.g.bullets_enable_in_empty_buffers = 0
      vim.g.bullets_set_mappings = 1
      vim.g.bullets_mapping_leader = ""
      vim.g.bullets_delete_last_bullet_if_empty = 1
      -- Custom bullet styles
      vim.g.bullets_outline_levels = { "ROM", "ABC", "num", "abc", "rom", "1)" }
    end,
  },

  -- Markdown table editing and formatting
  {
    "dhruvasagar/vim-table-mode",
    ft = "markdown",
    config = function()
      vim.g.table_mode_corner = "|"
      vim.g.table_mode_border = 0
      vim.g.table_mode_fillchar = " "
    end,
    keys = {
      { "<leader>tm", "<cmd>TableModeToggle<cr>", desc = "Toggle table mode" },
      { "<leader>tr", "<cmd>TableModeRealign<cr>", desc = "Realign table" },
    },
  },

  -- Markdown preview in browser
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function() vim.fn["mkdp#util#install"]() end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown preview" },
    },
  },
}