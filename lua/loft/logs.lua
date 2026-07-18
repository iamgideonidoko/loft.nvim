local utils = require("loft.utils")

local logs = {}
local state = {
  buf = nil,
  timer = nil,
  last_win = nil,
  win = nil,
  last_output = nil,
}

local function valid_buffer()
  return state.buf and state.buf > 0 and utils.buffer_exists(state.buf)
end

local function log_windows()
  if not valid_buffer() then
    return {}
  end

  local ok, wins = pcall(vim.fn.win_findbuf, state.buf)
  if not ok or type(wins) ~= "table" then
    return {}
  end

  local windows = {}
  for _, win in ipairs(wins) do
    win = tonumber(win)
    if win and win > 0 then
      local win_ok, exists = pcall(utils.window_exists, win)
      if win_ok and exists then
        local buf_ok, buf = pcall(vim.api.nvim_win_get_buf, win)
        if buf_ok and buf == state.buf then
          table.insert(windows, win)
        end
      end
    end
  end
  return windows
end

local function stop_timer()
  local timer = state.timer
  state.timer = nil

  if timer and not timer:is_closing() then
    pcall(timer.stop, timer)
    pcall(timer.close, timer)
  end
end

local function messages()
  local ok, result = pcall(function()
    if vim.api.nvim_exec2 then
      return vim.api.nvim_exec2("messages", { output = true }).output
    end
    return vim.api.nvim_exec("messages", true)
  end)
  if ok and type(result) == "string" then
    return result
  end
  return ""
end

local function ensure_buffer()
  if valid_buffer() then
    return state.buf
  end

  local buf = vim.api.nvim_create_buf(false, true)
  state.buf = buf
  state.last_output = nil
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

  local content = messages()
  if type(content) ~= "string" then
    return
  end

  if content == state.last_output then
    return
  end

  local split_ok, lines = pcall(vim.split, content, "\n", { plain = true })
  if not split_ok or type(lines) ~= "table" then
    return
  end

  local current_ok, current_lines = pcall(vim.api.nvim_buf_get_lines, state.buf, 0, -1, false)
  if current_ok and type(current_lines) == "table" and vim.deep_equal(current_lines, lines) then
    return
  end

  local set_ok = pcall(function()
    utils.buffer_modifiable(state.buf, true)
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    utils.buffer_modifiable(state.buf, false)
  end)
  if not set_ok then
    return
  end

  state.last_output = content

  local count_ok, last_line = pcall(vim.api.nvim_buf_line_count, state.buf)
  if not count_ok or last_line < 1 then
    return
  end

  for _, win in ipairs(log_windows()) do
    pcall(vim.api.nvim_win_set_cursor, win, { last_line, 0 })
  end
end

local function start_timer()
  if state.timer or #log_windows() == 0 then
    return
  end

  local uv = vim.uv or vim.loop
  local timer_ok, timer = pcall(uv.new_timer)
  if not timer_ok or not timer then
    return
  end

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
    pcall(vim.api.nvim_set_current_win, windows[1])
    logs.refresh()
    start_timer()
    return
  end

  local buf = ensure_buffer()
  local last_win_ok, last_win = pcall(vim.api.nvim_get_current_win)
  if not last_win_ok or not last_win or last_win < 1 then
    return
  end
  state.last_win = last_win

  local split_ok = pcall(vim.cmd, "botright 12split")
  if not split_ok then
    return
  end

  local win_ok, win = pcall(vim.api.nvim_get_current_win)
  if not win_ok or not win or win < 1 then
    return
  end

  state.win = win
  if vim.fn.exists("+winfixbuf") == 1 then
    vim.wo[win].winfixbuf = false
  end
  pcall(vim.api.nvim_win_set_buf, win, buf)
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
    pcall(vim.api.nvim_win_close, win, false)
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

--- Open Logs panel or focus existing one.
---@type fun()
function logs.focus()
  local windows = log_windows()
  if #windows == 0 then
    logs.open()
    return
  end

  local current_ok, current_win = pcall(vim.api.nvim_get_current_win)
  if current_ok and current_win and current_win == windows[1] then
    return
  end

  pcall(vim.api.nvim_set_current_win, windows[1])
end

function logs.setup()
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = utils.get_augroup("LogsPreventOverride", true),
    callback = function()
      local win_ok, win = pcall(vim.api.nvim_get_current_win)
      if not win_ok or not win or win < 1 or not utils.window_exists(win) then
        return
      end

      local buf_ok, current_buf = pcall(vim.api.nvim_win_get_buf, win)
      if buf_ok and current_buf == state.buf then
        return
      end

      local log_win = state.win
      if log_win == win and utils.window_exists(state.last_win) then
        local foreign_buf = vim.api.nvim_get_current_buf()
        vim.schedule(function()
          if not utils.window_exists(state.last_win) or not utils.window_exists(log_win) or not valid_buffer() then
            return
          end
          local log_buf_ok, log_buf = pcall(vim.api.nvim_win_get_buf, log_win)
          if log_buf_ok and log_buf == foreign_buf then
            pcall(vim.api.nvim_win_set_buf, log_win, state.buf)
            pcall(vim.api.nvim_win_set_buf, state.last_win, foreign_buf)
            pcall(vim.api.nvim_set_current_win, state.last_win)
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
        state.last_output = nil
      end
      local closed_win = args.match and tonumber(args.match)
      if args.event == "WinClosed" and closed_win and closed_win == state.win then
        state.win = nil
      end
      if not logs.is_open() then
        stop_timer()
      end
    end,
  })

  local closing_duplicate = false
  vim.api.nvim_create_autocmd("WinEnter", {
    group = utils.get_augroup("LogsSingleton", true),
    callback = function()
      if closing_duplicate or not valid_buffer() then
        return
      end
      local win_ok, win = pcall(vim.api.nvim_get_current_win)
      if not win_ok or not win or win < 1 then
        return
      end
      local buf_ok, buf = pcall(vim.api.nvim_win_get_buf, win)
      if not buf_ok or buf ~= state.buf then
        return
      end
      if #log_windows() <= 1 then
        return
      end
      closing_duplicate = true
      vim.schedule(function()
        if utils.window_exists(win) then
          pcall(vim.api.nvim_win_close, win, false)
        end
        closing_duplicate = false
      end)
    end,
  })
end

return logs
