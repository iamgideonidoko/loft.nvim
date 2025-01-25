local actions = require("loft.actions")

---@alias loft.UIKeymapsActions 'move_up'|'move_down'|'move_entry_up'|'move_entry_down'|'delete_entry'|'select_entry'|'close'|'toggle_mark_entry'
---@alias loft.UIKeymapsConfig table<string, loft.UIKeymapsActions|function|false>
---@alias  loft.GeneralKeymapsConfig table<string, { callback: function, desc: string }|function|false>: For keys mapped outside of Loft in `normal` mode

---@class (exact) loft.SetupConfig
---@field  keymaps loft.KeymapConfig?

---@class (exact) loft.KeymapConfig
---@field  ui loft.UIKeymapsConfig?
---@field  general loft.GeneralKeymapsConfig?

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
      ["<Esc>"] = "close",
      ["q"] = "close",
      ["x"] = "toggle_mark_entry",
    },
    general = {
      ["<leader>l"] = { callback = actions.open_loft, desc = "Open Loft" },
      ["<Tab>"] = actions.switch_to_next_buffer,
      ["<S-Tab>"] = actions.switch_to_prev_buffer,
      ["<leader>x"] = { callback = actions.close_buffer, desc = "Close buffer" },
      ["<leader>X"] = {
        callback = function()
          actions.close_buffer({ force = true })
        end,
        desc = "Force close buffer",
      },
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
