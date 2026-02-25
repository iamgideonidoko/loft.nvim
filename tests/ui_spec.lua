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

test_set["open creates buffer and window"] = function()
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  eq(child.lua_get([[type(require("loft.ui")._win_id)]]), "number")
end

test_set["close deletes buffer and window"] = function()
  child.lua([[require("loft.ui"):open()]])
  local win_id, buf_id = child.lua_get([[require("loft.ui")._win_id]]), child.lua_get([[require("loft.ui")._buf_id]])
  child.lua([[require("loft.ui"):close()]])
  eq(child.api.nvim_win_is_valid(win_id), false)
  eq(child.api.nvim_buf_is_valid(buf_id), false)
end

test_set["toggle opens when closed"] = function()
  eq(child.lua_get([[require("loft.ui"):is_open()]]), false)
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):toggle()]])
  eq(child.lua_get([[require("loft.ui"):is_open()]]), true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["toggle closes when open"] = function()
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  eq(child.lua_get([[require("loft.ui"):is_open()]]), true)
  child.lua([[require("loft.ui"):toggle()]])
  eq(child.lua_get([[require("loft.ui"):is_open()]]), false)
end

test_set["is_open returns false initially"] = function()
  eq(child.lua_get([[require("loft.ui"):is_open()]]), false)
end

test_set["is_open returns true when open"] = function()
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  eq(child.lua_get([[require("loft.ui"):is_open()]]), true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["get_buffer_mark returns empty for unmarked buffer"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  eq(child.lua_get([[require("loft.ui"):get_buffer_mark(]] .. buf .. [[)]]), "")
end

test_set["get_buffer_mark returns symbol for marked buffer"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  local mark = child.lua_get([[require("loft.ui"):get_buffer_mark(]] .. buf .. [[)]])
  eq(mark ~= "", true)
end

test_set["smart_order_indicator returns symbol when on"] = function()
  eq(child.lua_get([[require("loft.ui"):smart_order_indicator() ~= ""]]), true)
end

test_set["smart_order_indicator returns empty when off"] = function()
  child.lua([[require("loft.registry"):toggle_smart_order()]])
  eq(child.lua_get([[require("loft.ui"):smart_order_indicator()]]), "")
end

test_set["toggle_smart_order changes registry state"] = function()
  local initial = child.lua_get([[require("loft.registry"):is_smart_order_on()]])
  child.lua([[require("loft.ui"):toggle_smart_order()]])
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), not initial)
end

test_set["move_buffer_up reorders registry"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.api.nvim_set_current_buf(buf1)
  -- After switching, buf1 is last. move_buffer_up swaps it with second-to-last.
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  local len = #before
  child.lua([[require("loft.ui"):move_buffer_up()]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[len - 1], before[len])
  eq(after[len], before[len - 1])
  child.lua([[require("loft.ui"):close()]])
end

test_set["move_buffer_down reorders registry"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  -- Current = initial (first). move_buffer_down swaps it with second.
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  child.lua([[require("loft.ui"):move_buffer_down()]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[1], before[2])
  eq(after[2], before[1])
  child.lua([[require("loft.ui"):close()]])
end

-- ── cursor movement ────────────────────────────────────────────────────

test_set["_move_up moves cursor up by one"] = function()
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {3, 1})]])
  child.lua([[require("loft.ui"):_move_up()]])
  eq(child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]]), 2)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_move_up wraps from first line to last"] = function()
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local n = child.lua_get([[#require("loft.registry"):get_registry()]])
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {1, 1})]])
  child.lua([[require("loft.ui"):_move_up()]])
  eq(child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]]), n)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_move_down moves cursor down by one"] = function()
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {1, 1})]])
  child.lua([[require("loft.ui"):_move_down()]])
  eq(child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]]), 2)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_move_down wraps from last line to first"] = function()
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local n = child.lua_get([[#require("loft.registry"):get_registry()]])
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {]] .. n .. [[, 1})]])
  child.lua([[require("loft.ui"):_move_down()]])
  eq(child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]]), 1)
  child.lua([[require("loft.ui"):close()]])
end

-- ── entry reordering ───────────────────────────────────────────────────

