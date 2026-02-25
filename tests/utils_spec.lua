local helper = require("loft.test_helper")
local utils = require("loft.utils")

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

test_set["is_floating_window"] = function()
  child.lua([[vim.cmd("new")]])
  local win = child.api.nvim_get_current_win()
  eq(child.lua_get([[require("loft.utils").is_floating_window()]]), false)
  child.api.nvim_win_set_config(win, { relative = "editor", row = 1, col = 1, width = 1, height = 1 })
  eq(child.lua_get([[require("loft.utils").is_floating_window()]]), true)
end

test_set["merge_distinct"] = function()
  eq(utils.merge_distinct({ 1, 2, 3 }, { 2, 3, 4 }), { 1, 2, 3, 4 })
end

test_set["get_index"] = function()
  local list = { 1, 2, 3 }
  eq(utils.get_index(list, 2), 2)
  eq(utils.get_index(list, 4), nil)
end

test_set["table_includes"] = function()
  local list = { 1, 2, 3 }
  eq(utils.table_includes(list, 2), true)
  eq(utils.table_includes(list, 4), false)
end

test_set["buffer_exists"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  eq(child.lua_get([[require("loft.utils").buffer_exists(]] .. buf .. [[)]]), true)
  child.api.nvim_buf_delete(buf, { force = true })
  eq(child.lua_get([[require("loft.utils").buffer_exists(]] .. buf .. [[)]]), false)
end

test_set["buffer_modifiable"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  child.lua([[require("loft.utils").buffer_modifiable(]] .. buf .. [[, false)]])
  eq(child.api.nvim_buf_get_option(buf, "modifiable"), false)
  child.lua([[require("loft.utils").buffer_modifiable(]] .. buf .. [[, true)]])
  eq(child.api.nvim_buf_get_option(buf, "modifiable"), true)
end

test_set["is_buffer_valid listed buffer"] = function()
  local buf = child.api.nvim_create_buf(true, false)
  eq(child.lua_get([[require("loft.utils").is_buffer_valid(]] .. buf .. [[)]]), true)
  child.api.nvim_buf_delete(buf, { force = true })
  eq(child.lua_get([[require("loft.utils").is_buffer_valid(]] .. buf .. [[)]]), false)
end

test_set["is_buffer_valid unlisted buffer"] = function()
  local buf = child.api.nvim_create_buf(false, false)
  eq(child.lua_get([[require("loft.utils").is_buffer_valid(]] .. buf .. [[)]]), false)
end

test_set["get_all_valid_buffers"] = function()
  local initial_count = child.lua_get([[#require("loft.utils").get_all_valid_buffers()]])
  local buf = child.api.nvim_create_buf(true, false)
  eq(child.lua_get([[#require("loft.utils").get_all_valid_buffers()]]), initial_count + 1)
  child.api.nvim_buf_delete(buf, { force = true })
  eq(child.lua_get([[#require("loft.utils").get_all_valid_buffers()]]), initial_count)
end

test_set["window_exists valid window"] = function()
  local win = child.api.nvim_get_current_win()
  eq(child.lua_get([[require("loft.utils").window_exists(]] .. win .. [[)]]), true)
end

test_set["window_exists invalid window"] = function()
  eq(child.lua_get([[require("loft.utils").window_exists(99999)]]), false)
end

test_set["window_exists nil"] = function()
  eq(child.lua_get([[require("loft.utils").window_exists(nil)]]), false)
end

test_set["get_augroup returns a number"] = function()
  eq(child.lua_get([[type(require("loft.utils").get_augroup("TestGroup", true))]]), "number")
end

test_set["in_temp_directory cache path"] = function()
  -- vim.fn.stdpath("cache") is always set, comes before any nil env vars in the list
  local cache = vim.fn.stdpath("cache")
  eq(utils.in_temp_directory(cache .. "/test_file.lua"), true)
end

test_set["in_temp_directory normal path"] = function()
  eq(utils.in_temp_directory("/home/user/projects/file.lua"), false)
end

test_set["buf_has_deleted_file scratch buffer"] = function()
  -- scratch buffer has buftype=nofile, never treated as deleted file
  local buf = child.api.nvim_create_buf(true, true)
  eq(child.lua_get([[require("loft.utils").buf_has_deleted_file(]] .. buf .. [[)]]), false)
  child.api.nvim_buf_delete(buf, { force = true })
end

test_set["buf_has_deleted_file no-name buffer"] = function()
  -- buffer with no file path cannot have a deleted file
  local buf = child.api.nvim_create_buf(true, false)
  eq(child.lua_get([[require("loft.utils").buf_has_deleted_file(]] .. buf .. [[)]]), false)
  child.api.nvim_buf_delete(buf, { force = true })
end

test_set["get_nvim_version returns integers"] = function()
  local major, minor, patch = utils.get_nvim_version()
  eq(type(major), "number")
  eq(type(minor), "number")
  eq(type(patch), "number")
  eq(major >= 0, true)
  eq(minor >= 0, true)
  eq(patch >= 0, true)
end

test_set["is_dev returns false without lazy"] = function()
  eq(utils.is_dev(), false)
end

test_set["greedy_debounce executes first call immediately"] = function()
  local count = 0
  local fn = utils.greedy_debounce(function()
    count = count + 1
  end, 10000)
  fn()
  eq(count, 1)
end

test_set["greedy_debounce suppresses rapid subsequent calls"] = function()
  local count = 0
  local fn = utils.greedy_debounce(function()
    count = count + 1
  end, 10000)
  fn()
  fn()
  fn()
  eq(count, 1)
end

test_set["buffer_exists nil returns false"] = function()
  eq(child.lua_get([[require("loft.utils").buffer_exists(nil)]]), false)
end

test_set["merge_distinct empty tables"] = function()
  eq(utils.merge_distinct({}, {}), {})
end

test_set["merge_distinct empty first table"] = function()
  eq(utils.merge_distinct({}, { 1, 2 }), { 1, 2 })
end

test_set["merge_distinct empty second table"] = function()
  eq(utils.merge_distinct({ 1, 2 }, {}), { 1, 2 })
end

test_set["debounce calls function after timeout"] = function()
  helper.skip_in_ci()
  child.lua([[
    _G.loft_debounce_count = 0
    local fn = require("loft.utils").debounce(function()
      _G.loft_debounce_count = _G.loft_debounce_count + 1
    end, 50)
    fn()
    vim.wait(500, function() return _G.loft_debounce_count > 0 end)
  ]])
  eq(child.lua_get([[_G.loft_debounce_count]]), 1)
end

test_set["debounce only fires once for rapid calls"] = function()
  helper.skip_in_ci()
  child.lua([[
    _G.loft_debounce_count2 = 0
    local fn = require("loft.utils").debounce(function()
      _G.loft_debounce_count2 = _G.loft_debounce_count2 + 1
    end, 100)
    fn()
    fn()
    fn()
    vim.wait(600, function() return _G.loft_debounce_count2 > 0 end)
  ]])
  eq(child.lua_get([[_G.loft_debounce_count2]]), 1)
end

return test_set
