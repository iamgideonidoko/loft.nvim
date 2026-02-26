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

-- ── :LoftCloseOthers ────────────────────────────────────────────────────

test_set["LoftCloseOthers closes all buffers except current"] = function()
  local buf1 = child.api.nvim_create_buf(true, false)
  local buf2 = child.api.nvim_create_buf(true, false)
  local buf3 = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(buf2)
  child.cmd("LoftCloseOthers")
  eq(child.api.nvim_buf_is_valid(buf2), true)
  eq(child.api.nvim_buf_is_valid(buf1), false)
  eq(child.api.nvim_buf_is_valid(buf3), false)
end

test_set["LoftCloseOthers keeps current buffer in registry"] = function()
  child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  local buf_keep = child.api.nvim_create_buf(true, false)
  child.api.nvim_set_current_buf(buf_keep)
  child.cmd("LoftCloseOthers")
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local found = false
  for _, b in ipairs(registry) do
    if b == buf_keep then
      found = true
    end
  end
  eq(found, true)
  eq(#registry, 1)
end

-- ── :LoftCloseUnmarked ──────────────────────────────────────────────────

test_set["LoftCloseUnmarked closes only unmarked buffers"] = function()
  child.lua([[require("loft.registry"):clean()]])
  local buf_marked = child.api.nvim_create_buf(true, false)
  local buf_plain = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf_marked .. [[)]])
  child.cmd("LoftCloseUnmarked")
  eq(child.api.nvim_buf_is_valid(buf_marked), true)
  eq(child.api.nvim_buf_is_valid(buf_plain), false)
end

test_set["LoftCloseUnmarked leaves marked buffers in registry"] = function()
  child.lua([[require("loft.registry"):clean()]])
  local buf_marked = child.api.nvim_create_buf(true, false)
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf_marked .. [[)]])
  child.cmd("LoftCloseUnmarked")
  local registry = child.lua_get([[require("loft.registry"):get_registry()]])
  local found = false
  for _, b in ipairs(registry) do
    if b == buf_marked then
      found = true
    end
  end
  eq(found, true)
end

return test_set
