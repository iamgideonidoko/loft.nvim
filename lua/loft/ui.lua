local utils = require("loft.utils")
local constants = require("loft.constants")

---@class loft.UI
---@field private _win_id integer
---@field private _buf_id integer
---@field registry_instance loft.Registry
local UI = {}
UI.__index = UI

---@param registry_instance loft.Registry
function UI:new(registry_instance)
  local instance = setmetatable({}, self)
  instance.registry_instance = registry_instance
  return instance
end

---Render a list of all the buffers in the registry (entries) in main UI buffer
---@private
function UI:_render_entries()
  if utils.buffer_exists(self._buf_id) then
    utils.buffer_modifiable(self._buf_id, true)
    ---Lines to render
    ---@type string[]
    local buf_lines = {}
    for _, buf_id in ipairs(self.registry_instance:get_registry()) do
      local buffer = vim.fn.getbufinfo(buf_id)[1]
      if buffer then
        local bufname = buffer.name ~= "" and buffer.name or "[No Name]"
        local bufnr = buffer.bufnr
        local flags = ""
        local is_modified = vim.api.nvim_get_option_value("modified", { buf = bufnr })
        if is_modified then
          flags = flags .. "[+]"
        end
        local relative_path = vim.fn.fnamemodify(bufname, ":.")
        table.insert(buf_lines, string.format("%s%d>%s", flags, bufnr, relative_path))
      end
    end
    vim.api.nvim_buf_set_lines(self._buf_id, 0, -1, false, buf_lines)
    utils.buffer_modifiable(self._buf_id, false)
  end
end

function UI:open()
  local last_win_before_loft = vim.api.nvim_get_current_win()
  local last_buf_before_loft = vim.api.nvim_get_current_buf()
  self.registry_instance:clean()
  -- Focus existing window
  if utils.window_exists(self._win_id) then
    return vim.api.nvim_set_current_win(self._win_id)
  end
  local max_height = vim.o.lines - 2
  local max_width = vim.o.columns - 4
  local win_height =
    math.min(#self.registry_instance:get_registry() > 0 and #self.registry_instance:get_registry() or 1, max_height)
  local win_width = math.max(math.ceil(max_width * 0.8), 50)
  self._buf_id = vim.api.nvim_create_buf(false, true)
  ---@type vim.api.keyset.win_config
  local win_opts = {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = (vim.o.lines - win_height) / 2,
    col = (vim.o.columns - win_width) / 2,
    style = "minimal",
    border = "rounded",
    title = constants.DISPLAY_NAME,
    title_pos = "center",
    noautocmd = true,
  }
  self._win_id = vim.api.nvim_open_win(self._buf_id, true, win_opts)
  vim.api.nvim_set_option_value("cursorline", true, {
    win = self._win_id,
  })
  vim.api.nvim_set_option_value("modifiable", false, {
    buf = self._buf_id,
  })
  vim.api.nvim_set_option_value("wrap", false, {
    win = self._win_id,
  })
  self:_render_entries()
  -- Move cursor to current entry
  local last_buf_index = utils.get_index(self.registry_instance:get_registry(), last_buf_before_loft)
  if last_buf_index then
    vim.api.nvim_win_set_cursor(self._win_id, { last_buf_index, 1 })
  end
  UI:setup_autocmd()
end

function UI:close()
  if utils.buffer_exists(self._buf_id) then
    vim.api.nvim_buf_delete(self._buf_id, { force = true })
    self._buf_id = nil
  end
  if utils.window_exists(self._win_id) then
    vim.api.nvim_win_close(self._win_id, true)
    self._win_id = nil
  end
end

function UI:setup_autocmd()
  -- Prevent override
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = utils.get_augroup("PreventOverride", true),
    callback = function()
      if vim.api.nvim_get_current_win() == self._win_id then
        local current_buf_id = vim.api.nvim_get_current_buf()
        if current_buf_id ~= self._buf_id then
          vim.api.nvim_set_current_buf(self._buf_id)
          if not utils.table_includes(self.registry_instance:get_registry(), current_buf_id) then
            vim.api.nvim_buf_delete(current_buf_id, { force = true })
          end
        end
      end
    end,
  })
end

return UI:new(require("loft.registry"))
