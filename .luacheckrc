std = luajit
cache = true
codes = true

-- list of warning: https://luacheck.readthedocs.io/en/stable/warnings.html
ignore = {}

globals = {}

read_globals = { "vim" }

files = {
  ["lua/loft/init.lua"] = {
    ignore = {},
  },
}
