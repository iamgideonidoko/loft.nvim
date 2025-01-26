local events = {}

---@param buffer integer
---@param mark_state boolean
events.buffer_mark = function(buffer, mark_state)
  vim.api.nvim_exec_autocmds(
    "User",
    { pattern = "LoftBufferMark", modeline = false, data = { mark_state = mark_state, buffer = buffer } }
  )
end

return events
