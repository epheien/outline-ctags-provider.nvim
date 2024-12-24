# A outline.nvim external provider for universal ctags

A Lazy.nvim example to use this provider.

```lua
  {
    'hedyhli/outline.nvim',
    config = function()
      require('outline').setup({
        providers = {
          priority = { 'lsp', 'coc', 'markdown', 'norg', 'ctags' },
        },
      })
    end,
    event = "VeryLazy",
    dependencies = {
      'epheien/outline-ctags-provider.nvim'
    }
  },
```
