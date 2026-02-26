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

-- ── registry_changed event ─────────────────────────────────────────────

test_set["registry_changed fires LoftRegistryChanged autocmd on buffer add"] = function()
  child.lua([[
    _G.loft_test_reg_changed = 0
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftRegistryChanged",
      callback = function() _G.loft_test_reg_changed = _G.loft_test_reg_changed + 1 end,
    })
  ]])
  -- _update() fires on_change() when a new buffer is added
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  -- Trigger an explicit update to fire on_change
  child.lua([[require("loft.registry"):_update()]])
  local count = child.lua_get([[_G.loft_test_reg_changed]])
  eq(count > 0, true)
end

test_set["registry_changed fires LoftRegistryChanged autocmd on toggle_mark"] = function()
  child.lua([[
    _G.loft_test_reg_changed2 = false
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftRegistryChanged",
      callback = function() _G.loft_test_reg_changed2 = true end,
    })
  ]])
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[_G.loft_test_reg_changed2]]), true)
end

-- ── buffer_switch event ────────────────────────────────────────────────

test_set["buffer_switch fires LoftBufferSwitch with correct source and buffer"] = function()
  child.lua([[
    _G.loft_test_switch_data = nil
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftBufferSwitch",
      callback = function(ev) _G.loft_test_switch_data = ev.data end,
    })
  ]])
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.events").buffer_switch(]] .. buf .. [[, "next")]])
  eq(child.lua_get([[_G.loft_test_switch_data.buffer]]), buf)
  eq(child.lua_get([[_G.loft_test_switch_data.source]]), "next")
end

test_set["buffer_switch fires on switch_to_next_buffer action"] = function()
  child.lua([[
    _G.loft_test_next_source = nil
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftBufferSwitch",
      callback = function(ev) _G.loft_test_next_source = ev.data.source end,
    })
  ]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.actions").switch_to_next_buffer()]])
  eq(child.lua_get([[_G.loft_test_next_source]]), "next")
end

test_set["buffer_switch fires on switch_to_prev_buffer action"] = function()
  child.lua([[
    _G.loft_test_prev_source = nil
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftBufferSwitch",
      callback = function(ev) _G.loft_test_prev_source = ev.data.source end,
    })
  ]])
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.actions").switch_to_prev_buffer()]])
  eq(child.lua_get([[_G.loft_test_prev_source]]), "prev")
end

return test_set
