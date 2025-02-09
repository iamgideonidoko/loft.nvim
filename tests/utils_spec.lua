local helper = require("loft.test_helper")
local utils = require("loft.utils")

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

test_set["is_floating_window"] = function()
  child.lua([[vim.cmd("new")]])
  local win = child.api.nvim_get_current_win()
  eq(child.lua_get([[require("loft.utils").is_floating_window()]]), false)
  child.api.nvim_win_set_config(win, { relative = "editor", row = 1, col = 1, width = 1, height = 1 })
  eq(child.lua_get([[require("loft.utils").is_floating_window()]]), true)
end

test_set["merge_distinct"] = function()
  eq(utils.merge_distinct({ 1, 2, 3 }, { 2, 3, 4 }), { 1, 2, 3, 4 })
end

test_set["get_index"] = function()
  local list = { 1, 2, 3 }
  eq(utils.get_index(list, 2), 2)
  eq(utils.get_index(list, 4), nil)
end

test_set["table_includes"] = function()
  local list = { 1, 2, 3 }
  eq(utils.table_includes(list, 2), true)
  eq(utils.table_includes(list, 4), false)
end

test_set["buffer_exists"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  eq(child.lua_get([[require("loft.utils").buffer_exists(]] .. buf .. [[)]]), true)
  child.api.nvim_buf_delete(buf, { force = true })
  eq(child.lua_get([[require("loft.utils").buffer_exists(]] .. buf .. [[)]]), false)
end

test_set["buffer_modifiable"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.utils").buffer_modifiable(]] .. buf .. [[, false)]])
  eq(child.api.nvim_buf_get_option(buf, "modifiable"), false)
  child.lua([[require("loft.utils").buffer_modifiable(]] .. buf .. [[, true)]])
  eq(child.api.nvim_buf_get_option(buf, "modifiable"), true)
end

return test_set
