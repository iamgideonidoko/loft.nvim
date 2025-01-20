local utils = require("loft.utils")

---@class loft.UI
---@field private _win_id integer
---@field private _buf_id integer
---@field private registry_instance loft.Registry
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

return UI:new(require("loft.registry"))