test_set["_move_entry_up swaps entry with previous and moves cursor up"] = function()
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  local n = #before
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {]] .. n .. [[, 1})]])
  child.lua([[require("loft.ui"):_move_entry_up()]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[n - 1], before[n])
  eq(after[n], before[n - 1])
  eq(child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]]), n - 1)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_move_entry_up cyclic from first to last"] = function()
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  local n = #before
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {1, 1})]])
  child.lua([[require("loft.ui"):_move_entry_up()]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[n], before[1])
  eq(child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]]), n)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_move_entry_down swaps entry with next and moves cursor down"] = function()
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {1, 1})]])
  child.lua([[require("loft.ui"):_move_entry_down()]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[1], before[2])
  eq(after[2], before[1])
  eq(child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]]), 2)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_move_entry_down cyclic from last to first"] = function()
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local before = child.lua_get([[require("loft.registry"):get_registry()]])
  local n = #before
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {]] .. n .. [[, 1})]])
  child.lua([[require("loft.ui"):_move_entry_down()]])
  local after = child.lua_get([[require("loft.registry"):get_registry()]])
  eq(after[1], before[n])
  eq(child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]]), 1)
  child.lua([[require("loft.ui"):close()]])
end

-- ── entry selection and deletion ───────────────────────────────────────

test_set["_select_entry closes UI and switches to selected buffer"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local buf1_line = nil
  for i, b in ipairs(registry) do
    if b == buf1 then
      buf1_line = i
      break
    end
  end
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {]] .. buf1_line .. [[, 1})]])
  child.lua([[require("loft.ui"):_select_entry()]])
  eq(child.lua_get([[require("loft.ui"):is_open()]]), false)
  eq(child.lua_get([[vim.api.nvim_get_current_buf()]]), buf1)
end

test_set["_delete_entry removes buffer from registry"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local buf1_line = nil
  for i, b in ipairs(registry) do
    if b == buf1 then
      buf1_line = i
      break
    end
  end
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {]] .. buf1_line .. [[, 1})]])
  child.lua([[require("loft.ui"):_delete_entry()]])
  eq(child.api.nvim_buf_is_valid(buf1), false)
  child.lua([[require("loft.ui"):close()]])
end

-- ── mark toggling ──────────────────────────────────────────────────────

test_set["_toggle_mark_entry marks entry at cursor"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local buf1_line = nil
  for i, b in ipairs(registry) do
    if b == buf1 then
      buf1_line = i
      break
    end
  end
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {]] .. buf1_line .. [[, 1})]])
  child.lua([[require("loft.ui"):_toggle_mark_entry()]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf1 .. [[)]]), true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_toggle_mark_entry unmarks already marked entry"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf1 .. [[)]])
  child.lua([[require("loft.ui"):open()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local buf1_line = nil
  for i, b in ipairs(registry) do
    if b == buf1 then
      buf1_line = i
      break
    end
  end
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {]] .. buf1_line .. [[, 1})]])
  child.lua([[require("loft.ui"):_toggle_mark_entry()]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf1 .. [[)]]), false)
  child.lua([[require("loft.ui"):close()]])
end

-- ── navigate to marked entry ───────────────────────────────────────────

test_set["_move_to_marked_entry down jumps to next marked buffer"] = function()
  child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf2 .. [[)]])
  child.lua([[require("loft.ui"):open()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local buf2_line = nil
  for i, b in ipairs(registry) do
    if b == buf2 then
      buf2_line = i
      break
    end
  end
  -- cursor starts at line 1 (initial buf); move down to first marked
  child.lua([[require("loft.ui"):_move_to_marked_entry("down")]])
  eq(child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]]), buf2_line)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_move_to_marked_entry up jumps to prev marked buffer"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf1 .. [[)]])
  child.lua([[require("loft.ui"):open()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local buf1_line, buf2_line = nil, nil
  for i, b in ipairs(registry) do
    if b == buf1 then
      buf1_line = i
    end
    if b == buf2 then
      buf2_line = i
    end
  end
  -- place cursor at buf2 (last), move up to buf1 (marked)
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {]] .. buf2_line .. [[, 1})]])
  child.lua([[require("loft.ui"):_move_to_marked_entry("up")]])
  eq(child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]]), buf1_line)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_move_to_marked_entry does nothing when no marked buffer"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  -- cursor at line 1, no marked buffers
  local before_line = child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]])
  child.lua([[require("loft.ui"):_move_to_marked_entry("down")]])
  eq(child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]]), before_line)
  child.lua([[require("loft.ui"):close()]])
end

-- ── help window ────────────────────────────────────────────────────────

test_set["_show_help creates help window"] = function()
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  eq(child.lua_get([[type(require("loft.ui")._help_win_id)]]), "number")
  eq(child.lua_get([[vim.api.nvim_win_is_valid(require("loft.ui")._help_win_id)]]), true)
  child.lua([[require("loft.ui"):_close_help()]])
  child.lua([[require("loft.ui"):close()]])
end

