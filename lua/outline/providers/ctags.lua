local cfg = require('outline.config')
local kinds_index = require('outline.symbols').str_to_kind

local config = {
  -- 全局通用映射
  program = 'ctags',
  scope_sep = '.',
  kinds = {
    prototype = 'Function',
    member = 'Field',
  },
  -- key: language or ctags
  filetypes = {
    ['c++'] = {
      scope_sep = '::',
      kinds = {
        alias = 'TypeAlias',
        ['local'] = 'Variable',
        typedef = 'TypeAlias',
        enumerator = 'Enum',
      },
    },
    go = {
      kinds = {
        func = 'Function',
        talias = 'TypeAlias',
        methodSpec = 'Function',
        var = 'Variable',
        const = 'Constant',
        type = 'TypeParameter',
        packageName = 'Module',
      },
    },
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

local function ctags_kind_to_outline_kind(kind, language)
  local fallback = 'Fragment'
  if not kind then return kinds_index[fallback] end

  local filetypes = config.filetypes[string.lower(language)] or {}
  local kinds = filetypes.kinds or {}
  -- filetypes['c++'].kinds
  local outline_kind = kinds[kind]
  -- kinds
  if not outline_kind then outline_kind = config.kinds[kind] end
  -- 从隐含的隐射中寻找匹配: struct => Struct, ...
  if not outline_kind then outline_kind = capitalize(kind) end

  return kinds_index[outline_kind] or kinds_index[fallback]
end

-- tag.scopes 作为 path 从 symbols 里面寻找/生成指定的 node
local function find_node_by_scopes(symbols, tag, range)
  local node = nil
  local children = symbols
  for i, scope in ipairs(tag.scopes) do
    --local parent = node
    node = nil
    for _, child in ipairs(children) do
      if child.name == scope then
        node = child
      end
    end
    if not node then
      local kind = i == #tag.scopes and tag.scopeKind or 'struct'
      node = {
        name = scope,
        kind = ctags_kind_to_outline_kind(kind, tag.language),
        range = range,
        selectionRange = range,
        children = {},
        dummy = true, -- 标识作为 scope 添加
      }
      table.insert(children, node)
    end
    children = node.children
  end
  return node
end

-- a::b::c => {'a', 'b', 'c'}
-- TODO: 优化性能
local function split_scope(scope, language)
  local filetype = config.filetypes[string.lower(language)]
  local sep = filetype and filetype.scope_sep or config.scope_sep
  return vim.split(scope, sep, { plain = true, trimempty = true })
end

-- {"_type": "tag", "name": "MyStruct", "path": "/Users/eph/a.cpp", "pattern": "/^struct MyStruct {$/", "file": true, "kind": "struct"}
local function convert_symbols(text)
  local symbols = {}
  local tags = {}
  for line in vim.gsplit(text, "\n", { plain = true, trimempty = true }) do
    local tag = vim.json.decode(line)
    table.insert(tags, tag)
  end
  table.sort(tags, function(t1, t2)
    return t1.line < t2.line
  end)
  for _, tag in ipairs(tags) do
    local range = {
      -- line 和 character(column) 从 0 开始
      start = { line = tag.line - 1, character = 0 },
      ['end'] = { line = tag.line - 1, character = 10000 },
    }
    if tag['end'] then range['end'].line = tag['end'] - 1 end

    local symbol = {
      name = tag.name,
      kind = ctags_kind_to_outline_kind(tag.kind, tag.language),
      range = range,
      selectionRange = range,
      children = {},
      --info = tag,
    }
    if tag.typeref then symbol.detail = string.gsub(tag.typeref, 'typename:', '', 1) end
    if tag.signature then symbol.detail = tag.signature end

    if tag.scope then
      tag.scopes = split_scope(tag.scope, tag.language)
      local node = find_node_by_scopes(symbols, tag, symbol.range)
      table.insert(node.children, symbol)
    else
      table.insert(symbols, symbol)
    end
  end
  --vim.fn.writefile(vim.split(vim.json.encode(symbols), '\n'), 'xxx.json')
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
    '--fields=*',
    vim.fn.expand('%:p'),
  }, { text = true }, on_exit)
end

return M
