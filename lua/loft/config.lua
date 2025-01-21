local actions = require("loft.actions")

---@alias oil.UIKeymapsActions 'move_up'|'move_down'|'move_entry_up'|'move_entry_down'|'delete_entry'|'select_entry'

---@class (exact) loft.SetupConfig
---@field  keymaps loft.KeymapConfig?

---@class (exact) loft.KeymapConfig
---@field  ui table<string, oil.UIKeymapsActions>?
---@field  general table<string, function>?

---@type loft.SetupConfig
local default_config = {
  keymaps = {
    ui = {
      ["k"] = "move_up",
      ["j"] = "move_down",
      ["<C-k>"] = "move_entry_up",
      ["<C-j>"] = "move_entry_down",
      ["<C-d>"] = "delete_entry",
      ["<CR>"] = "select_entry",
    },
    general = {
      ["<leader>l"] = actions.open_loft,
      ["<Tab>"] = actions.switch_to_next_buffer,
      ["<S-Tab>"] = actions.switch_to_next_buffer,
      ["<leader>x"] = actions.close_buffer,
      ["<leader>X"] = function()
        actions.close_buffer({ force = true })
      end,
    },
  },
}

---@class loft.Config
---@field all loft.SetupConfig?
local config = {}

---@type loft.SetupConfig
config.all = default_config

---@type fun(opts: loft.SetupConfig?)
config.setup = function(opts)
  local user_config = vim.tbl_deep_extend("keep", opts or {}, default_config)
  for k, v in pairs(user_config) do
    config.all[k] = v
  end
end

return config
