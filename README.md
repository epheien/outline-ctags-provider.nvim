# An outline.nvim external provider for universal ctags

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

## Configuration

### Default options
```lua
  {
    providers = {
      priority = { 'lsp', 'ctags', 'coc', 'markdown', 'norg' },
      ctags = {
        -- Global kind mapping fron kind of ctags to kind of outline.nvim.
        -- See below for more detail.
        kinds = {
          prototype = 'Function',
        },
        -- Key is language of ctags with lowercase -- you can run
        -- `ctags --list-languages` to get all languages.
        -- Value is kind mapping from kind of ctags to kind of outline.nvim.
        -- The kind of ctags can be listed to run `ctags --list-kinds-full[=(language)]`,
        -- eg. `ctags --list-kinds-full=c++`
        -- The kind of outline.nvim listed in document of outline.nvim.
        filetypes = {
          ['c++'] = {
            kinds = {
              member = 'Field',
              alias = 'TypeAlias',
              ['local'] = 'Variable',
              typedef = 'TypeAlias',
              enumerator = 'Enum',
            },
          },
        },
      },
    },
  }
```

## NOTES

This plugin is far from mature. If you find any issues, please submit an issue, PR is even better.
