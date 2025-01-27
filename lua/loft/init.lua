local config = require("loft.config")
local utils = require("loft.utils")
local registry_instance = require("loft.registry")
local ui_instance = require("loft.ui")
local autocmds = require("loft.autocmds")
local commands = require("loft.commands")

local loft = {}

---@param keymaps loft.GeneralKeymapsConfig
local function setup_general_keymap(keymaps)
  for key, value in pairs(keymaps) do
    if value == false then
      return
    end
    local action = (type(value) == "function" or value["func"]) and value or value.callback
    local desc = type(value) == "table" and value.desc or ""
    vim.keymap.set("n", key, function()
      action()
    end, { noremap = true, silent = true, desc = desc })
  end
end

---@param opts loft.SetupConfig?
loft.setup = function(opts)
  config.setup(opts)
  registry_instance:setup({
    track_telescope_select = config.all.move_curr_buf_on_telescope_select,
    close_invalid_buf_on_switch = config.all.close_invalid_buf_on_switch,
    enable_smart_order_by_default = config.all.enable_smart_order_by_default,
  })
  ui_instance:setup({
    keymaps = config.all.keymaps.ui,
    general_keymaps = config.all.keymaps.general,
    window = config.all.window,
  })
  setup_general_keymap(config.all.keymaps.general)
  autocmds.setup()
  commands.setup()
  if utils.is_dev() then
    require("loft.dev").create_reload_command()
  end
end

return loft
