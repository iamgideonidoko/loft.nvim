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

test_set["Loft exposes Logs API"] = function()
  eq(child.lua_get([[type(require("loft").logs.toggle)]]), "function")
end

test_set["Logs opens a fixed-height non-editable messages split"] = function()
  child.lua([[require("loft").logs.open()]])
  local win = child.api.nvim_get_current_win()
  local buf = child.api.nvim_get_current_buf()
  eq(child.api.nvim_win_get_height(win), 12)
  eq(child.api.nvim_get_option_value("buftype", { buf = buf }), "nofile")
  eq(child.api.nvim_get_option_value("bufhidden", { buf = buf }), "hide")
  eq(child.api.nvim_get_option_value("modifiable", { buf = buf }), false)
  eq(child.api.nvim_get_option_value("readonly", { buf = buf }), true)
  eq(child.api.nvim_get_option_value("filetype", { buf = buf }), "messages")
  eq(child.api.nvim_get_option_value("winfixheight", { win = win }), true)
  eq(child.api.nvim_get_option_value("number", { win = win }), false)
  eq(child.api.nvim_get_option_value("relativenumber", { win = win }), false)
  eq(child.api.nvim_get_option_value("signcolumn", { win = win }), "no")
  eq(child.api.nvim_get_option_value("foldcolumn", { win = win }), "0")
  eq(child.api.nvim_get_option_value("spell", { win = win }), false)
  eq(child.api.nvim_get_option_value("list", { win = win }), false)
  if child.fn.exists("+winfixbuf") == 1 then
    eq(child.lua_get([[vim.wo.winfixbuf]]), true)
  end
  child.lua([[require("loft").logs.close()]])
end

test_set["Logs refreshes from messages"] = function()
  child.lua([[
    vim.notify("loft logs test message")
    require("loft").logs.open()
    require("loft").logs.refresh()
  ]])
  eq(
    child.lua_get([[
    table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false), "\n")
      :find("loft logs test message", 1, true) ~= nil
  ]]),
    true
  )
  child.lua([[require("loft").logs.close()]])
end

test_set["Logs toggle closes and reuses its hidden buffer"] = function()
  child.lua([[require("loft").logs.toggle()]])
  local buf = child.api.nvim_get_current_buf()
  child.lua([[require("loft").logs.toggle()]])
  eq(child.lua_get([[require("loft").logs.is_open()]]), false)
  eq(child.api.nvim_buf_is_valid(buf), true)
  child.lua([[require("loft").logs.toggle()]])
  eq(child.api.nvim_get_current_buf(), buf)
  child.lua([[require("loft").logs.close()]])
end

test_set["Logs q mapping closes panel"] = function()
  child.lua([[require("loft").logs.open()]])
  child.cmd("normal q")
  eq(child.lua_get([[require("loft").logs.is_open()]]), false)
end

test_set["close action safely closes Logs panel"] = function()
  child.lua([[
    local logs = require("loft").logs
    logs.open()
    _G.loft_logs_buf = vim.api.nvim_get_current_buf()
    require("loft.actions").close_buffer({ force = true })
  ]])
  eq(child.lua_get([[require("loft").logs.is_open()]]), false)
  eq(child.lua_get([[vim.api.nvim_buf_is_valid(_G.loft_logs_buf)]]), true)
end

test_set["Logs panel rejects foreign buffers"] = function()
  child.lua([[
    local logs = require("loft").logs
    logs.open()
    _G.loft_logs_win = vim.api.nvim_get_current_win()
    _G.loft_logs_buf = vim.api.nvim_get_current_buf()
    _G.loft_logs_foreign = vim.api.nvim_create_buf(true, false)
    if vim.fn.exists("+winfixbuf") == 1 then
      vim.wo.winfixbuf = false
    end
    pcall(vim.cmd, "buffer " .. _G.loft_logs_foreign)
    vim.wait(100, function()
      return vim.api.nvim_win_get_buf(_G.loft_logs_win) == _G.loft_logs_buf
    end)
  ]])
  eq(child.lua_get([[vim.api.nvim_win_get_buf(_G.loft_logs_win)]]), child.lua_get([[_G.loft_logs_buf]]))
  eq(
    child.lua_get([[
    vim.api.nvim_get_current_win() ~= _G.loft_logs_win
      and vim.api.nvim_get_current_buf() == _G.loft_logs_foreign
  ]]),
    true
  )
  child.lua([[require("loft").logs.close()]])
