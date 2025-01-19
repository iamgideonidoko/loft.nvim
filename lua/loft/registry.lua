local utils = require("loft.utils")

---@class loft.Registry
---@field private _registry integer[]
---@field private _update_paused boolean
---@field private _update_paused_once boolean
local Registry = {}
Registry.__index = Registry

function Registry:new()
  local instance = setmetatable({}, self)
  instance._registry = {}
  instance._update_paused = false
  instance._update_paused_once = false
  return instance
end

---Update registry to move the given or current buffer to last
---@param buffer integer?
function Registry:update(buffer)
  local buf = buffer or vim.api.nvim_get_current_buf()
  if utils.is_floating_window() or self._update_paused then
    return
  end
  if self._update_paused_once then
    self._update_paused_once = false
    return
  end
  for i, b in ipairs(self._registry) do
    if b == buf then
      table.remove(self._registry, i)
      break
    end
  end
  if 1 ~= vim.fn.buflisted(buf) then
    return
  end
  table.insert(self._registry, buf)
end

function Registry:pause_update()
  self._update_paused = true
end

function Registry:resume_update()
  self._update_paused = false
end

function Registry:pause_update_one()
  self._update_paused_once = true
end

return Registry:new()
