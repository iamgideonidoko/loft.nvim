---@diagnostic disable: invisible
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

test_set["adds buffers correctly"] = function()
  child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.registry"):clean()]])
  eq(child.lua_get([[#require("loft.registry"):get_registry()]]), 2)
end

return test_set
