std = luajit
cache = true
codes = true

-- list of warning: https://luacheck.readthedocs.io/en/stable/warnings.html
ignore = {}

globals = {}

read_globals = { "vim", "MiniTest" }

files = {
  ["lua/loft/registry.lua"] = {
    ignore = { "631" },
  },
  ["lua/loft/config.lua"] = {
    ignore = { "631" },
  },
}
