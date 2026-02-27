local helper = require("loft.test_helper")

local child = helper.new_child_neovim()
local eq = helper.expect.equality

local test_set = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.setup()
      child.lua([[require("loft").setup()]])
    end,
    post_once = child.stop,
  },
  n_retry = helper.get_n_retry(1),
})

-- ── default values ─────────────────────────────────────────────────────

test_set["default close_invalid_buf_on_switch is true"] = function()
  eq(child.lua_get([[require("loft.config").all.close_invalid_buf_on_switch]]), true)
end

test_set["default enable_smart_order_by_default is true"] = function()
  eq(child.lua_get([[require("loft.config").all.enable_smart_order_by_default]]), true)
end

test_set["default smart_order_alt_bufs is true"] = function()
  eq(child.lua_get([[require("loft.config").all.smart_order_alt_bufs]]), true)
end

test_set["default smart_order_marked_bufs is false"] = function()
  eq(child.lua_get([[require("loft.config").all.smart_order_marked_bufs]]), false)
end

test_set["default enable_recent_marked_mapping is true"] = function()
  eq(child.lua_get([[require("loft.config").all.enable_recent_marked_mapping]]), true)
end

test_set["default post_leader_marked_mapping is l"] = function()
  eq(child.lua_get([[require("loft.config").all.post_leader_marked_mapping]]), "l")
end

test_set["default show_marked_mapping_num is true"] = function()
  eq(child.lua_get([[require("loft.config").all.show_marked_mapping_num]]), true)
end

test_set["default marked_mapping_num_style is solid"] = function()
  eq(child.lua_get([[require("loft.config").all.marked_mapping_num_style]]), "solid")
end

test_set["default ui_timeout_on_curr_buf_move is 800"] = function()
  eq(child.lua_get([[require("loft.config").all.ui_timeout_on_curr_buf_move]]), 800)
end

test_set["default window border is rounded"] = function()
  eq(child.lua_get([[require("loft.config").all.window.border]]), "rounded")
end

test_set["default window zindex is 100"] = function()
  eq(child.lua_get([[require("loft.config").all.window.zindex]]), 100)
end

test_set["default window title_pos is center"] = function()
  eq(child.lua_get([[require("loft.config").all.window.title_pos]]), "center")
end

test_set["default window width and height are nil"] = function()
  eq(child.lua_get([[require("loft.config").all.window.width == nil]]), true)
  eq(child.lua_get([[require("loft.config").all.window.height == nil]]), true)
end

-- ── user overrides ─────────────────────────────────────────────────────

test_set["setup overrides close_invalid_buf_on_switch"] = function()
  child.lua([[require("loft").setup({ close_invalid_buf_on_switch = false })]])
  eq(child.lua_get([[require("loft.config").all.close_invalid_buf_on_switch]]), false)
end

test_set["setup overrides enable_smart_order_by_default"] = function()
  child.lua([[require("loft").setup({ enable_smart_order_by_default = false })]])
  eq(child.lua_get([[require("loft.config").all.enable_smart_order_by_default]]), false)
end

test_set["setup overrides post_leader_marked_mapping"] = function()
  child.lua([[require("loft").setup({ post_leader_marked_mapping = "b" })]])
  eq(child.lua_get([[require("loft.config").all.post_leader_marked_mapping]]), "b")
end

test_set["setup overrides marked_mapping_num_style to outline"] = function()
  child.lua([[require("loft").setup({ marked_mapping_num_style = "outline" })]])
  eq(child.lua_get([[require("loft.config").all.marked_mapping_num_style]]), "outline")
end

test_set["setup overrides ui_timeout_on_curr_buf_move"] = function()
  child.lua([[require("loft").setup({ ui_timeout_on_curr_buf_move = 0 })]])
  eq(child.lua_get([[require("loft.config").all.ui_timeout_on_curr_buf_move]]), 0)
end

test_set["setup overrides show_marked_mapping_num to false"] = function()
  child.lua([[require("loft").setup({ show_marked_mapping_num = false })]])
  eq(child.lua_get([[require("loft.config").all.show_marked_mapping_num]]), false)
end

test_set["setup deep merges window opts keeping unspecified defaults"] = function()
  child.lua([[require("loft").setup({ window = { border = "double" } })]])
  eq(child.lua_get([[require("loft.config").all.window.border]]), "double")
  -- unspecified window fields remain at default
  eq(child.lua_get([[require("loft.config").all.window.zindex]]), 100)
  eq(child.lua_get([[require("loft.config").all.window.title_pos]]), "center")
end

test_set["setup with empty opts keeps all defaults"] = function()
  child.lua([[require("loft").setup({})]])
  eq(child.lua_get([[require("loft.config").all.close_invalid_buf_on_switch]]), true)
  eq(child.lua_get([[require("loft.config").all.enable_smart_order_by_default]]), true)
  eq(child.lua_get([[require("loft.config").all.window.border]]), "rounded")
end

-- ── general keymap false-skip bug regression ───────────────────────────

test_set["setting one general keymap to false does not prevent other keymaps from registering"] = function()
  -- Before the fix, `return` inside the loop would abort ALL remaining keymaps
  -- the moment any entry was false. Verify the other keymap is still registered.
  child.lua([[
    require("loft").setup({
      keymaps = {
        general = {
          ["<leader>lx"] = false,
          ["<leader>lt"] = require("loft.actions").open_loft,
        },
      },
    })
  ]])
  -- vim.fn.maparg expands <leader> so it matches the stored keymap (e.g. \lt)
  local result = child.lua_get([[vim.fn.maparg("<leader>lt", "n")]])
  eq(result ~= "", true)
end

test_set["setting multiple general keymaps to false leaves them all unregistered"] = function()
  child.lua([[
    require("loft").setup({
      keymaps = {
        general = {
          ["<leader>lx"] = false,
          ["<leader>ly"] = false,
        },
      },
    })
  ]])
  eq(child.lua_get([[vim.fn.maparg("<leader>lx", "n")]]), "")
  eq(child.lua_get([[vim.fn.maparg("<leader>ly", "n")]]), "")
end

return test_set
