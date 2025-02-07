local actions = require("loft.actions")

---@alias loft.UIKeymapsActions 'move_up'|'move_down'|'move_entry_up'|'move_entry_down'|'delete_entry'|'select_entry'|'close'|'toggle_mark_entry'|'toggle_smart_order'|'show_help'|'move_up_to_marked_entry'|'move_down_to_marked_entry'
---@alias loft.UIKeymapsConfig table<string, loft.UIKeymapsActions|function|false>
---@alias loft.GeneralKeymapsConfig table<string, { callback: function|loft.Action, desc: string }|function|loft.Action|false> For keys mapped outside of Loft in `normal` mode

---@class (exact) loft.SetupConfig
---@field keymaps? loft.KeymapConfig
---@field move_curr_buf_on_telescope_select? boolean Whether to move the current buffer to the last of the registry during Telescope selection just before the selected buffer
---@field close_invalid_buf_on_switch? boolean Whether to close invalid buffers when switching buffers
---@field enable_smart_order_by_default? boolean Whether to enable smart order by default
---@field smart_order_marked_bufs? boolean Whether smart order should reposition marked buffers
---@field enable_recent_marked_mapping? boolean Whether the 9 most recently marked buffers should be switched to with a mapping (with keymaps)
---@field post_leader_marked_mapping? string The character to use after leader when assigning keymap to the 9 most recently marked buffers
---@field show_marked_mapping_num? boolean Whether to show the mapping number for the 9 most recently marked buffers
---@field window? loft.WinOpts

---@class (exact) loft.WinOpts
---@field width? integer Defaults to calculated width
---@field height? integer Defaults to calculated height
---@field zindex? integer
---@field title_pos? "left"|"right"|"center"
---@field border? "none"|"single"|"double"|"rounded"|"solid"|"shadow"|string[]

---@class (exact) loft.KeymapConfig
---@field ui? loft.UIKeymapsConfig
---@field general? loft.GeneralKeymapsConfig

---@type loft.SetupConfig
local default_config = {
  move_curr_buf_on_telescope_select = true,
  close_invalid_buf_on_switch = true,
  enable_smart_order_by_default = true,
  smart_order_marked_bufs = false,
  enable_recent_marked_mapping = true,
  post_leader_marked_mapping = "l",
  show_marked_mapping_num = true,
  window = {
    width = nil,
    height = nil,
    zindex = 100,
    title_pos = "center",
    border = "rounded",
  },
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
      ["<C-s>"] = "toggle_smart_order",
      ["?"] = "show_help",
      ["<M-k>"] = "move_up_to_marked_entry",
      ["<M-j>"] = "move_down_to_marked_entry",
    },
    general = {
      ["<leader>lf"] = actions.open_loft,
      ["<Tab>"] = actions.switch_to_next_buffer,
      ["<S-Tab>"] = actions.switch_to_prev_buffer,
      ["<leader>x"] = actions.close_buffer,
      ["<leader>X"] = {
        callback = function()
          actions.close_buffer({ force = true })
        end,
        desc = "Force close buffer",
      },
      ["<leader>ln"] = actions.switch_to_next_marked_buffer,
      ["<leader>lp"] = actions.switch_to_prev_marked_buffer,
      ["<leader>lm"] = actions.toggle_mark_current_buffer,
      ["<leader>ls"] = actions.toggle_smart_order,
      ["<leader>la"] = actions.switch_to_alt_buffer,
    },
  },
}

---@class loft.Config
---@field all? loft.SetupConfig
local config = {}

---@type loft.SetupConfig
config.all = default_config

---@type fun(opts?: loft.SetupConfig)
config.setup = function(opts)
  local user_config = vim.tbl_deep_extend("keep", opts or {}, default_config)
  for k, v in pairs(user_config) do
    config.all[k] = v
  end
end

return config
