local actions = require("loft.actions")
local utils = require("loft.utils")
local autocmds = {}

---@param buffer integer?
autocmds.delete_missing_file_buffer = function(buffer)
  local buf = buffer or vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(buf)
  local normalized_path = vim.fn.fnamemodify(file_path, ":p")
  local stat = vim.loop.fs_stat(file_path)
  local cwd = vim.fn.getcwd()
  vim.defer_fn(function()
    if
      file_path == ""
      or stat
      or normalized_path:sub(1, #cwd) ~= cwd
      or vim.fn.filereadable(file_path) == 1
      or not utils.is_buffer_valid(buf)
    then
      return
    end
    actions.close_buffer({ buf = buf, force = true })
  end, 0)
end

autocmds.setup = function()
  vim.api.nvim_create_autocmd("BufEnter", {
    group = utils.get_augroup("DeleteMissingFileBuffer", true),
    callback = function()
      autocmds.delete_missing_file_buffer()
    end,
  })
end

return autocmds
