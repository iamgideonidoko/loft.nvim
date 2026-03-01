---@diagnostic disable: assign-type-mismatch
local registry_instance = require("loft.registry")
local utils = require("loft.utils")
local events = require("loft.events")

---@class (exact) loft.Action
---@field desc string
---@field func function

---@type table<string, loft.Action>
local actions = {}

--- Delete a buffer without closing splits
---@type fun(opts: { force?: boolean, buffer?: integer })
actions.close_buffer = {
  desc = "Close buffer",
  ---@param opts { force?: boolean, buffer?: integer }
  func = function(opts)
    opts = opts or {}
    local current_buf = opts.buffer or vim.api.nvim_get_current_buf()
    if not opts.force and vim.api.nvim_get_option_value("modified", { buf = current_buf }) then
      return vim.api.nvim_err_writeln("Buffer is modified. Force required.")
    end
    if not opts.force and vim.api.nvim_get_option_value("buftype", { buf = current_buf }) == "terminal" then
      return vim.api.nvim_err_writeln("Buffer is a terminal. Force required.")
    end
    registry_instance:clean()
    -- bufnr("#") returns -1 when there is no alternate buffer; is_buffer_valid
    -- handles negative numbers gracefully so no extra guard is needed here.
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
    -- Ensure next_buf is not the buffer we are deleting
    if next_buf == current_buf then
      next_buf = nil
    end
    registry_instance:pause_update()
    for _, win in ipairs(vim.fn.win_findbuf(current_buf)) do
      -- alt_buf must differ from current_buf (e.g. from inside a Loft float, # == current_buf)
      if
        utils.is_buffer_valid(alt_buf, not registry_instance.opts.auto_delete_missing_file_bufs)
        and alt_buf ~= current_buf
      then
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
  end,
}

--- Navigate to the next buffer in registry
---@type fun()
actions.switch_to_next_buffer = {
  desc = "Switch to next buffer",
  func = function()
    registry_instance:clean()
    local next_buf = registry_instance:get_next_buffer()
    if next_buf == nil then
      local current_buf = vim.api.nvim_get_current_buf()
      if
        not utils.is_buffer_valid(current_buf, not registry_instance.opts.auto_delete_missing_file_bufs)
        and registry_instance.opts.close_invalid_buf_on_switch
      then
        actions.close_buffer({ force = true })
      end
      return
    end
    registry_instance:pause_update()
    pcall(vim.api.nvim_set_current_buf, next_buf)
    registry_instance:resume_update()
    events.buffer_switch(next_buf, "next")
  end,
}

--- Navigate to the previous buffer in registry
---@type fun()
actions.switch_to_prev_buffer = {
  desc = "Switch to previous buffer",
  func = function()
    registry_instance:clean()
    local prev_buf = registry_instance:get_prev_buffer()
    if prev_buf == nil then
      local current_buf = vim.api.nvim_get_current_buf()
      if
        not utils.is_buffer_valid(current_buf, not registry_instance.opts.auto_delete_missing_file_bufs)
        and registry_instance.opts.close_invalid_buf_on_switch
      then
        actions.close_buffer({ force = true })
      end
      return
    end
    registry_instance:pause_update()
    pcall(vim.api.nvim_set_current_buf, prev_buf)
    registry_instance:resume_update()
    events.buffer_switch(prev_buf, "prev")
  end,
}

---@type fun()
actions.open_loft = {
  desc = "Open Loft",
  func = function()
    require("loft.ui"):open()
  end,
}

--- Navigate to the next marked buffer in registry
---@type fun()
actions.switch_to_next_marked_buffer = {
  desc = "Switch to next marked buffer",
  func = function()
    registry_instance:clean()
    local next_marked_buf = registry_instance:get_marked_buffer("next")
    if next_marked_buf == nil then
      return
    end
    registry_instance:pause_update()
    pcall(vim.api.nvim_set_current_buf, next_marked_buf)
    registry_instance:resume_update()
    events.buffer_switch(next_marked_buf, "marked_next")
  end,
}

--- Navigate to the prev marked buffer in registry
---@type fun()
actions.switch_to_prev_marked_buffer = {
  desc = "Switch to previous marked buffer",
  func = function()
    registry_instance:clean()
    local prev_marked_buf = registry_instance:get_marked_buffer("prev")
    if prev_marked_buf == nil then
      return
    end
    registry_instance:pause_update()
    pcall(vim.api.nvim_set_current_buf, prev_marked_buf)
    registry_instance:resume_update()
    events.buffer_switch(prev_marked_buf, "marked_prev")
  end,
}

--- Toggle mark the current buffer
---@type fun(opts?: { notify?: boolean })
actions.toggle_mark_current_buffer = {
  desc = "Toggle mark current buffer",
  ---@param opts? { notify?: boolean }
  func = function(opts)
    opts = opts or {}
    if opts.notify == nil then
      opts.notify = true -- Default to true
    end
    local current_buf = vim.api.nvim_get_current_buf()
    if utils.is_buffer_valid(current_buf, not registry_instance.opts.auto_delete_missing_file_bufs) then
      local new_mark_state = registry_instance:toggle_mark_buffer(current_buf)
      if opts.notify then
        if new_mark_state then
          vim.notify("Marked", vim.log.levels.INFO)
        else
          vim.notify("Unmarked", vim.log.levels.INFO)
        end
      end
    end
  end,
}

--- Toggle the smart order status
---@type fun(opts: { notify?: boolean })
actions.toggle_smart_order = {
  desc = "Toggle Smart Order ON and OFF",
  ---@type fun(opts?: { notify?: boolean })
  func = function(opts)
    opts = opts or {}
    if opts.notify == nil then
      opts.notify = true
    end
    local ui_instance = require("loft.ui")
    local new_state = ui_instance:toggle_smart_order()
    if not ui_instance:is_open() and opts.notify then
      if new_state then
        vim.notify("Smart Order is ON", vim.log.levels.INFO)
      else
        vim.notify("Smart Order is OFF", vim.log.levels.INFO)
      end
    end
  end,
}

--- Switch to the alternate buffer without updating the registry
---@type fun()
actions.switch_to_alt_buffer = {
  desc = "Switch to alternate buffer (no registry update)",
  func = function()
    registry_instance:pause_update()
    ---@diagnostic disable-next-line: param-type-mismatch
    local ok, _ = pcall(vim.cmd, "e #")
    if not ok then
      registry_instance:resume_update()
      vim.notify("No alternate buffer", vim.log.levels.ERROR)
      return
    end
    local buf = vim.api.nvim_get_current_buf()
    registry_instance:resume_update()
    events.buffer_switch(buf, "alt")
  end,
}

--- Move the current buffer up the registry in a cyclic manner while showing the UI briefly
---@type fun()
actions.move_buffer_up = {
  desc = "Move buffer up",
  func = function()
    require("loft.ui"):move_buffer_up()
  end,
}

--- Move the current buffer down the registry in a cyclic manner while showing the UI briefly
---@type fun()
actions.move_buffer_down = {
  desc = "Move buffer down",
  func = function()
    require("loft.ui"):move_buffer_down()
  end,
}

--- Close all buffers in the registry except the current one.
---@type fun(opts?: { force?: boolean })
actions.close_others = {
  desc = "Close all other buffers",
  ---@param opts? { force?: boolean }
  func = function(opts)
    opts = opts or {}
    registry_instance:clean()
    local current_buf = vim.api.nvim_get_current_buf()
    -- Snapshot the registry so mutations during the loop don't affect iteration
    local to_close = {}
    for _, buf in ipairs(registry_instance:get_registry()) do
      if buf ~= current_buf then
        table.insert(to_close, buf)
      end
    end
    for _, buf in ipairs(to_close) do
      actions.close_buffer({ force = opts.force or false, buffer = buf })
    end
  end,
}

--- Close all unmarked buffers in the registry.
--- Pair with marking: mark what you want to keep, then call this to clear the rest.
---@type fun(opts?: { force?: boolean })
actions.close_unmarked = {
  desc = "Close all unmarked buffers",
  ---@param opts? { force?: boolean }
  func = function(opts)
    opts = opts or {}
    registry_instance:clean()
    -- Snapshot before mutation
    local to_close = {}
    for _, buf in ipairs(registry_instance:get_registry()) do
      if not registry_instance.is_buffer_marked(buf) then
        table.insert(to_close, buf)
      end
    end
    for _, buf in ipairs(to_close) do
      actions.close_buffer({ force = opts.force or false, buffer = buf })
    end
  end,
}

for _, action in pairs(actions) do
  setmetatable(action, {
    __call = function(_, ...)
      action.func(...)
    end,
  })
end

return actions
