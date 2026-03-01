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

-- ── smart_order_on_window_switch ────────────────────────────────────────

test_set["smart order does not reorder on window switch by default"] = function()
  child.lua([[require("loft").setup({ enable_smart_order_by_default = true, smart_order_on_window_switch = false })]])
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local initial = child.lua_get([[require("loft.registry"):get_registry()]])
  -- Simulate a window switch: set _prev_win_id to a different win ID, then call _update()
  child.lua([[
    local reg = require("loft.registry")
    local current_win = vim.api.nvim_get_current_win()
    reg._prev_win_id = current_win + 999  -- pretend we came from a different window
    reg:_update()
  ]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  -- Order must be unchanged: window-switch with flag=false should not reorder
  eq(after[1], initial[1])
  eq(after[#after], initial[#initial])
end

test_set["smart order DOES reorder on window switch when smart_order_on_window_switch=true"] = function()
  child.lua([[require("loft").setup({ enable_smart_order_by_default = true, smart_order_on_window_switch = true })]])
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local current_buf = child.lua_get([[vim.api.nvim_get_current_buf()]])
  -- Simulate a window switch and trigger _update()
  child.lua([[
    local reg = require("loft.registry")
    local current_win = vim.api.nvim_get_current_win()
    reg._prev_win_id = current_win + 999  -- pretend we came from a different window
    reg:_update()
  ]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  -- Current buf should be at the end (most recently used position) after smart order
  eq(after[#after], current_buf)
end

-- ── exclude_buftypes ────────────────────────────────────────────────────

test_set["exclude_buftypes prevents excluded buftype from entering registry"] = function()
  child.lua([[require("loft").setup({ exclude_buftypes = { "nofile" } })]])
  -- Create a nofile buffer and fire BufEnter on it
  child.lua([[
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
    vim.api.nvim_set_option_value("buflisted", true, { buf = buf })
    -- Manually call _update as if BufEnter fired for that buf
    require("loft.registry"):_update(buf)
  ]])
  local reg = child.lua_get([[require("loft.registry"):get_registry()]])
  -- The nofile buffer should NOT be in the registry
  local found = false
  for _, b in ipairs(reg) do
    local bt = child.lua_get(string.format([[vim.api.nvim_get_option_value("buftype", { buf = %d })]], b))
    if bt == "nofile" then
      found = true
    end
  end
  eq(found, false)
end

test_set["exclude_buftypes empty list allows all buftypes (default)"] = function()
  -- Default is {}, so no buftype is excluded
  local default_excludes = child.lua_get([[require("loft.config").all.exclude_buftypes]])
  eq(#default_excludes, 0)
end

-- ── auto_delete_missing_file_bufs ────────────────────────────────────────

test_set["auto_delete_missing_file_bufs defaults to true"] = function()
  eq(child.lua_get([[require("loft.config").all.auto_delete_missing_file_bufs]]), true)
end

test_set["clean() deletes missing-file buffers when auto_delete_missing_file_bufs=true"] = function()
  child.lua([[require("loft").setup({ auto_delete_missing_file_bufs = true })]])
  -- Create a buffer with a non-existent file path so buf_has_deleted_file returns true.
  local buf = child.api.nvim_create_buf(true, false)
  child.lua(string.format([[vim.api.nvim_buf_set_name(%d, "/nonexistent_loft_clean_test.lua")]], buf))
  -- Inject into registry so the deletion loop can find it.
  child.lua(string.format([[table.insert(require("loft.registry")._registry, %d)]], buf))
  -- Confirm buf_has_deleted_file sees it as deleted
  local is_deleted = child.lua_get(string.format([[require("loft.utils").buf_has_deleted_file(%d)]], buf))
  eq(is_deleted, true)
  -- clean() should force-delete the buffer from Neovim
  child.lua([[require("loft.registry"):clean()]])
  local still_valid = child.lua_get(string.format([[vim.api.nvim_buf_is_valid(%d)]], buf))
  eq(still_valid, false)
end

test_set["clean() keeps missing-file buffers when auto_delete_missing_file_bufs=false"] = function()
  child.lua([[require("loft").setup({ auto_delete_missing_file_bufs = false })]])
  local buf = child.api.nvim_create_buf(true, false)
  child.lua(string.format([[vim.api.nvim_buf_set_name(%d, "/nonexistent_loft_clean_test.lua")]], buf))
  child.lua(string.format([[table.insert(require("loft.registry")._registry, %d)]], buf))
  local is_deleted = child.lua_get(string.format([[require("loft.utils").buf_has_deleted_file(%d)]], buf))
  eq(is_deleted, true)
  -- clean() must NOT delete the buffer from Neovim
  child.lua([[require("loft.registry"):clean()]])
  local still_valid = child.lua_get(string.format([[vim.api.nvim_buf_is_valid(%d)]], buf))
  eq(still_valid, true)
  child.api.nvim_buf_delete(buf, { force = true })
end

test_set["clean(true) deletes missing-file buffers regardless of config"] = function()
  -- Explicit delete_missing=true overrides the config option.
  child.lua([[require("loft").setup({ auto_delete_missing_file_bufs = false })]])
  local buf = child.api.nvim_create_buf(true, false)
  child.lua(string.format([[vim.api.nvim_buf_set_name(%d, "/nonexistent_loft_clean_test.lua")]], buf))
  child.lua(string.format([[table.insert(require("loft.registry")._registry, %d)]], buf))
  child.lua([[require("loft.registry"):clean(true)]])
  local still_valid = child.lua_get(string.format([[vim.api.nvim_buf_is_valid(%d)]], buf))
  eq(still_valid, false)
end

test_set["clean(false) keeps missing-file buffers regardless of config"] = function()
  -- Explicit delete_missing=false overrides the config option.
  child.lua([[require("loft").setup({ auto_delete_missing_file_bufs = true })]])
  local buf = child.api.nvim_create_buf(true, false)
  child.lua(string.format([[vim.api.nvim_buf_set_name(%d, "/nonexistent_loft_clean_test.lua")]], buf))
  child.lua(string.format([[table.insert(require("loft.registry")._registry, %d)]], buf))
  child.lua([[require("loft.registry"):clean(false)]])
  local still_valid = child.lua_get(string.format([[vim.api.nvim_buf_is_valid(%d)]], buf))
  eq(still_valid, true)
  child.api.nvim_buf_delete(buf, { force = true })
end

test_set["smart order: entering non-registry buffer does not reorder registry"] = function()
  child.lua([[require("loft").setup({ enable_smart_order_by_default = true })]])
  local buf_a = child.api.nvim_create_buf(true, false)
  local buf_b = child.api.nvim_create_buf(true, false)
  -- Both are in the registry
  child.lua([[require("loft.registry"):clean()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  -- Create a new buffer NOT yet in the registry and call _update for it.
  -- This simulates entering a brand-new buffer (it will be added, but registry
  -- buffers should NOT be reordered).
  child.lua([[
    local reg = require("loft.registry")
    local new_buf = vim.api.nvim_create_buf(true, false)
    -- Force it to appear valid but NOT yet in registry (skip clean so it isn't added)
    reg:_update(new_buf)
  ]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  -- buf_a and buf_b should still be at their original positions (not moved to end)
  local a_before, b_before
  for i, b in ipairs(before) do
    if b == buf_a then
      a_before = i
    end
    if b == buf_b then
      b_before = i
    end
  end
  local a_after, b_after
  for i, b in ipairs(after) do
    if b == buf_a then
      a_after = i
    end
    if b == buf_b then
      b_after = i
    end
  end
  eq(a_before, a_after)
  eq(b_before, b_after)
end

test_set["smart order: entering registry buffer from non-registry buf reorders correctly"] = function()
  child.lua([[require("loft").setup({ enable_smart_order_by_default = true, smart_order_alt_bufs = false })]])
  local buf_a = child.api.nvim_create_buf(true, false)
  local buf_b = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  -- Registry is now [initial, buf_a, buf_b] or similar.
  -- Simulate: manually set buf_a as already in registry, then call _update(buf_a)
  -- with a non-registry alt_buf. buf_a should move to last, others stay put.
  child.lua([[
    local reg = require("loft.registry")
    -- Fake alt_buf as a buffer NOT in the registry
    local non_reg_buf = vim.api.nvim_create_buf(false, true)
    -- Override alt buf by calling _update directly with buf_a as current buf
    -- and the non-registry buf would be the "previous" in the real scenario.
    -- We simulate by removing buf_a, expecting it ends up last.
    reg:_update(]] .. buf_a .. [[)
  ]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  -- buf_a should be last (moved to end by smart order)
  eq(after[#after], buf_a)
  -- buf_b's position should be before buf_a
  local b_pos
  for i, b in ipairs(after) do
    if b == buf_b then
      b_pos = i
    end
  end
  eq(b_pos ~= nil, true)
  eq(b_pos < #after, true)
end

test_set["smart order: alt_buf only reordered when both buf and alt_buf are in registry"] = function()
  child.lua([[require("loft").setup({ enable_smart_order_by_default = true, smart_order_alt_bufs = true })]])
  local buf_a = child.api.nvim_create_buf(true, false)
  local buf_b = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  -- Confirm both are in registry
  local reg_before = child.lua_get([[require("loft.registry"):get_registry()]])
  local a_in, b_in = false, false
  for _, b in ipairs(reg_before) do
    if b == buf_a then
      a_in = true
    end
    if b == buf_b then
      b_in = true
    end
  end
  eq(a_in, true)
  eq(b_in, true)
  -- Now call _update for buf_a (which IS in registry), with alt_buf = buf_b (also in registry).
  -- Both should be reordered: buf_b second-to-last, buf_a last.
  child.lua([[
    local reg = require("loft.registry")
    -- Patch alt_buf lookup by directly manipulating: simulate BufEnter buf_a with # = buf_b
    -- We use the internal path: set current buf to buf_a, previous to buf_b
    vim.api.nvim_set_current_buf(]] .. buf_b .. [[)
    vim.api.nvim_set_current_buf(]] .. buf_a .. [[)
    reg:_update()
  ]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[#after], buf_a)
  eq(after[#after - 1], buf_b)
end

-- ── invalid buffer id in registry must not crash _update ──────────

test_set["_update with stale invalid buffer in registry does not crash"] = function()
  -- nvim_buf_get_name on an invalid buf id raised "Invalid buffer id".
  -- add_stat_path now guards with nvim_buf_is_valid before calling nvim_buf_get_name.
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  -- Inject the buffer into the registry, then delete it (making the id stale).
  child.lua(string.format([[table.insert(require("loft.registry")._registry, %d)]], buf))
  child.api.nvim_buf_delete(buf, { force = true })
  -- _update must not throw "Invalid buffer id"
  local ok = child.lua_get([[
    pcall(function() require("loft.registry"):_update() end)
  ]])
  eq(ok, true)
end

-- ── Regression: rapid _update calls must not produce duplicate entries ────────

test_set["rapid _update calls produce no duplicate registry entries"] = function()
  -- Regression: before the generation counter, multiple overlapping async-stat
  -- batches would each call run_main_logic and insert the same buffer multiple times.
  child.lua([[require("loft").setup({ enable_smart_order_by_default = false })]])
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  -- Fire three _update calls without yielding so all share the same event-loop tick.
  child.lua(string.format(
    [[
    local reg = require("loft.registry")
    reg:_update(%d)
    reg:_update(%d)
    reg:_update(%d)
  ]],
    buf,
    buf,
    buf
  ))
  -- Let all pending vim.schedule callbacks drain.
  child.lua([[vim.wait(150, function() return false end)]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local count = 0
  for _, b in ipairs(registry) do
    if b == buf then
      count = count + 1
    end
  end
  eq(count, 1)
  child.api.nvim_buf_delete(buf, { force = true })
end

-- ── Regression: keymap_recent_marked_buffers must not crash on deleted buf ───

test_set["keymap_recent_marked_buffers does not crash when marked buffer is deleted"] = function()
  -- Regression: getbufinfo(buf)[1] returned nil for a deleted buffer, causing
  -- "attempt to index a nil value" in keymap_recent_marked_buffers.
  child.lua([[require("loft").setup({ enable_recent_marked_mapping = true })]])
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua(string.format([[require("loft.registry"):toggle_mark_buffer(%d)]], buf))
  -- Delete the buffer while it remains in the marked list.
  child.api.nvim_buf_delete(buf, { force = true })
  -- on_change → keymap_recent_marked_buffers must not crash.
  local ok = child.lua_get([[
    pcall(function() require("loft.registry"):on_change() end)
  ]])
  eq(ok, true)
end

-- ── get_next/prev_buffer when current not in registry ─────────────────────────

test_set["get_next_buffer returns nil when current buffer not in registry"] = function()
  child.lua([[require("loft.registry"):clean()]])
  -- Create a buffer and set it as current WITHOUT adding it to the registry.
  local buf = child.api.nvim_create_buf(false, true)
  child.api.nvim_set_current_buf(buf)
  -- Force-remove it from registry in case clean() added it.
  child.lua(string.format(
    [[
    local reg = require("loft.registry")._registry
    for i = #reg, 1, -1 do
      if reg[i] == %d then table.remove(reg, i) end
    end
  ]],
    buf
  ))
  eq(child.lua_get([[require("loft.registry"):get_next_buffer() == nil]]), true)
  child.api.nvim_buf_delete(buf, { force = true })
end

test_set["get_prev_buffer returns nil when current buffer not in registry"] = function()
  child.lua([[require("loft.registry"):clean()]])
  local buf = child.api.nvim_create_buf(false, true)
  child.api.nvim_set_current_buf(buf)
  child.lua(string.format(
    [[
    local reg = require("loft.registry")._registry
    for i = #reg, 1, -1 do
      if reg[i] == %d then table.remove(reg, i) end
    end
  ]],
    buf
  ))
  eq(child.lua_get([[require("loft.registry"):get_prev_buffer() == nil]]), true)
  child.api.nvim_buf_delete(buf, { force = true })
end

-- ── move_buffer_up / move_buffer_down edge cases ──────────────────────────────

test_set["move_buffer_up at index 1 without cyclic is a no-op"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  -- Move the first element up without cyclic — nothing should change.
  child.lua([[require("loft.registry"):move_buffer_up(1, false)]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[1], before[1])
  eq(#after, #before)
  child.api.nvim_buf_delete(buf1, { force = true })
end

test_set["move_buffer_down at last index without cyclic is a no-op"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  local last = #before
  child.lua(string.format([[require("loft.registry"):move_buffer_down(%d, false)]], last))
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[last], before[last])
  eq(#after, #before)
  child.api.nvim_buf_delete(buf1, { force = true })
end

test_set["move_buffer_up with cyclic moves first buffer to last"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  -- Move index 1 up cyclically → it should wrap to last position.
  child.lua([[require("loft.registry"):move_buffer_up(1, true)]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[#after], before[1])
  child.api.nvim_buf_delete(buf1, { force = true })
end

test_set["move_buffer_down with cyclic moves last buffer to first"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  local last = #before
  child.lua(string.format([[require("loft.registry"):move_buffer_down(%d, true)]], last))
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[1], before[last])
  child.api.nvim_buf_delete(buf1, { force = true })
end

-- ── _is_buftype_excluded ──────────────────────────────────────────────────────

test_set["_is_buftype_excluded returns true when buftype matches exclude list"] = function()
  child.lua([[require("loft").setup({ exclude_buftypes = { "nofile" } })]])
  local buf = child.api.nvim_create_buf(false, true) -- scratch: buftype="nofile"
  eq(child.lua_get(string.format([[require("loft.registry"):_is_buftype_excluded(%d)]], buf)), true)
  child.api.nvim_buf_delete(buf, { force = true })
end

test_set["_is_buftype_excluded returns false when buftype not in exclude list"] = function()
  child.lua([[require("loft").setup({ exclude_buftypes = { "quickfix" } })]])
  local buf = child.api.nvim_create_buf(true, false) -- normal listed buffer
  eq(child.lua_get(string.format([[require("loft.registry"):_is_buftype_excluded(%d)]], buf)), false)
  child.api.nvim_buf_delete(buf, { force = true })
end

-- ── toggle_smart_order return value ──────────────────────────────────────────

test_set["toggle_smart_order returns new state"] = function()
  -- Returns false when turning off, true when turning back on.
  local state1 = child.lua_get([[require("loft.registry"):toggle_smart_order()]])
  eq(state1, false)
  local state2 = child.lua_get([[require("loft.registry"):toggle_smart_order()]])
  eq(state2, true)
end

-- ── pause/resume_update expose correct flags ──────────────────────────────────

test_set["pause_update sets _update_paused and resume_update clears it"] = function()
  child.lua([[require("loft.registry"):pause_update()]])
  eq(child.lua_get([[require("loft.registry")._update_paused]]), true)
  child.lua([[require("loft.registry"):resume_update()]])
  eq(child.lua_get([[require("loft.registry")._update_paused]]), false)
end

-- ── get_marked_buffer when current buf not in registry ────────────────────────

test_set["get_marked_buffer still finds marked buf when current not in registry"] = function()
  local buf_a = child.api.nvim_create_buf(true, false)
  local buf_b = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua(string.format([[require("loft.registry"):toggle_mark_buffer(%d)]], buf_a))
  -- Create a scratch buffer (not in registry) and make it current.
  local scratch = child.api.nvim_create_buf(false, true)
  child.api.nvim_set_current_buf(scratch)
  child.lua(string.format(
    [[
    local reg = require("loft.registry")._registry
    for i = #reg, 1, -1 do
      if reg[i] == %d then table.remove(reg, i) end
    end
  ]],
    scratch
  ))
  -- get_marked_buffer should still return buf_a from the registry.
  eq(child.lua_get([[require("loft.registry"):get_marked_buffer("next")]]), buf_a)
  child.api.nvim_buf_delete(buf_a, { force = true })
  child.api.nvim_buf_delete(buf_b, { force = true })
  child.api.nvim_buf_delete(scratch, { force = true })
end

return test_set
