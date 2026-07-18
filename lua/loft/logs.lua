local utils = require("loft.utils")

local logs = {}
local state = {
  buf = nil,
  timer = nil,
  last_win = nil,
  win = nil,
}

local function valid_buffer()
  return utils.buffer_exists(state.buf)
end

local function log_windows()
  if not valid_buffer() then
    return {}
  end

  local windows = {}
  for _, win in ipairs(vim.fn.win_findbuf(state.buf)) do
    if utils.window_exists(win) and vim.api.nvim_win_get_buf(win) == state.buf then
      table.insert(windows, win)
    end
  end
  return windows
end

local function stop_timer()
  local timer = state.timer
  state.timer = nil

  if timer and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

local function messages()
  if vim.api.nvim_exec2 then
    return vim.api.nvim_exec2("messages", { output = true }).output
  end
  return vim.api.nvim_exec("messages", true)
end

local function ensure_buffer()
  if valid_buffer() then
    return state.buf
  end

  local buf = vim.api.nvim_create_buf(false, true)
  state.buf = buf
  vim.api.nvim_buf_set_name(buf, "Loft Logs")
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "messages"
  utils.buffer_modifiable(buf, false)
  vim.keymap.set("n", "q", logs.close, { buffer = buf, silent = true })

  return buf
end

--- Refresh Logs panel from `:messages`.
---@type fun()
function logs.refresh()
  if not valid_buffer() then
    return
  end

  local lines = vim.split(messages(), "\n", { plain = true })
  if vim.deep_equal(vim.api.nvim_buf_get_lines(state.buf, 0, -1, false), lines) then
    return
  end

  utils.buffer_modifiable(state.buf, true)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  utils.buffer_modifiable(state.buf, false)

  local last_line = vim.api.nvim_buf_line_count(state.buf)
  for _, win in ipairs(log_windows()) do
    vim.api.nvim_win_set_cursor(win, { last_line, 0 })
  end
end

local function start_timer()
  if state.timer or #log_windows() == 0 then
    return
  end

  local timer = (vim.uv or vim.loop).new_timer()
  state.timer = timer
  timer:start(
    0,
    1000,
    vim.schedule_wrap(function()
      if state.timer ~= timer then
        return
      end
      if #log_windows() == 0 then
        stop_timer()
        return
      end
      logs.refresh()
    end)
  )
end

--- Check whether Logs panel is visible.
---@type fun(): boolean
function logs.is_open()
  return #log_windows() > 0
end

---@private
function logs.is_buffer(buf)
  return valid_buffer() and state.buf == buf
end

--- Open Logs panel.
---@type fun()
function logs.open()
  local windows = log_windows()
  if #windows > 0 then
    state.win = windows[1]
    vim.api.nvim_set_current_win(windows[1])
    logs.refresh()
    start_timer()
    return
  end

  local buf = ensure_buffer()
  state.last_win = vim.api.nvim_get_current_win()
  vim.cmd("botright 12split")
  local win = vim.api.nvim_get_current_win()
  state.win = win
  if vim.fn.exists("+winfixbuf") == 1 then
    vim.wo[win].winfixbuf = false
  end
  vim.api.nvim_win_set_buf(win, buf)
  vim.wo[win].winfixheight = true
  if vim.fn.exists("+winfixbuf") == 1 then
    vim.wo[win].winfixbuf = true
  end
  logs.refresh()
  start_timer()
end

--- Close Logs panel.
---@type fun()
function logs.close()
  for _, win in ipairs(log_windows()) do
    vim.api.nvim_win_close(win, false)
  end
  if not logs.is_open() then
    stop_timer()
  end
  state.win = nil
end

--- Toggle Logs panel.
---@type fun()
function logs.toggle()
  if logs.is_open() then
    logs.close()
  else
    logs.open()
  end
end

function logs.setup()
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = utils.get_augroup("LogsPreventOverride", true),
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if not utils.window_exists(win) or vim.api.nvim_win_get_buf(win) == state.buf then
        return
      end

      local log_win = state.win
      if log_win == win and utils.window_exists(state.last_win) then
        local foreign_buf = vim.api.nvim_get_current_buf()
        vim.schedule(function()
          if utils.window_exists(log_win) and valid_buffer() and vim.api.nvim_win_get_buf(log_win) == foreign_buf then
            vim.api.nvim_win_set_buf(log_win, state.buf)
            vim.api.nvim_win_set_buf(state.last_win, foreign_buf)
            vim.api.nvim_set_current_win(state.last_win)
          end
        end)
        return
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "WinClosed", "BufWipeout" }, {
    group = utils.get_augroup("LogsLifecycle", true),
    callback = function(args)
      if args.event == "BufWipeout" and args.buf == state.buf then
        state.buf = nil
      end
      if args.event == "WinClosed" and tonumber(args.match) == state.win then
        state.win = nil
      end
      if not logs.is_open() then
        stop_timer()
      end
    end,
  })
end

return logs
