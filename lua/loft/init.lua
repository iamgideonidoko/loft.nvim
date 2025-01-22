local config = require("loft.config")
local utils = require("loft.utils")
local registry_instance = require("loft.registry")
local ui_instance = require("loft.ui")

local loft = {}

---@type fun(opts: loft.SetupConfig?)
loft.setup = function(opts)
  config.setup(opts)
  registry_instance:setup()
  ui_instance:setup({ keymaps = config.all.keymaps.ui })
  for key, value in pairs(config.all.keymaps.general) do
    local action = type(value) == "function" and value or value.callback
    local desc = type(value) == "table" and value.desc or ""
    vim.keymap.set("n", key, action, { noremap = true, silent = true, desc = desc })
  end
  if utils.is_dev() then
    require("loft.dev").create_reload_command()
  end
end

return loft
