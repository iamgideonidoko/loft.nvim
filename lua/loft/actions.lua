local registry_instance = require("loft.registry")
local utils = require("loft.utils")

local actions = {}

---Delete a buffer without closing splits
---@param opts { force: boolean?, buffer: integer? }?
actions.close_buffer = function(opts)
  opts = opts or {}
  local current_buf = opts.buffer or vim.api.nvim_get_current_buf()
  if not opts.force and vim.api.nvim_get_option_value("modified", { buf = current_buf }) then
    return vim.api.nvim_err_writeln("Buffer is modified. Force required.")
  end
  if not opts.force and vim.api.nvim_get_option_value("buftype", { buf = current_buf }) == "terminal" then
    return vim.api.nvim_err_writeln("Buffer is a terminal. Force required.")
  end
  registry_instance:clean()
  local alt_buf = vim.fn.bufnr("#")
  local next_buf = nil
  local found_current = false
  for _, buf in ipairs(registry_instance:get_registry()) do
    if found_current then
      next_buf = buf
      break
    end
    if buf == current_buf then
      found_current = true
    end
  end
  if #registry_instance:get_registry() > 1 and not next_buf then
    -- The next valid buffer is likely the first
    next_buf = registry_instance:get_registry()[1]
  end
  registry_instance:pause_update()
  -- Replace current buffer with alt or next or empty buffer in all windows
  for _, win in ipairs(vim.fn.win_findbuf(current_buf)) do
    if utils.is_buffer_valid(alt_buf) then
      vim.api.nvim_win_set_buf(win, alt_buf)
    elseif next_buf then
      vim.api.nvim_win_set_buf(win, next_buf)
    else
      vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(false, true))
    end
  end
  pcall(vim.api.nvim_buf_delete, current_buf, { force = opts.force })
  registry_instance:resume_update()
  registry_instance:clean()
end

-- Navigate to the next buffer in registry
actions.switch_to_next_buffer = function()
  registry_instance:clean()
  local next_buf = registry_instance:get_next_buffer()
  if next_buf == nil then
    return
  end
  registry_instance:pause_update()
  vim.api.nvim_set_current_buf(next_buf)
  registry_instance:resume_update()
end

-- Navigate to the previous buffer in registry
actions.switch_to_prev_buffer = function()
  registry_instance:clean()
  local prev_buf = registry_instance:get_prev_buffer()
  if prev_buf == nil then
    return
  end
  registry_instance:pause_update()
  vim.api.nvim_set_current_buf(prev_buf)
  registry_instance:resume_update()
end

actions.open_loft = function()
  require("loft.ui"):open()
end

-- Navigate to the next marked buffer in registry
actions.switch_to_next_marked_buffer = function()
  registry_instance:clean()
  local next_marked_buf = registry_instance:get_marked_buffer("next")
  if next_marked_buf == nil then
    return
  end
  registry_instance:pause_update()
  vim.api.nvim_set_current_buf(next_marked_buf)
  registry_instance:resume_update()
end

-- Navigate to the prev marked buffer in registry
actions.switch_to_prev_marked_buffer = function()
  registry_instance:clean()
  local prev_marked_buf = registry_instance:get_marked_buffer("prev")
  if prev_marked_buf == nil then
    return
  end
  registry_instance:pause_update()
  vim.api.nvim_set_current_buf(prev_marked_buf)
  registry_instance:resume_update()
end

return actions
