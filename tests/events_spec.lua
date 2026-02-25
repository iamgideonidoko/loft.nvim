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

-- ── buffer_mark event ──────────────────────────────────────────────────

test_set["buffer_mark fires LoftBufferMark autocmd"] = function()
  child.lua([[
    _G.loft_test_mark_fired = false
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftBufferMark",
      callback = function() _G.loft_test_mark_fired = true end,
    })
  ]])
  local buf = child.api.nvim_get_current_buf()
  child.lua([[require("loft.events").buffer_mark(]] .. buf .. [[, true)]])
  eq(child.lua_get([[_G.loft_test_mark_fired]]), true)
end

test_set["buffer_mark passes buffer and mark_state true in event data"] = function()
  child.lua([[
    _G.loft_test_mark_data = nil
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftBufferMark",
      callback = function(ev) _G.loft_test_mark_data = ev.data end,
    })
  ]])
  local buf = child.api.nvim_get_current_buf()
  child.lua([[require("loft.events").buffer_mark(]] .. buf .. [[, true)]])
  eq(child.lua_get([[_G.loft_test_mark_data.mark_state]]), true)
  eq(child.lua_get([[_G.loft_test_mark_data.buffer]]), buf)
end

test_set["buffer_mark passes mark_state false in event data"] = function()
  child.lua([[
    _G.loft_test_mark_state = nil
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftBufferMark",
      callback = function(ev) _G.loft_test_mark_state = ev.data.mark_state end,
    })
  ]])
  local buf = child.api.nvim_get_current_buf()
  child.lua([[require("loft.events").buffer_mark(]] .. buf .. [[, false)]])
  eq(child.lua_get([[_G.loft_test_mark_state]]), false)
end

test_set["buffer_mark reflects actual mark state after toggle"] = function()
  child.lua([[
    _G.loft_test_mark_states = {}
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftBufferMark",
      callback = function(ev)
        table.insert(_G.loft_test_mark_states, ev.data.mark_state)
      end,
    })
  ]])
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[_G.loft_test_mark_states]] .. "[ 1]"), true)
  eq(child.lua_get([[_G.loft_test_mark_states]] .. "[ 2]"), false)
end

-- ── smart_order_toggle event ───────────────────────────────────────────

test_set["smart_order_toggle fires LoftSmartOrderToggle autocmd"] = function()
  child.lua([[
    _G.loft_test_sot_fired = false
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftSmartOrderToggle",
      callback = function() _G.loft_test_sot_fired = true end,
    })
  ]])
  child.lua([[require("loft.events").smart_order_toggle(false)]])
  eq(child.lua_get([[_G.loft_test_sot_fired]]), true)
end

test_set["smart_order_toggle passes state true in event data"] = function()
  child.lua([[
    _G.loft_test_sot_state = nil
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftSmartOrderToggle",
      callback = function(ev) _G.loft_test_sot_state = ev.data.smart_order_state end,
    })
  ]])
  child.lua([[require("loft.events").smart_order_toggle(true)]])
  eq(child.lua_get([[_G.loft_test_sot_state]]), true)
end

test_set["smart_order_toggle passes state false in event data"] = function()
  child.lua([[
    _G.loft_test_sot_state = nil
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftSmartOrderToggle",
      callback = function(ev) _G.loft_test_sot_state = ev.data.smart_order_state end,
    })
  ]])
  child.lua([[require("loft.events").smart_order_toggle(false)]])
  eq(child.lua_get([[_G.loft_test_sot_state]]), false)
end

test_set["smart_order_toggle fires on registry toggle_smart_order"] = function()
  child.lua([[
    _G.loft_test_sot_via_registry = nil
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftSmartOrderToggle",
      callback = function(ev) _G.loft_test_sot_via_registry = ev.data.smart_order_state end,
    })
  ]])
  child.lua([[require("loft.registry"):toggle_smart_order()]])
  eq(child.lua_get([[_G.loft_test_sot_via_registry]]), false)
end

return test_set
