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

return events