test_set["_show_help focuses existing window on second call"] = function()
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  local first_id = child.lua_get([[require("loft.ui")._help_win_id]])
  child.lua([[require("loft.ui"):_show_help()]])
  eq(child.lua_get([[require("loft.ui")._help_win_id]]), first_id)
  child.lua([[require("loft.ui"):_close_help()]])
  child.lua([[require("loft.ui"):close()]])
end

test_set["_close_help closes help window and clears id"] = function()
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  local help_win = child.lua_get([[require("loft.ui")._help_win_id]])
  child.lua([[require("loft.ui"):_close_help()]])
  -- Window must be invalid (either explicitly closed or auto-closed on buf delete)
  eq(child.api.nvim_win_is_valid(help_win), false)
  child.lua([[require("loft.ui"):close()]])
end

-- ── highlight groups ────────────────────────────────────────────────────

test_set["highlights.setup defines all highlight groups"] = function()
  local groups = child.lua_get([[vim.tbl_keys(require("loft.highlights").groups)]])
  local expected = {
    "LoftCurrentBuffer",
    "LoftMarkedBuffer",
    "LoftMark",
    "LoftCurrentIndicator",
    "LoftModified",
    "LoftBufferNumber",
  }
  for _, name in ipairs(expected) do
    -- vim.fn.hlID returns a positive integer when a group is defined; works on all Neovim versions
    local defined = child.lua_get([[vim.fn.hlID("]] .. name .. [[") > 0]])
    eq(defined, true)
  end
  eq(#groups, #expected)
end

test_set["highlights re-applied on ColorScheme event"] = function()
  -- Fire ColorScheme; groups must still resolve afterwards
  child.lua([[vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })]])
  local defined = child.lua_get([[vim.fn.hlID("LoftCurrentBuffer") > 0]])
  eq(defined, true)
end

