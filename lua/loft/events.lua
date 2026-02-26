local events = {}

---@param buffer integer
---@param mark_state boolean
events.buffer_mark = function(buffer, mark_state)
  vim.api.nvim_exec_autocmds(
    "User",
    { pattern = "LoftBufferMark", modeline = false, data = { mark_state = mark_state, buffer = buffer } }
  )
end

---@param smart_order_state boolean
events.smart_order_toggle = function(smart_order_state)
  vim.api.nvim_exec_autocmds(
    "User",
    { pattern = "LoftSmartOrderToggle", modeline = false, data = { smart_order_state = smart_order_state } }
  )
end

--- Fired whenever the registry mutates (entries added, removed, or reordered).
events.registry_changed = function()
  vim.api.nvim_exec_autocmds("User", { pattern = "LoftRegistryChanged", modeline = false })
end

--- Fired whenever Loft navigates to a buffer (next/prev/marked/alt).
---@param buffer integer The buffer that was switched to.
---@param source string A short label describing what triggered the switch
---   (e.g. "next", "prev", "marked_next", "marked_prev", "alt").
events.buffer_switch = function(buffer, source)
  vim.api.nvim_exec_autocmds(
    "User",
    { pattern = "LoftBufferSwitch", modeline = false, data = { buffer = buffer, source = source } }
  )
end

return events