end

test_set["Logs focus opens or navigates to panel"] = function()
  child.lua([[require("loft").logs.focus()]])
  eq(child.lua_get([[require("loft").logs.is_open()]]), true)
  child.lua([[
    _G.loft_logs_win = vim.api.nvim_get_current_win()
    vim.cmd("wincmd w")
    require("loft").logs.focus()
  ]])
  eq(child.lua_get([[vim.api.nvim_get_current_win() == _G.loft_logs_win]]), true)
  child.lua([[require("loft").logs.close()]])
end

test_set["Logs window cannot be duplicated"] = function()
  child.lua([[
    require("loft").logs.open()
    _G.loft_logs_buf = vim.api.nvim_get_current_buf()
    _G.loft_logs_win = vim.api.nvim_get_current_win()
    vim.cmd("split")
    vim.wait(100, function()
      local n = 0
      for _, w in ipairs(vim.fn.win_findbuf(_G.loft_logs_buf)) do
        if vim.api.nvim_win_is_valid(w) then
          n = n + 1
        end
      end
      return n <= 1
    end)
  ]])
  eq(child.lua_get([[require("loft").logs.is_open()]]), true)
  eq(child.lua_get([[vim.api.nvim_get_current_win() == _G.loft_logs_win]]), true)
  eq(
    child.lua_get([[
      (function()
        local n = 0
        for _, w in ipairs(vim.fn.win_findbuf(_G.loft_logs_buf)) do
          if vim.api.nvim_win_is_valid(w) then
            n = n + 1
          end
        end
        return n
      end)()
    ]]),
    1
  )
  child.lua([[require("loft").logs.close()]])
end

test_set["Logs respects custom height"] = function()
  child.lua([[require("loft").setup({ logs = { height = 8 } })]])
  child.lua([[require("loft").logs.open()]])
  eq(child.api.nvim_win_get_height(child.api.nvim_get_current_win()), 8)
  child.lua([[require("loft").logs.close()]])
end

test_set["Logs refresh preserves view when not at end"] = function()
  child.lua([[
    for i = 1, 5 do
      vim.notify("log message " .. i)
    end
    require("loft").logs.open()
    require("loft").logs.refresh()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_cursor(win, { 2, 0 })
    vim.notify("new message")
    require("loft").logs.refresh()
  ]])
  eq(child.lua_get([=[vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1]]=]), 2)
  child.lua([[require("loft").logs.close()]])
end

test_set["Logs refresh auto-scrolls when at end"] = function()
  child.lua([[
    for i = 1, 5 do
      vim.notify("log message " .. i)
    end
    require("loft").logs.open()
    require("loft").logs.refresh()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()
    local line_count = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_win_set_cursor(win, { line_count, 0 })
    vim.notify("new message")
    require("loft").logs.refresh()
    _G.loft_new_line_count = vim.api.nvim_buf_line_count(buf)
  ]])
  eq(
    child.lua_get([=[vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1]]=]),
    child.lua_get([[_G.loft_new_line_count]])
  )
  child.lua([[require("loft").logs.close()]])
end

test_set["Logs refresh does not auto-scroll when follow is false"] = function()
  child.lua([[require("loft").setup({ logs = { follow = false } })]])
  child.lua([[
    for i = 1, 5 do
      vim.notify("log message " .. i)
    end
    require("loft").logs.open()
    require("loft").logs.refresh()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
    vim.notify("new message")
    require("loft").logs.refresh()
  ]])
  eq(child.lua_get([=[vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1]]=]), 1)
  child.lua([[require("loft").logs.close()]])
end

test_set["Logs buffer has R refresh command"] = function()
  child.lua([[require("loft").logs.open()]])
  local buf = child.api.nvim_get_current_buf()
  eq(child.lua_get(([[vim.api.nvim_buf_get_commands(%d, {}).R ~= nil]]):format(buf)), true)
  child.lua([[require("loft").logs.close()]])
end

test_set["default Logs mapping is <leader>ll"] = function()
  eq(child.lua_get([[vim.fn.maparg("<leader>ll", "n") ~= ""]]), true)
end

return test_set
