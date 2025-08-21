return {
  -- Copilot for autocomplete
  {
    'github/copilot.vim',
    config = function()
      vim.g.copilot_no_tab_map = false  -- Enable Tab for accepting suggestions
      vim.keymap.set('i', '<Tab>', 'copilot#Accept("\\<CR>")', { expr = true, silent = true })
      vim.keymap.set('i', '<Esc>', function()
        if vim.fn['copilot#GetDisplayedSuggestion']() ~= '' then
          vim.fn['copilot#Dismiss']()
          return ''
        else
          return '<Esc>'
        end
      end, { expr = true, silent = true })
    end
  },
  -- Official Claude Code integration (most advanced)
  {
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    opts = {}
  }
}