local cfg = require('outline.config')
local kinds_index = require('outline.symbols').str_to_kind

local config = {
  -- 全局通用映射
  program = 'ctags',
  kinds = {
    prototype = 'Function',
  },
  -- key: language or ctags
  filetypes = {
    ['c++'] = {
      kinds = {
        member = 'Field',
        alias = 'TypeAlias',
        ['local'] = 'Variable',
        typedef = 'TypeAlias',
        enumerator = 'Enum',
      },
    }
  }
}

config = vim.tbl_deep_extend('force', config, cfg.o.providers.ctags or {})

local M = {
  name = 'ctags',
}

function M.supports_buffer(bufnr, conf)
  return vim.api.nvim_buf_get_name(bufnr) ~= ''
end

local function capitalize(str)
    return (str:sub(1,1):upper() .. str:sub(2))
end

local function ctags_kind_to_outline_kind(tag)
  local kind = tag.kind
  local fallback = 'Fragment'
  if not kind then return kinds_index[fallback] end

  local filetypes = config.filetypes[string.lower(tag.language)] or {}
  local kinds = filetypes.kinds or {}
  -- filetypes['c++'].kinds
  local outline_kind = kinds[kind]
  -- kinds
  if not outline_kind then outline_kind = config.kinds[kind] end
  -- 从隐含的隐射中寻找匹配: struct => Struct, ...
  if not outline_kind then outline_kind = capitalize(kind) end

  return kinds_index[outline_kind] or kinds_index[fallback]
end

-- {"_type": "tag", "name": "MyStruct", "path": "/Users/eph/a.cpp", "pattern": "/^struct MyStruct {$/", "file": true, "kind": "struct"}
local function convert_symbols(text)
  local symbols = {}
  local structs = {}
  for line in vim.gsplit(text, "\n", { plain = true, trimempty = true }) do
    local tag = vim.json.decode(line)
    local range = {
      -- line 和 character(column) 从 0 开始
      start = { line = tag.line - 1, character = 0 },
      ['end'] = { line = tag.line - 1, character = 10000 },
    }
    if tag['end'] then range['end'].line = tag['end'] - 1 end

    local symbol = {
      name = tag.name,
      kind = ctags_kind_to_outline_kind(tag),
      range = range,
      selectionRange = range,
      children = {},
    }
    if tag.kind == 'struct' then
      structs[tag.name] = symbol
    end
    if tag.scope and structs[tag.scope] then
      --print(vim.inspect(symbols))
      table.insert(structs[tag.scope].children, symbol)
    else
      table.insert(symbols, symbol)
    end
  end
  return symbols
end

function M.request_symbols(on_symbols, opts)
  local on_exit = function(obj)
    vim.schedule(function()
      if (obj.code ~= 0) then
        print(string.format("ctags occur error %d: %s"), obj.code, obj.stderr)
        return
      end
      on_symbols(convert_symbols(obj.stdout))
    end)
  end
  vim.system({
    config.program,
    '--output-format=json',
    '--fields=+neaZ{language}',
    vim.fn.expand('%:p'),
  }, { text = true }, on_exit)
end

return M
