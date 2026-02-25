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

test_set["switch_to_next_buffer navigates to next"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  -- Registry: [initial, buf1, buf2]. Current = initial (index 1). Next = buf1.
  child.lua([[require("loft.actions").switch_to_next_buffer()]])
  eq(child.lua_get([[vim.api.nvim_get_current_buf()]]), buf1)
end

test_set["switch_to_next_buffer wraps to first"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.api.nvim_set_current_buf(buf1)
  -- buf1 is now last. next wraps to first.
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  child.lua([[require("loft.actions").switch_to_next_buffer()]])
  eq(child.lua_get([[vim.api.nvim_get_current_buf()]]), registry[1])
end

test_set["switch_to_prev_buffer navigates to prev"] = function()
  child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  -- Registry: [initial, buf1, buf2]. Current = initial (index 1). Prev wraps to last = buf2.
  child.lua([[require("loft.actions").switch_to_prev_buffer()]])
  eq(child.lua_get([[vim.api.nvim_get_current_buf()]]), buf2)
end

test_set["switch_to_prev_buffer navigates backward"] = function()
  child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.api.nvim_set_current_buf(buf2)
  -- buf2 is last after switch. prev = second-to-last.
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  child.lua([[require("loft.actions").switch_to_prev_buffer()]])
  eq(child.lua_get([[vim.api.nvim_get_current_buf()]]), registry[#registry - 1])
end

test_set["close_buffer deletes the buffer"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.api.nvim_set_current_buf(buf1)
  child.lua([[require("loft.actions").close_buffer()]])
  eq(child.api.nvim_buf_is_valid(buf1), false)
end

test_set["close_buffer switches away from closed buffer"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.api.nvim_set_current_buf(buf1)
  child.lua([[require("loft.actions").close_buffer()]])
  eq(child.lua_get([[vim.api.nvim_get_current_buf()]]) ~= buf1, true)
end

test_set["close_buffer refuses modified buffer without force"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(buf)
  child.lua([[vim.api.nvim_set_option_value("modified", true, { buf = ]] .. buf .. [[ })]])
  child.lua([[require("loft.actions").close_buffer()]])
  eq(child.api.nvim_buf_is_valid(buf), true)
end

test_set["close_buffer force closes modified buffer"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.api.nvim_set_current_buf(buf)
  child.lua([[vim.api.nvim_set_option_value("modified", true, { buf = ]] .. buf .. [[ })]])
  child.lua([[require("loft.actions").close_buffer({ force = true })]])
  eq(child.api.nvim_buf_is_valid(buf), false)
end

test_set["toggle_mark_current_buffer marks current buffer"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(buf)
  child.lua([[require("loft.actions").toggle_mark_current_buffer({ notify = false })]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
end

test_set["toggle_mark_current_buffer unmarks current buffer"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(buf)
  child.lua([[require("loft.actions").toggle_mark_current_buffer({ notify = false })]])
  child.lua([[require("loft.actions").toggle_mark_current_buffer({ notify = false })]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), false)
end

test_set["switch_to_next_marked_buffer navigates to marked"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf1 .. [[)]])
  child.api.nvim_set_current_buf(buf2)
  child.lua([[require("loft.actions").switch_to_next_marked_buffer()]])
  eq(child.lua_get([[vim.api.nvim_get_current_buf()]]), buf1)
end

test_set["switch_to_next_marked_buffer does nothing when none marked"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local current = child.lua_get([[vim.api.nvim_get_current_buf()]])
  child.lua([[require("loft.actions").switch_to_next_marked_buffer()]])
  eq(child.lua_get([[vim.api.nvim_get_current_buf()]]), current)
end

test_set["switch_to_prev_marked_buffer navigates to marked"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf1 .. [[)]])
  child.api.nvim_set_current_buf(buf2)
  child.lua([[require("loft.actions").switch_to_prev_marked_buffer()]])
  eq(child.lua_get([[vim.api.nvim_get_current_buf()]]), buf1)
end

test_set["switch_to_alt_buffer switches to alternate"] = function()
  -- :e # requires named files; open two existing files to exercise it properly
  child.lua([[vim.cmd("e scripts/minimal_init.vim")]])
  local buf_a = child.lua_get([[vim.api.nvim_get_current_buf()]])
  child.lua([[vim.cmd("e scripts/test_setup.lua")]])
  -- alternate is now buf_a (scripts/minimal_init.vim)
  child.lua([[require("loft.actions").switch_to_alt_buffer()]])
  eq(child.lua_get([[vim.api.nvim_get_current_buf()]]), buf_a)
end

test_set["toggle_smart_order changes state"] = function()
  local initial = child.lua_get([[require("loft.registry"):is_smart_order_on()]])
  child.lua([[require("loft.actions").toggle_smart_order({ notify = false })]])
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), not initial)
end

test_set["move_buffer_up reorders registry"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.api.nvim_set_current_buf(buf1)
  -- buf1 is last after smart-order update
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  local len = #before
  child.lua([[require("loft.actions").move_buffer_up()]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[len - 1], before[len])
  eq(after[len], before[len - 1])
  child.lua([[require("loft.ui"):close()]])
end

test_set["move_buffer_down reorders registry"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  -- current = initial (first buffer); move_buffer_down swaps it with the next
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  child.lua([[require("loft.actions").move_buffer_down()]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[1], before[2])
  eq(after[2], before[1])
  child.lua([[require("loft.ui"):close()]])
end

test_set["open_loft opens the UI"] = function()
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.actions").open_loft()]])
  eq(child.lua_get([[require("loft.ui"):is_open()]]), true)
  child.lua([[require("loft.ui"):close()]])
end

return test_set
