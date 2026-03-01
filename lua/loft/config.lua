local actions = require("loft.actions")

---@alias loft.UIKeymapsActions 'move_up'|'move_down'|'move_entry_up'|'move_entry_down'|'delete_entry'|'force_delete_entry'|'select_entry'|'close'|'toggle_mark_entry'|'toggle_smart_order'|'show_help'|'move_up_to_marked_entry'|'move_down_to_marked_entry'
---@alias loft.UIKeymapsConfig table<string, loft.UIKeymapsActions|function|false>
---@alias loft.UIVisualKeymapsActions 'delete_selected_entries'|'force_delete_selected_entries'
---@alias loft.UIVisualKeymapsConfig table<string, loft.UIVisualKeymapsActions|function|false>
---@alias loft.GeneralKeymapsConfig table<string, { callback: function|loft.Action, desc: string }|function|loft.Action|false> For keys mapped outside of Loft in `normal` mode

---@class (exact) loft.SetupConfig
---@field keymaps? loft.KeymapConfig
---@field close_invalid_buf_on_switch? boolean Whether to close invalid buffers when switching buffers
---@field enable_smart_order_by_default? boolean Whether to enable smart order by default
---@field smart_order_marked_bufs? boolean Whether smart order should reposition marked buffers
---@field smart_order_alt_bufs? boolean Whether smart order should reposition alternate buffer by moving it to just before the current buffer
---@field smart_order_on_window_switch? boolean Whether smart order should reorder when switching between window splits/tabs. Defaults to false.
---@field enable_recent_marked_mapping? boolean Whether the 9 most recently marked buffers should be switched to with a mapping (with keymaps)
---@field post_leader_marked_mapping? string The character to use after leader when assigning keymap to the 9 most recently marked buffers
---@field show_marked_mapping_num? boolean Whether to show the mapping number for the 9 most recently marked buffers
---@field marked_mapping_num_style? 'solid'|'outline' The style of the mapping number
---@field ui_timeout_on_curr_buf_move? integer The timeout in milliseconds to wait before closing the UI after moving the current buffer. Defaults to 800. Set to 0 to disable the UI from showing.
---@field reverse_order? boolean Whether to display the buffer list in reverse order (first registry entry at the bottom). Defaults to false.
---@field confirm_force_delete? boolean Whether to show a confirmation prompt before force-deleting buffers. Defaults to true.
---@field allow_delete_current_buffer? boolean Whether deleting the current buffer (marked ●) from the Loft UI is allowed. Defaults to true.
---@field auto_delete_missing_file_bufs? boolean Whether to automatically delete (from Neovim) buffers whose backing file no longer exists on disk. Defaults to true.
---@field exclude_buftypes? string[] List of `buftype` values whose buffers are never tracked by Loft (e.g. `{"terminal","quickfix"}`). Defaults to `{}`.
---@field open_at? 'cursor'|'top'|'current'|'middle'|'bottom' Where to position the cursor when the Loft UI opens. `cursor` restores the last cursor line, `top` goes to the first entry, `current` goes to the active buffer entry (●), `middle` goes to the middle entry, `bottom` goes to the last entry. Defaults to `"current"`.
---@field window? loft.WinOpts
---@field help_window? loft.HelpWinOpts
---@field persistence? loft.PersistenceConfig

---@class (exact) loft.PersistenceConfig
---@field enabled? boolean Whether to persist registry state across sessions (default: false)
---@field path? string Custom file path for persistence state; defaults to stdpath("data")/loft/<cwd_hash>.json

---@class (exact) loft.WinOpts
---@field width? integer|fun(height: integer, width: integer): integer Defaults to calculated width
---@field height? integer|fun(height: integer, width: integer): integer Defaults to calculated height
---@field row? integer|fun(height: integer, width: integer): integer Explicit row; overrides centered calculation
---@field col? integer|fun(height: integer, width: integer): integer Explicit col; overrides centered calculation
---@field row_offset? integer Value added to the computed row (default 0)
---@field col_offset? integer Value added to the computed col (default 0)
---@field title? string Custom title string; defaults to auto-generated Loft title
---@field title_pos? "left"|"right"|"center"
---@field footer? string Custom footer string; defaults to the smart-order indicator
---@field footer_pos? "left"|"right"|"center"
---@field zindex? integer
---@field border? "none"|"single"|"double"|"rounded"|"solid"|"shadow"|string[]

---@class (exact) loft.HelpWinOpts
---@field disable? boolean Disable the help window entirely (default false)
---@field width? integer|fun(height: integer, width: integer): integer Defaults to calculated width
---@field height? integer|fun(height: integer, width: integer): integer Defaults to calculated height
---@field row? integer|fun(height: integer, width: integer): integer Explicit row; overrides centered calculation
---@field col? integer|fun(height: integer, width: integer): integer Explicit col; overrides centered calculation
---@field row_offset? integer Value added to the computed row (default 0)
---@field col_offset? integer Value added to the computed col (default 0)
---@field border? "none"|"single"|"double"|"rounded"|"solid"|"shadow"|string[] Defaults to main window border
---@field zindex? integer Clamped to >= main window zindex + 1

---@class (exact) loft.KeymapConfig
---@field ui? loft.UIKeymapsConfig
---@field ui_visual? loft.UIVisualKeymapsConfig
---@field general? loft.GeneralKeymapsConfig

---@type loft.SetupConfig
local default_config = {
  close_invalid_buf_on_switch = true,
  enable_smart_order_by_default = true,
  smart_order_marked_bufs = false,
  smart_order_alt_bufs = true,
  smart_order_on_window_switch = false,
  enable_recent_marked_mapping = true,
  post_leader_marked_mapping = "l",
  show_marked_mapping_num = true,
  marked_mapping_num_style = "solid",
  ui_timeout_on_curr_buf_move = 800,
  reverse_order = false,
  confirm_force_delete = true,
  allow_delete_current_buffer = true,
  auto_delete_missing_file_bufs = true,
  exclude_buftypes = {},
  open_at = "current",
  window = {
    width = nil,
    height = nil,
    row = nil,
    col = nil,
    row_offset = 0,
    col_offset = 0,
    title = nil,
    title_pos = "center",
    footer = nil,
    footer_pos = "center",
    zindex = 100,
    border = "rounded",
  },
  help_window = {
    disable = false,
    width = nil,
    height = nil,
    row = nil,
    col = nil,
    row_offset = 0,
    col_offset = 0,
    border = nil,
    zindex = nil,
  },
  keymaps = {
    ui = {
      ["k"] = "move_up",
      ["j"] = "move_down",
      ["<C-k>"] = "move_entry_up",
      ["<C-j>"] = "move_entry_down",
      ["dd"] = "delete_entry",
      ["D"] = "force_delete_entry",
      ["<CR>"] = "select_entry",
      ["<Esc>"] = "close",
      ["q"] = "close",
      ["m"] = "toggle_mark_entry",
      ["<C-s>"] = "toggle_smart_order",
      ["?"] = "show_help",
      ["<M-k>"] = "move_up_to_marked_entry",
      ["<M-j>"] = "move_down_to_marked_entry",
    },
    ui_visual = {
      ["d"] = "delete_selected_entries",
      ["D"] = "force_delete_selected_entries",
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
      ["<S-M-i>"] = actions.move_buffer_up,
      ["<S-M-o>"] = actions.move_buffer_down,
    },
  },
  persistence = {
    enabled = false,
    path = nil,
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
