local helper = require("loft.test_helper")

local child = helper.new_child_neovim()
local eq, expect = helper.expect.equality, helper.expect

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

test_set["cleaning the registry adds all buffers"] = function()
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.registry"):clean()]])
  eq(child.lua_get([[#require("loft.registry"):get_registry()]]), 2)
end

test_set["navigation to buffer adds buffers correctly"] = function()
  local buf = child.api.nvim_create_buf(true, true)
  child.api.nvim_set_current_buf(buf)
  eq(child.lua_get([[#require("loft.registry"):get_registry()]]), 2)
end

test_set["marks buffer correctly"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
end

test_set["removes invalid buffers"] = function()
  child.api.nvim_create_buf(true, false)
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):_update(]] .. buf .. [[)]])
  child.api.nvim_buf_delete(buf, { force = true })
  child.lua([[require("loft.registry"):clean()]])
  eq(child.lua_get([[#require("loft.registry"):get_registry()]]), 2)
end

test_set["maintains smart order"] = function()
  local buf = child.api.nvim_get_current_buf()
  local buf1 = child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):_update(]] .. buf1 .. [[)]])
  child.lua([[require("loft.registry"):_update(]] .. buf2 .. [[)]])
  child.lua([[require("loft.registry"):_update(]] .. buf1 .. [[)]])
  eq(child.lua_get([[require("loft.registry"):get_registry()]]), { buf, buf2, buf1 })
end

test_set["handles invalid input gracefully"] = function()
  expect.no_error(function()
    child.lua([[require("loft.registry"):_update(nil)]])
  end)
  expect.error(function()
    child.lua([[require("loft.registry"):toggle_mark_buffer(nil)]])
  end)
end

test_set["get_next_buffer navigates forward"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  -- Registry: [initial, buf1], current = initial (index 1)
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local next_buf = child.lua_get([[require("loft.registry"):get_next_buffer()]])
  eq(next_buf, registry[2])
end

test_set["get_next_buffer wraps to first"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.api.nvim_set_current_buf(buf1)
  -- buf1 is now last due to smart order; next should wrap to first
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local next_buf = child.lua_get([[require("loft.registry"):get_next_buffer()]])
  eq(next_buf, registry[1])
end

test_set["get_prev_buffer wraps to last"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  -- current = initial (first), prev should wrap to last
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local prev_buf = child.lua_get([[require("loft.registry"):get_prev_buffer()]])
  eq(prev_buf, registry[#registry])
end

test_set["get_prev_buffer navigates backward"] = function()
  child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.api.nvim_set_current_buf(buf2)
  -- buf2 is last in registry after smart-order update; prev = second-to-last
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local prev_buf = child.lua_get([[require("loft.registry"):get_prev_buffer()]])
  eq(prev_buf, registry[#registry - 1])
end

test_set["move_buffer_up swaps with previous"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  local len = #before
  child.lua([[require("loft.registry"):move_buffer_up(]] .. len .. [[, false)]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[len - 1], before[len])
  eq(after[len], before[len - 1])
end

test_set["move_buffer_up cyclic from first to last"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  child.lua([[require("loft.registry"):move_buffer_up(1, true)]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[#after], before[1])
end

test_set["move_buffer_down swaps with next"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  child.lua([[require("loft.registry"):move_buffer_down(1, false)]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[1], before[2])
  eq(after[2], before[1])
end

test_set["move_buffer_down cyclic from last to first"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  local len = #before
  child.lua([[require("loft.registry"):move_buffer_down(]] .. len .. [[, true)]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[1], before[len])
end

test_set["toggle_mark_buffer unmarks buffer"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), false)
end

test_set["get_marked_buffer returns next marked"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf1 .. [[)]])
  child.api.nvim_set_current_buf(buf2)
  local next_marked = child.lua_get([[require("loft.registry"):get_marked_buffer("next")]])
  eq(next_marked, buf1)
end

test_set["get_marked_buffer returns nil when none marked"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local has_result = child.lua_get([[require("loft.registry"):get_marked_buffer("next") ~= nil]])
  eq(has_result, false)
end

test_set["get_marked_buffer returns prev marked"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf1 .. [[)]])
  child.api.nvim_set_current_buf(buf2)
  local prev_marked = child.lua_get([[require("loft.registry"):get_marked_buffer("prev")]])
  eq(prev_marked, buf1)
end

test_set["is_smart_order_on default true"] = function()
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), true)
end

test_set["toggle_smart_order changes state"] = function()
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), true)
  child.lua([[require("loft.registry"):toggle_smart_order()]])
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), false)
  child.lua([[require("loft.registry"):toggle_smart_order()]])
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), true)
end

test_set["get_marked_buffer_keymap_index returns correct index"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  -- Mark buf1 first, then buf2; buf2 is most recent → index 1
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf1 .. [[)]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf2 .. [[)]])
  eq(child.lua_get([[require("loft.registry"):get_marked_buffer_keymap_index(]] .. buf2 .. [[)]]), 1)
  eq(child.lua_get([[require("loft.registry"):get_marked_buffer_keymap_index(]] .. buf1 .. [[)]]), 2)
end

test_set["get_marked_buffer_keymap_index returns nil for unmarked"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local result = child.lua_get([[require("loft.registry"):get_marked_buffer_keymap_index(]] .. buf .. [[) ~= nil]])
  eq(result, false)
end

test_set["pause_update prevents smart order reordering"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  child.lua([[require("loft.registry"):pause_update()]])
  child.api.nvim_set_current_buf(buf1)
  local during = child.lua_get([[require("loft.registry"):get_registry()]])
  child.lua([[require("loft.registry"):resume_update()]])
  eq(during, before)
end

test_set["keymap_recent_marked_buffers sets keymap for marked buffer"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  child.lua([[require("loft.registry"):keymap_recent_marked_buffers()]])
  eq(child.lua_get([[vim.fn.mapcheck("<leader>l1", "n") ~= ""]]), true)
end

test_set["keymap_recent_marked_buffers clears keymaps when all unmarked"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  child.lua([[require("loft.registry"):keymap_recent_marked_buffers()]])
  -- Unmark the buffer
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  child.lua([[require("loft.registry"):keymap_recent_marked_buffers()]])
  eq(child.lua_get([[vim.fn.mapcheck("<leader>l1", "n")]]), "")
end

test_set["keymap_recent_marked_buffers does nothing when disabled"] = function()
  child.lua([[require("loft").setup({ enable_recent_marked_mapping = false })]])
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  child.lua([[require("loft.registry"):keymap_recent_marked_buffers()]])
  eq(child.lua_get([[vim.fn.mapcheck("<leader>l1", "n")]]), "")
end

test_set["keymap_recent_marked_buffers respects post_leader_marked_mapping"] = function()
  child.lua([[require("loft").setup({ post_leader_marked_mapping = "b" })]])
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  child.lua([[require("loft.registry"):keymap_recent_marked_buffers()]])
  eq(child.lua_get([[vim.fn.mapcheck("<leader>b1", "n") ~= ""]]), true)
end

test_set["keymap_recent_marked_buffers maps up to 9 most recent"] = function()
  child.lua([[require("loft.registry"):clean()]])
  for _ = 1, 10 do
    local b = child.api.nvim_create_buf(true, false)
    child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. b .. [[)]])
  end
  -- Re-clean so all new buffers appear in the registry before keymapping
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):keymap_recent_marked_buffers()]])
  -- Keys 1-9 should all be set
  for i = 1, 9 do
    eq(child.lua_get([[vim.fn.mapcheck("<leader>l]] .. i .. [[", "n") ~= ""]]), true)
  end
end

-- ── reverse_order navigation ────────────────────────────────────────────

test_set["reverse_order: get_next_buffer follows visual order (lower registry index)"] = function()
  child.lua([[require("loft").setup({ reverse_order = true })]])
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  -- Set current to registry[2] (middle); visual "next" = registry[1] (lower index)
  child.api.nvim_set_current_buf(registry[2])
  local next_buf = child.lua_get([[require("loft.registry"):get_next_buffer()]])
  eq(next_buf, registry[1])
end

test_set["reverse_order: get_next_buffer wraps from registry[1] to last"] = function()
  child.lua([[require("loft").setup({ reverse_order = true })]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  -- Set current to registry[1]; visual "next" wraps to registry[n]
  child.api.nvim_set_current_buf(registry[1])
  local next_buf = child.lua_get([[require("loft.registry"):get_next_buffer()]])
  eq(next_buf, registry[#registry])
end

test_set["reverse_order: get_prev_buffer follows visual order (higher registry index)"] = function()
  child.lua([[require("loft").setup({ reverse_order = true })]])
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  -- Set current to registry[2]; visual "prev" = registry[3] (higher index)
  child.api.nvim_set_current_buf(registry[2])
  local prev_buf = child.lua_get([[require("loft.registry"):get_prev_buffer()]])
  eq(prev_buf, registry[3])
end

test_set["reverse_order: get_prev_buffer wraps from last to registry[1]"] = function()
  child.lua([[require("loft").setup({ reverse_order = true })]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  -- Set current to registry[n]; visual "prev" wraps to registry[1]
  child.api.nvim_set_current_buf(registry[#registry])
  local prev_buf = child.lua_get([[require("loft.registry"):get_prev_buffer()]])
  eq(prev_buf, registry[1])
end

return test_set
