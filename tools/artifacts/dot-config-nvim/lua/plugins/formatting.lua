return {
  -- Configure prettier for markdown with 4-space indents
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        prettier = {
          prepend_args = {
            "--tab-width", "4",
            "--print-width", "80",
            "--prose-wrap", "preserve",
          },
        },
      },
    },
  },

  -- Ensure prettier is installed
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "prettier" })
    end,
  },
}