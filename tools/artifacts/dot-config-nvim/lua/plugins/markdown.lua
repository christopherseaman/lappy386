return {
  -- Markdown concealing for prettier display
  {
    "preservim/vim-markdown",
    ft = "markdown",
    config = function()
      vim.g.vim_markdown_folding_disabled = 1
      vim.g.vim_markdown_conceal = 0
      vim.g.vim_markdown_conceal_code_blocks = 0
      vim.g.vim_markdown_math = 1
      vim.g.vim_markdown_frontmatter = 1
      vim.g.vim_markdown_strikethrough = 1
      vim.g.vim_markdown_autowrite = 1
      vim.g.vim_markdown_edit_url_in = "tab"
      vim.g.vim_markdown_follow_anchor = 1
    end,
  },

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
      --    vim.g.table_mode_fillchar = " "
    end,
    keys = {
      { "<leader>tm", "<cmd>TableModeToggle<cr>", desc = "Toggle table mode" },
      { "<leader>tr", "<cmd>TableModeRealign<cr>", desc = "Realign table" },
    },
  },

  -- Markdown preview in browser
  -- {
  --   "iamcco/markdown-preview.nvim",
  --   cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  --   ft = { "markdown" },
  --   build = "cd app && npx --yes yarn install",
  --   config = function()
  --     vim.g.mkdp_auto_start = 0
  --     vim.g.mkdp_auto_close = 1
  --     vim.g.mkdp_refresh_slow = 0
  --     vim.g.mkdp_browser = ""
  --     vim.g.mkdp_markdown_css = ""
  --     vim.g.mkdp_theme = "dark"
  --     vim.g.mkdp_highlight_css = ""
  --     vim.g.mkdp_port = ""
  --     vim.g.mkdp_page_title = "「${name}」"
  --     vim.g.mkdp_filetypes = { "markdown" }
  --   end,
  --   keys = {
  --     { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown preview" },
  --   },
  -- },
}
