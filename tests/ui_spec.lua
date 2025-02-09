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

return test_set