test_set["_render_entries applies LoftCurrentBuffer to current buffer line"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(buf)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local ns = child.lua_get('vim.api.nvim_get_namespaces()["loft_ui"]')
  local ui_buf = child.lua_get([[require("loft.ui")._buf_id]])
  local marks =
    child.lua_get(string.format([[vim.api.nvim_buf_get_extmarks(%d, %d, 0, -1, { details = true })]], ui_buf, ns))
  -- line_hl_group is not reported in extmark details before Neovim 0.9;
  -- on those versions just confirm the namespace has extmarks (highlights applied).
  local has_nvim_09 = child.lua_get([[vim.fn.has("nvim-0.9") == 1]])
  if has_nvim_09 then
    local found = false
    for _, m in ipairs(marks) do
      if m[4] and m[4].line_hl_group == "LoftCurrentBuffer" then
        found = true
        break
      end
    end
    eq(found, true)
  else
    eq(#marks > 0, true)
  end
  child.lua([[require("loft.ui"):close()]])
end

test_set["_render_entries applies LoftMarkedBuffer to marked buffer line"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  child.lua([[require("loft.registry"):clean()]])
  -- open from a different buffer so `buf` is not the current one
  child.lua([[require("loft.ui"):open()]])
  local ns = child.lua_get('vim.api.nvim_get_namespaces()["loft_ui"]')
  local ui_buf = child.lua_get([[require("loft.ui")._buf_id]])
  local marks =
    child.lua_get(string.format([[vim.api.nvim_buf_get_extmarks(%d, %d, 0, -1, { details = true })]], ui_buf, ns))
  -- line_hl_group is not reported in extmark details before Neovim 0.9
  local has_nvim_09 = child.lua_get([[vim.fn.has("nvim-0.9") == 1]])
  if has_nvim_09 then
    local found = false
    for _, m in ipairs(marks) do
      if m[4] and m[4].line_hl_group == "LoftMarkedBuffer" then
        found = true
        break
      end
    end
    eq(found, true)
  else
    eq(#marks > 0, true)
  end
  child.lua([[require("loft.ui"):close()]])
end

test_set["_render_entries applies LoftMark inline highlight to mark symbol"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local ns = child.lua_get('vim.api.nvim_get_namespaces()["loft_ui"]')
  local ui_buf = child.lua_get([[require("loft.ui")._buf_id]])
  local marks =
    child.lua_get(string.format([[vim.api.nvim_buf_get_extmarks(%d, %d, 0, -1, { details = true })]], ui_buf, ns))
  local found = false
  for _, m in ipairs(marks) do
    if m[4] and m[4].hl_group == "LoftMark" then
      found = true
      break
    end
  end
  eq(found, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_render_entries applies LoftBufferNumber to every buffer number token"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local ns = child.lua_get('vim.api.nvim_get_namespaces()["loft_ui"]')
  local ui_buf = child.lua_get([[require("loft.ui")._buf_id]])
  local marks =
    child.lua_get(string.format([[vim.api.nvim_buf_get_extmarks(%d, %d, 0, -1, { details = true })]], ui_buf, ns))
  local found = false
  for _, m in ipairs(marks) do
    if m[4] and m[4].hl_group == "LoftBufferNumber" then
      found = true
      break
    end
  end
  eq(found, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_render_entries applies LoftCurrentIndicator for current buffer dot"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(buf)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local ns = child.lua_get('vim.api.nvim_get_namespaces()["loft_ui"]')
  local ui_buf = child.lua_get([[require("loft.ui")._buf_id]])
  local marks =
    child.lua_get(string.format([[vim.api.nvim_buf_get_extmarks(%d, %d, 0, -1, { details = true })]], ui_buf, ns))
  local found = false
  for _, m in ipairs(marks) do
    if m[4] and m[4].hl_group == "LoftCurrentIndicator" then
      found = true
      break
    end
  end
  eq(found, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_render_entries applies LoftModified for modified buffer"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  -- mark buffer as modified via setlocal modified
  child.lua([[vim.api.nvim_set_option_value("modified", true, { buf = ]] .. buf .. [[ })]])
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local ns = child.lua_get('vim.api.nvim_get_namespaces()["loft_ui"]')
  local ui_buf = child.lua_get([[require("loft.ui")._buf_id]])
  local marks =
    child.lua_get(string.format([[vim.api.nvim_buf_get_extmarks(%d, %d, 0, -1, { details = true })]], ui_buf, ns))
  local found = false
  for _, m in ipairs(marks) do
    if m[4] and m[4].hl_group == "LoftModified" then
      found = true
      break
    end
  end
  eq(found, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["highlights cleared on close and reapplied on re-open"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(buf)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local ns = child.lua_get('vim.api.nvim_get_namespaces()["loft_ui"]')
  local ui_buf = child.lua_get([[require("loft.ui")._buf_id]])
  local before = child.lua_get(string.format([[#vim.api.nvim_buf_get_extmarks(%d, %d, 0, -1, {})]], ui_buf, ns))
  eq(before > 0, true)
  child.lua([[require("loft.ui"):close()]])
  -- Re-open: new buffer, highlights should be present again
  child.lua([[require("loft.ui"):open()]])
  local ui_buf2 = child.lua_get([[require("loft.ui")._buf_id]])
  local after = child.lua_get(string.format([[#vim.api.nvim_buf_get_extmarks(%d, %d, 0, -1, {})]], ui_buf2, ns))
  eq(after > 0, true)
  child.lua([[require("loft.ui"):close()]])
end

-- ── reverse_order ──────────────────────────────────────────────────────

-- Helper: setup loft with reverse_order = true and create N listed buffers.
-- Returns the created buffer IDs in creation order.
local function setup_reverse(child_instance, n)
  child_instance.lua([[require("loft").setup({ reverse_order = true })]])
  local bufs = {}
  for _ = 1, n do
    table.insert(bufs, child_instance.api.nvim_create_buf(true, false))
  end
  child_instance.lua([[require("loft.registry"):clean()]])
  return bufs
end

test_set["reverse_order: entries rendered in reverse registry order"] = function()
  setup_reverse(child, 3)
  child.lua([[require("loft.ui"):open()]])
  local lines = child.lua_get([[vim.api.nvim_buf_get_lines(require("loft.ui")._buf_id, 0, -1, false)]])
  -- Each line encodes {bufnr}; first rendered line should contain the LAST registry item
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  -- registry[3] should appear on line 1
  local last_bufnr = tostring(registry[#registry])
  eq(lines[1]:find("{" .. last_bufnr .. "}") ~= nil, true)
  -- registry[1] should appear on the last line
  local first_bufnr = tostring(registry[1])
  eq(lines[#lines]:find("{" .. first_bufnr .. "}") ~= nil, true)
  child.lua([[require("loft.ui"):close()]])
  -- silence unused-var warning
end

test_set["reverse_order: cursor placed on current buffer line"] = function()
  setup_reverse(child, 3)
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  -- Set registry[1] as current; in reversed mode it lands on the last display line
  child.api.nvim_set_current_buf(registry[1])
  child.lua([[require("loft.ui"):open()]])
  local cursor_row = child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]])
  local lines = child.lua_get([[vim.api.nvim_buf_get_lines(require("loft.ui")._buf_id, 0, -1, false)]])
  -- The cursor line must contain the number of _last_buf_before_loft
  local last_buf = child.lua_get([[require("loft.ui")._last_buf_before_loft]])
  eq(lines[cursor_row]:find("{" .. tostring(last_buf) .. "}") ~= nil, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["reverse_order: _move_entry_up moves visually upward"] = function()
  setup_reverse(child, 3)
  child.lua([[require("loft.ui"):open()]])
  local registry_before = child.lua_get([[require("loft.registry"):get_registry()]])
  local n = #registry_before
  -- Position cursor on the MIDDLE display line (line 2) which is registry[n-1]
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {2, 1})]])
  local mid_buf = registry_before[n - 1]
  child.lua([[require("loft.ui"):_move_entry_up()]])
  -- After move-up, mid_buf should be at display line 1
  local lines = child.lua_get([[vim.api.nvim_buf_get_lines(require("loft.ui")._buf_id, 0, -1, false)]])
  eq(lines[1]:find("{" .. tostring(mid_buf) .. "}") ~= nil, true)
  -- Cursor should be at line 1
  local cursor_row = child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]])
  eq(cursor_row, 1)
  child.lua([[require("loft.ui"):close()]])
end

test_set["reverse_order: _move_entry_down moves visually downward"] = function()
  setup_reverse(child, 3)
  child.lua([[require("loft.ui"):open()]])
  local registry_before = child.lua_get([[require("loft.registry"):get_registry()]])
  local n = #registry_before
  -- Position cursor on the MIDDLE display line (line 2) which is registry[n-1]
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {2, 1})]])
  local mid_buf = registry_before[n - 1]
  child.lua([[require("loft.ui"):_move_entry_down()]])
  -- After move-down from line 2, mid_buf should be at display line 3 (line 2 + 1)
  local lines = child.lua_get([[vim.api.nvim_buf_get_lines(require("loft.ui")._buf_id, 0, -1, false)]])
  eq(lines[3]:find("{" .. tostring(mid_buf) .. "}") ~= nil, true)
  -- Cursor should be at line 3
  local cursor_row = child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]])
  eq(cursor_row, 3)
  child.lua([[require("loft.ui"):close()]])
end

test_set["reverse_order: _delete_entry removes correct buffer"] = function()
  setup_reverse(child, 3)
  child.lua([[require("loft.ui"):open()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local n = #registry
  -- Line 1 in reversed display = registry[n]; position cursor there
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {1, 1})]])
  local top_buf = registry[n]
  child.lua([[require("loft.ui"):_delete_entry()]])
  local registry_after = child.lua_get([[require("loft.registry"):get_registry()]])
  -- top_buf must no longer be in the registry
  local still_present = false
  for _, b in ipairs(registry_after) do
    if b == top_buf then
      still_present = true
      break
    end
  end
  eq(still_present, false)
  child.lua([[require("loft.ui"):close()]])
end

test_set["reverse_order: _toggle_mark_entry marks correct buffer"] = function()
  setup_reverse(child, 3)
  child.lua([[require("loft.ui"):open()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local n = #registry
  -- Line 1 = registry[n]; mark it
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {1, 1})]])
  local top_buf = registry[n]
  child.lua([[require("loft.ui"):_toggle_mark_entry()]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. top_buf .. [[)]]), true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["reverse_order: _move_to_marked_entry down jumps to buffer visually below"] = function()
  setup_reverse(child, 4)
  child.lua([[require("loft.registry"):clean()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local n = #registry
  -- Mark the buffer at registry[2] (display line n-1)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. registry[2] .. [[)]])
  child.lua([[require("loft.ui"):open()]])
  -- Place cursor at top line (registry[n])
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {1, 1})]])
  child.lua([[require("loft.ui"):_move_to_marked_entry("down")]])
  local cursor_row = child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]])
  -- registry[2] in reversed display = line n - 2 + 1 = n-1
  eq(cursor_row, n - 1)
  child.lua([[require("loft.ui"):close()]])
end

test_set["reverse_order: _move_to_marked_entry up jumps to buffer visually above"] = function()
  setup_reverse(child, 4)
  child.lua([[require("loft.registry"):clean()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local n = #registry
  -- Mark the buffer at registry[n-1] (display line 2)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. registry[n - 1] .. [[)]])
  child.lua([[require("loft.ui"):open()]])
  -- Place cursor at the last display line (registry[1])
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {]] .. n .. [[, 1})]])
  child.lua([[require("loft.ui"):_move_to_marked_entry("up")]])
  local cursor_row = child.lua_get([[select(1, unpack(vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)))]])
  -- registry[n-1] in reversed display = line n - (n-1) + 1 = 2
  eq(cursor_row, 2)
  child.lua([[require("loft.ui"):close()]])
end

return test_set
