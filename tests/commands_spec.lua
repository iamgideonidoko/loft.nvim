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

-- ── :LoftToggle ────────────────────────────────────────────────────────

test_set["LoftToggle opens UI when closed"] = function()
  child.api.nvim_create_buf(true, true)
  child.cmd("LoftToggle")
  eq(child.lua_get([[require("loft.ui"):is_open()]]), true)
  child.lua([[require("loft.ui"):close()]])
end

test_set["LoftToggle closes UI when open"] = function()
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.ui"):open()]])
  child.cmd("LoftToggle")
  eq(child.lua_get([[require("loft.ui"):is_open()]]), false)
end

test_set["LoftToggle is idempotent across two calls"] = function()
  child.api.nvim_create_buf(true, true)
  child.cmd("LoftToggle")
  child.cmd("LoftToggle")
  eq(child.lua_get([[require("loft.ui"):is_open()]]), false)
end

-- ── :LoftToggleSmartOrder ──────────────────────────────────────────────

test_set["LoftToggleSmartOrder turns smart order off"] = function()
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), true)
  child.cmd("LoftToggleSmartOrder")
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), false)
end

test_set["LoftToggleSmartOrder turns smart order back on"] = function()
  child.cmd("LoftToggleSmartOrder")
  child.cmd("LoftToggleSmartOrder")
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), true)
end

test_set["LoftToggleSmartOrder fires LoftSmartOrderToggle event"] = function()
  child.lua([[
    _G.loft_cmd_sot = nil
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftSmartOrderToggle",
      callback = function(ev) _G.loft_cmd_sot = ev.data.smart_order_state end,
    })
  ]])
  child.cmd("LoftToggleSmartOrder")
  eq(child.lua_get([[_G.loft_cmd_sot]]), false)
end

-- ── :LoftToggleMark ────────────────────────────────────────────────────

test_set["LoftToggleMark marks current buffer"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(buf)
  child.cmd("LoftToggleMark")
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
end

test_set["LoftToggleMark unmarks already marked buffer"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(buf)
  child.cmd("LoftToggleMark")
  child.cmd("LoftToggleMark")
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), false)
end

test_set["LoftToggleMark fires LoftBufferMark event"] = function()
  child.lua([[
    _G.loft_cmd_mark_fired = false
    vim.api.nvim_create_autocmd("User", {
      pattern = "LoftBufferMark",
      callback = function() _G.loft_cmd_mark_fired = true end,
    })
  ]])
  local buf = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(buf)
  child.cmd("LoftToggleMark")
  eq(child.lua_get([[_G.loft_cmd_mark_fired]]), true)
end

return test_set
