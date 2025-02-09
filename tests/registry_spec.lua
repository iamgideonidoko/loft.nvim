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

return test_set
