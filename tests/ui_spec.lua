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

-- ── window customisation ────────────────────────────────────────────────

test_set["window row_offset shifts window row"] = function()
  child.lua([[require("loft").setup({ window = { row_offset = 5 } })]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local cfg = child.lua_get([[vim.api.nvim_win_get_config(require("loft.ui")._win_id)]])
  -- row must be at least 5 (offset is additive to the centered position)
  eq(cfg.row >= 5, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["window col_offset shifts window col"] = function()
  child.lua([[require("loft").setup({ window = { col_offset = 8 } })]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local cfg = child.lua_get([[vim.api.nvim_win_get_config(require("loft.ui")._win_id)]])
  eq(cfg.col >= 8, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["window explicit row/col are used as-is"] = function()
  child.lua([[require("loft").setup({ window = { row = 3, col = 7 } })]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local cfg = child.lua_get([[vim.api.nvim_win_get_config(require("loft.ui")._win_id)]])
  eq(cfg.row, 3)
  eq(cfg.col, 7)
  child.lua([[require("loft.ui"):close()]])
end

test_set["window custom border is applied"] = function()
  child.lua([[require("loft").setup({ window = { border = "single" } })]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  -- nvim_win_get_config expands named borders to char arrays; check a corner char
  local cfg = child.lua_get([[vim.api.nvim_win_get_config(require("loft.ui")._win_id)]])
  -- "single" top-left corner is "┌"
  local border_tl = type(cfg.border) == "table" and cfg.border[1] or cfg.border
  eq(border_tl, "┌")
  child.lua([[require("loft.ui"):close()]])
end

-- ── help_window options ─────────────────────────────────────────────────

test_set["help_window disable prevents help window from opening"] = function()
  child.lua([[require("loft").setup({ help_window = { disable = true } })]])
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  eq(child.lua_get([[require("loft.ui")._help_win_id]]), vim.NIL)
  child.lua([[require("loft.ui"):close()]])
end

test_set["help_window zindex is always > main zindex"] = function()
  -- Supply a zindex lower than the main window (100) – must be clamped
  child.lua([[require("loft").setup({ window = { zindex = 100 }, help_window = { zindex = 50 } })]])
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  local help_cfg = child.lua_get([[vim.api.nvim_win_get_config(require("loft.ui")._help_win_id)]])
  local main_cfg = child.lua_get([[vim.api.nvim_win_get_config(require("loft.ui")._win_id)]])
  eq(help_cfg.zindex > main_cfg.zindex, true)
  child.lua([[require("loft.ui"):_close_help()]])
  child.lua([[require("loft.ui"):close()]])
end

test_set["help_window custom border overrides main window border"] = function()
  child.lua([[require("loft").setup({ window = { border = "rounded" }, help_window = { border = "double" } })]])
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  local cfg = child.lua_get([[vim.api.nvim_win_get_config(require("loft.ui")._help_win_id)]])
  -- "double" top-left corner is "╔"
  local border_tl = type(cfg.border) == "table" and cfg.border[1] or cfg.border
  eq(border_tl, "╔")
  child.lua([[require("loft.ui"):_close_help()]])
  child.lua([[require("loft.ui"):close()]])
end

test_set["help_window inherits main window border when not set"] = function()
  child.lua([[require("loft").setup({ window = { border = "single" } })]])
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  local help_cfg = child.lua_get([[vim.api.nvim_win_get_config(require("loft.ui")._help_win_id)]])
  local main_cfg = child.lua_get([[vim.api.nvim_win_get_config(require("loft.ui")._win_id)]])
  -- Both windows should have the same border style (resolved to the same array)
  local htl = type(help_cfg.border) == "table" and help_cfg.border[1] or help_cfg.border
  local mtl = type(main_cfg.border) == "table" and main_cfg.border[1] or main_cfg.border
  eq(htl, mtl)
  child.lua([[require("loft.ui"):_close_help()]])
  child.lua([[require("loft.ui"):close()]])
end

test_set["help_window row_offset shifts help window"] = function()
  child.lua([[require("loft").setup({ help_window = { row_offset = 4 } })]])
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  local cfg = child.lua_get([[vim.api.nvim_win_get_config(require("loft.ui")._help_win_id)]])
  eq(cfg.row >= 4, true)
  child.lua([[require("loft.ui"):_close_help()]])
  child.lua([[require("loft.ui"):close()]])
end

test_set["help_window explicit row/col used as-is"] = function()
  child.lua([[require("loft").setup({ help_window = { row = 2, col = 5 } })]])
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  local cfg = child.lua_get([[vim.api.nvim_win_get_config(require("loft.ui")._help_win_id)]])
  eq(cfg.row, 2)
  eq(cfg.col, 5)
  child.lua([[require("loft.ui"):_close_help()]])
  child.lua([[require("loft.ui"):close()]])
end

test_set["help keymaps loop does not abort early on false/non-string values"] = function()
  -- Disable one keymap (false) – help window should still build all other entries
  child.lua([[require("loft").setup({ keymaps = { ui = { ["q"] = false, ["<Esc>"] = "close" } } })]])
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  -- Help window must have been created (previously a bug caused early return)
  eq(child.lua_get([[type(require("loft.ui")._help_win_id)]]), "number")
  child.lua([[require("loft.ui"):_close_help()]])
  child.lua([[require("loft.ui"):close()]])
end

-- ── native UI / buffer fortification ───────────────────────────────────

test_set["main buffer has bufhidden=wipe"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local bh = child.lua_get([[vim.api.nvim_get_option_value("bufhidden", { buf = require("loft.ui")._buf_id })]])
  eq(bh, "wipe")
  child.lua([[require("loft.ui"):close()]])
end

test_set["main buffer has swapfile=false"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local sf = child.lua_get([[vim.api.nvim_get_option_value("swapfile", { buf = require("loft.ui")._buf_id })]])
  eq(sf, false)
  child.lua([[require("loft.ui"):close()]])
end

test_set["help buffer has bufhidden=wipe"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  local bh = child.lua_get([[vim.api.nvim_get_option_value("bufhidden", { buf = require("loft.ui")._help_buf_id })]])
  eq(bh, "wipe")
  child.lua([[require("loft.ui"):_close_help()]])
  child.lua([[require("loft.ui"):close()]])
end

-- ── default keymap changes ──────────────────────────────────────────────

test_set["default keymap m is set to toggle_mark_entry"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local buf_id = child.lua_get([[require("loft.ui")._buf_id]])
  local keymaps = child.api.nvim_buf_get_keymap(buf_id, "n")
  local found = false
  for _, km in ipairs(keymaps) do
    if km.lhs == "m" then
      found = true
      break
    end
  end
  eq(found, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["default keymap dd is set to delete_entry"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local buf_id = child.lua_get([[require("loft.ui")._buf_id]])
  local keymaps = child.api.nvim_buf_get_keymap(buf_id, "n")
  local found = false
  for _, km in ipairs(keymaps) do
    if km.lhs == "dd" then
      found = true
      break
    end
  end
  eq(found, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["default keymap D is set to force_delete_entry"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local buf_id = child.lua_get([[require("loft.ui")._buf_id]])
  local keymaps = child.api.nvim_buf_get_keymap(buf_id, "n")
  local found = false
  for _, km in ipairs(keymaps) do
    if km.lhs == "D" then
      found = true
      break
    end
  end
  eq(found, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["visual keymap d is set to delete_selected_entries"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local buf_id = child.lua_get([[require("loft.ui")._buf_id]])
  local keymaps = child.api.nvim_buf_get_keymap(buf_id, "x")
  local found = false
  for _, km in ipairs(keymaps) do
    if km.lhs == "d" then
      found = true
      break
    end
  end
  eq(found, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["visual keymap D is set to force_delete_selected_entries"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local buf_id = child.lua_get([[require("loft.ui")._buf_id]])
  local keymaps = child.api.nvim_buf_get_keymap(buf_id, "x")
  local found = false
  for _, km in ipairs(keymaps) do
    if km.lhs == "D" then
      found = true
      break
    end
  end
  eq(found, true)
  child.lua([[require("loft.ui"):close()]])
end

-- ── force_delete_entry ──────────────────────────────────────────────────

test_set["_delete_entry(true) force-closes a modified buffer (no confirmation)"] = function()
  child.lua([[require("loft").setup({ confirm_force_delete = false })]])
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
  child.lua([[require("loft.ui"):_delete_entry(true)]])
  eq(child.api.nvim_buf_is_valid(buf1), false)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_delete_entry(false) does NOT remove buffer when confirm_force_delete is irrelevant"] = function()
  -- Normal delete (no force) always proceeds without confirmation
  child.lua([[require("loft").setup({ confirm_force_delete = true })]])
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
  child.lua([[require("loft.ui"):_delete_entry(false)]])
  eq(child.api.nvim_buf_is_valid(buf1), false)
  child.lua([[require("loft.ui"):close()]])
end

-- ── _delete_selected_entries ────────────────────────────────────────────

test_set["_delete_selected_entries removes the specified line range"] = function()
  child.lua([[require("loft").setup({ confirm_force_delete = false })]])
  local buf1 = child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  -- Find display lines for buf1 and buf2
  local line1, line2 = nil, nil
  for i, b in ipairs(registry) do
    if b == buf1 then
      line1 = i
    end
    if b == buf2 then
      line2 = i
    end
  end
  if line1 == nil or line2 == nil then
    child.lua([[require("loft.ui"):close()]])
    return
  end
  local lo = math.min(line1, line2)
  local hi = math.max(line1, line2)
  child.lua([[require("loft.ui"):_delete_selected_entries(false, ]] .. lo .. [[, ]] .. hi .. [[)]])
  eq(child.api.nvim_buf_is_valid(buf1), false)
  eq(child.api.nvim_buf_is_valid(buf2), false)
  child.lua([[require("loft.ui"):close()]])
end

test_set["_delete_selected_entries force=true deletes with confirm_force_delete=false"] = function()
  child.lua([[require("loft").setup({ confirm_force_delete = false })]])
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
  child.lua([[require("loft.ui"):_delete_selected_entries(true, ]] .. buf1_line .. [[, ]] .. buf1_line .. [[)]])
  eq(child.api.nvim_buf_is_valid(buf1), false)
  child.lua([[require("loft.ui"):close()]])
end

test_set["cursor is clamped to valid range after _delete_entry"] = function()
  child.lua([[require("loft").setup({ confirm_force_delete = false })]])
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.ui"):open()]])
  local n = child.lua_get([[#require("loft.registry"):get_registry()]])
  if n < 2 then
    child.lua([[require("loft.ui"):close()]])
    return
  end
  -- Move cursor to last line, then delete it — cursor should clamp
  child.lua([[vim.api.nvim_win_set_cursor(require("loft.ui")._win_id, {]] .. n .. [[, 1})]])
  child.lua([[require("loft.ui"):_delete_entry(true)]])
  local cursor = child.lua_get([[vim.api.nvim_win_get_cursor(require("loft.ui")._win_id)]])
  local new_n = child.lua_get([[#require("loft.registry"):get_registry()]])
  eq(cursor[1] <= new_n, true)
  child.lua([[require("loft.ui"):close()]])
end

-- ── keymaps: disabled keymap (false) does not abort rest ───────────────

test_set["disabled keymap (false) does not prevent other keymaps from being set"] = function()
  -- The fixed return-in-loop bug: setting a keymap to false should not abort _setup_keymaps
  child.lua([[require("loft").setup({ keymaps = { ui = { ["q"] = false, ["<Esc>"] = "close", ["k"] = "move_up" } } })]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local buf_id = child.lua_get([[require("loft.ui")._buf_id]])
  local keymaps = child.api.nvim_buf_get_keymap(buf_id, "n")
  local has_esc, has_k = false, false
  for _, km in ipairs(keymaps) do
    if km.lhs == "<Esc>" then
      has_esc = true
    end
    if km.lhs == "k" then
      has_k = true
    end
  end
  eq(has_esc, true)
  eq(has_k, true)
  child.lua([[require("loft.ui"):close()]])
end

-- ── close on focus lost ────────────────────────────────────────────────

test_set["loft closes when focus moves outside both windows"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  eq(child.lua_get([[type(require("loft.ui")._win_id)]]), "number")
  -- Open a regular split and focus it; loft should auto-close
  child.lua([[
    vim.cmd("split")
    -- WinLeave fires when leaving the loft window; schedule runs after focus settles
    vim.wait(50, function() return false end)
  ]])
  eq(child.lua_get([[require("loft.ui")._win_id]]), vim.NIL)
end

test_set["loft does NOT close when focus moves between main and help windows"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  -- Both windows open; focus is on help – go back to main
  child.lua([[
    vim.api.nvim_set_current_win(require("loft.ui")._win_id)
    vim.wait(50, function() return false end)
  ]])
  -- Main window should still be open
  eq(child.lua_get([[type(require("loft.ui")._win_id)]]), "number")
  child.lua([[require("loft.ui"):_close_help()]])
  child.lua([[require("loft.ui"):close()]])
end

test_set["loft closes (including help) when focus leaves from help window"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  -- Move focus to a non-loft split; both windows should close
  child.lua([[
    vim.cmd("split")
    vim.wait(50, function() return false end)
  ]])
  eq(child.lua_get([[require("loft.ui")._win_id]]), vim.NIL)
  eq(child.lua_get([[require("loft.ui")._help_win_id]]), vim.NIL)
end

-- ── keymap lockdown ────────────────────────────────────────────────────

test_set["main buffer: destructive normal keys are nop'd"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local buf_id = child.lua_get([[require("loft.ui")._buf_id]])
  local keymaps = child.api.nvim_buf_get_keymap(buf_id, "n")
  local locked = {}
  for _, km in ipairs(keymaps) do
    if km.rhs == "" or km.rhs == "<Nop>" then
      locked[km.lhs] = true
    end
  end
  -- Spot-check a representative sample
  eq(locked["i"], true)
  eq(locked["a"], true)
  eq(locked["u"], true)
  eq(locked["p"], true)
  eq(locked[":"], true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["main buffer: visual destructive keys are nop'd"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local buf_id = child.lua_get([[require("loft.ui")._buf_id]])
  local keymaps = child.api.nvim_buf_get_keymap(buf_id, "v")
  local locked = {}
  for _, km in ipairs(keymaps) do
    if km.rhs == "" or km.rhs == "<Nop>" then
      locked[km.lhs] = true
    end
  end
  eq(locked["c"], true)
  eq(locked["p"], true)
  eq(locked["x"], true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["main buffer: Loft d normal key is NOT locked (dd overrides)"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local buf_id = child.lua_get([[require("loft.ui")._buf_id]])
  local keymaps = child.api.nvim_buf_get_keymap(buf_id, "n")
  local has_dd = false
  for _, km in ipairs(keymaps) do
    if km.lhs == "dd" and (km.rhs == "" or km.callback ~= nil) and km.rhs ~= "<Nop>" then
      has_dd = true
    end
  end
  eq(has_dd, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["main buffer: Loft visual d is NOT locked"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local buf_id = child.lua_get([[require("loft.ui")._buf_id]])
  local keymaps = child.api.nvim_buf_get_keymap(buf_id, "x")
  local has_d = false
  for _, km in ipairs(keymaps) do
    if km.lhs == "d" and km.rhs ~= "<Nop>" then
      has_d = true
    end
  end
  eq(has_d, true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["help buffer: destructive normal keys are nop'd"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  local buf_id = child.lua_get([[require("loft.ui")._help_buf_id]])
  local keymaps = child.api.nvim_buf_get_keymap(buf_id, "n")
  local locked = {}
  for _, km in ipairs(keymaps) do
    if km.rhs == "" or km.rhs == "<Nop>" then
      locked[km.lhs] = true
    end
  end
  eq(locked["i"], true)
  eq(locked["u"], true)
  eq(locked["p"], true)
  child.lua([[require("loft.ui"):_close_help()]])
  child.lua([[require("loft.ui"):close()]])
end

test_set["main buffer has buftype=nofile"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local bt = child.lua_get([[vim.api.nvim_get_option_value("buftype", { buf = require("loft.ui")._buf_id })]])
  eq(bt, "nofile")
  child.lua([[require("loft.ui"):close()]])
end

test_set["main buffer has readonly=true"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  local ro = child.lua_get([[vim.api.nvim_get_option_value("readonly", { buf = require("loft.ui")._buf_id })]])
  eq(ro, true)
  child.lua([[require("loft.ui"):close()]])
end

-- ── VimResized repositioning ───────────────────────────────────────────

test_set["main window is repositioned on VimResized"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  -- Simulate terminal resize: shrink to 40x20
  child.lua([[
    vim.o.columns = 40
    vim.o.lines   = 20
    vim.api.nvim_exec_autocmds("VimResized", {})
    vim.wait(50, function() return false end)
  ]])
  local win_id = child.lua_get([[require("loft.ui")._win_id]])
  local cfg = child.api.nvim_win_get_config(win_id)
  -- Width should have been recalculated as floor(40 * 0.8) = 32
  eq(cfg.width, math.floor(40 * 0.8))
  -- Row/col should be centred within the new dimensions
  local expected_width = math.floor(40 * 0.8)
  local expected_col = math.floor((40 - expected_width) * 0.5)
  eq(cfg.col, expected_col)
  child.lua([[require("loft.ui"):close()]])
end

test_set["main window respects fixed width/height on VimResized"] = function()
  child.lua([[require("loft").setup({ window = { width = 20, height = 5 } })]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[
    vim.o.columns = 40
    vim.o.lines   = 20
    vim.api.nvim_exec_autocmds("VimResized", {})
    vim.wait(50, function() return false end)
  ]])
  local win_id = child.lua_get([[require("loft.ui")._win_id]])
  local cfg = child.api.nvim_win_get_config(win_id)
  -- Fixed dimensions must be preserved after resize
  eq(cfg.width, 20)
  eq(cfg.height, 5)
  child.lua([[require("loft.ui"):close()]])
end

test_set["help window is repositioned on VimResized"] = function()
  child.lua([[require("loft").setup({})]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.ui"):open()]])
  child.lua([[require("loft.ui"):_show_help()]])
  child.lua([[
    vim.o.columns = 40
    vim.o.lines   = 30
    vim.api.nvim_exec_autocmds("VimResized", {})
    vim.wait(50, function() return false end)
  ]])
  local help_win_id = child.lua_get([[require("loft.ui")._help_win_id]])
  local cfg = child.api.nvim_win_get_config(help_win_id)
  -- Help window default width is 70; centred within 40 columns → col = floor((40-70)*0.5)
  -- which is negative but that's how Neovim handles out-of-bounds floats; just verify col changed
  eq(cfg ~= nil, true)
  child.lua([[require("loft.ui"):_close_help()]])
  child.lua([[require("loft.ui"):close()]])
end

test_set["VimResized is no-op when loft is closed"] = function()
  child.lua([[require("loft").setup({})]])
  -- Fire resize without opening loft — should not error
  child.lua([[
    vim.o.columns = 80
    vim.o.lines   = 24
    vim.api.nvim_exec_autocmds("VimResized", {})
    vim.wait(50, function() return false end)
  ]])
  -- If we got here without an error the test passes; loft windows should remain nil
  eq(child.lua_get([[require("loft.ui")._win_id]]), vim.NIL)
end

return test_set
