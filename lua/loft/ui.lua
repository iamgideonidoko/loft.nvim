local utils = require("loft.utils")
local constants = require("loft.constants")
local actions = require("loft.actions")

---@class loft.UI
---@field private _win_id integer
---@field private _buf_id integer
---@field private _last_win_before_loft integer|nil
---@field private _last_buf_before_loft integer|nil
---@field registry_instance loft.Registry
---@field private _keymaps loft.UIKeymapsConfig|nil
local UI = {}
UI.__index = UI

---@param registry_instance loft.Registry
function UI:new(registry_instance)
  local instance = setmetatable({}, self)
  instance.registry_instance = registry_instance
  return instance
end

---@param opts  { keymaps: loft.UIKeymapsConfig }
function UI:setup(opts)
  self._keymaps = opts.keymaps
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
        local is_marked = self.registry_instance:is_buffer_marked(bufnr)
        if is_marked then
          flags = flags .. "(✓)"
        end
        local is_modified = vim.api.nvim_get_option_value("modified", { buf = bufnr })
        if is_modified then
          flags = flags .. "[+]"
        end
        local is_current_buf = self._last_buf_before_loft == bufnr
        if is_current_buf then
          flags = flags .. "●"
        end
        local relative_path = vim.fn.fnamemodify(bufname, ":.")
        table.insert(buf_lines, string.format("%s>{%d}%s", flags, bufnr, relative_path))
      end
    end
    vim.api.nvim_buf_set_lines(self._buf_id, 0, -1, false, buf_lines)
    utils.buffer_modifiable(self._buf_id, false)
  end
end

function UI:open()
  self._last_win_before_loft = vim.api.nvim_get_current_win()
  self._last_buf_before_loft = vim.api.nvim_get_current_buf()
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
  local title = " ⨳⨳ " .. string.upper(constants.DISPLAY_NAME) .. " ⨳⨳ "
  ---@type vim.api.keyset.win_config
  local win_opts = {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = (vim.o.lines - win_height) * 0.5,
    col = (vim.o.columns - win_width) * 0.5,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
    noautocmd = true,
    footer = self:_get_footer(),
    footer_pos = "center",
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
  local last_buf_index = utils.get_index(self.registry_instance:get_registry(), self._last_buf_before_loft)
  if last_buf_index then
    vim.api.nvim_win_set_cursor(self._win_id, { last_buf_index, 1 })
  end
  self:_setup_autocmd()
  self:_setup_keymaps()
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

---@private
function UI:_setup_autocmd()
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

---@private
function UI:_setup_keymaps()
  if not self._keymaps then
    return
  end
  ---@type table<loft.UIKeymapsActions, function>
  local mappings = {
    ["move_up"] = function()
      self:_move_up()
    end,
    ["move_down"] = function()
      self:_move_down()
    end,
    ["move_entry_up"] = function()
      self:_move_entry_up()
    end,
    ["move_entry_down"] = function()
      self:_move_entry_down()
    end,
    ["delete_entry"] = function()
      self:_delete_entry()
    end,
    ["select_entry"] = function()
      self:_select_entry()
    end,
    ["close"] = function()
      self:close()
    end,
    ["toggle_mark_entry"] = function()
      self:_toggle_mark_entry()
    end,
    ["toggle_smart_order"] = function()
      self:_toggle_smart_order()
    end,
  }
  for key, value in pairs(self._keymaps) do
    if value == false then
      return
    end
    local action = type(value) == "function" and value or mappings[value]
    vim.api.nvim_buf_set_keymap(self._buf_id, "n", key, "", {
      noremap = true,
      silent = true,
      callback = action,
    })
  end
end

---Move cursor up in cyclic manner
---@private
function UI:_move_up()
  local current_line = vim.fn.line(".")
  local no_of_entries = #self.registry_instance:get_registry()
  if no_of_entries == 0 then
    return
  end
  if current_line > 1 then
    vim.api.nvim_win_set_cursor(self._win_id, { current_line - 1, 1 })
  else
    vim.api.nvim_win_set_cursor(self._win_id, { no_of_entries, 1 })
  end
end

---Move cursor down in cyclic manner
---@private
function UI:_move_down()
  local current_line = vim.fn.line(".")
  local no_of_entries = #self.registry_instance:get_registry()
  if no_of_entries == 0 then
    return
  end
  if current_line < no_of_entries then
    vim.api.nvim_win_set_cursor(self._win_id, { current_line + 1, 1 })
  else
    vim.api.nvim_win_set_cursor(self._win_id, { 1, 1 })
  end
end

---Move entry up in cyclic manner
---@private
function UI:_move_entry_up()
  local current_line = vim.fn.line(".")
  local no_of_entries = #self.registry_instance:get_registry()
  if no_of_entries == 0 then
    return
  end
  self.registry_instance:move_buffer_up(current_line, true)
  local new_line = no_of_entries
  if current_line > 1 then
    new_line = current_line - 1
  end
  vim.api.nvim_win_set_cursor(self._win_id, { new_line, 1 })
  self:_render_entries()
end

---Move entry down in cyclic manner
---@private
function UI:_move_entry_down()
  local current_line = vim.fn.line(".")
  local no_of_entries = #self.registry_instance:get_registry()
  if no_of_entries == 0 then
    return
  end
  self.registry_instance:move_buffer_down(current_line, true)
  local new_line = 1
  if current_line < no_of_entries then
    new_line = current_line + 1
  end
  vim.api.nvim_win_set_cursor(self._win_id, { new_line, 1 })
  self:_render_entries()
end

---Delete an entry (with its buffer)
---@private
function UI:_delete_entry()
  local current_line = vim.fn.line(".")
  if #self.registry_instance:get_registry() == 0 then
    return
  end
  local buf = self.registry_instance:get_registry()[current_line]
  if buf == nil then
    return
  end
  actions.close_buffer({ force = false, buffer = buf })
  self:_render_entries()
  local win_config = vim.api.nvim_win_get_config(self._win_id)
  local no_of_entries = #self.registry_instance:get_registry()
  win_config.height = math.min(no_of_entries > 0 and no_of_entries or 1, vim.o.lines - 2)
  vim.api.nvim_win_set_config(self._win_id, win_config)
end

---@private
function UI:_select_entry()
  self.registry_instance:pause_update()
  local current_line = vim.fn.line(".")
  self:close()
  local selected_buffer = self.registry_instance:get_registry()[current_line]
  if selected_buffer ~= nil and utils.window_exists(self._last_win_before_loft) then
    pcall(vim.api.nvim_win_set_buf, self._last_win_before_loft, self.registry_instance:get_registry()[current_line])
  end
  self.registry_instance:resume_update()
end

---@private
function UI:_toggle_mark_entry()
  local current_line = vim.fn.line(".")
  local buf = self.registry_instance:get_registry()[current_line]
  if buf == nil then
    return
  end
  self.registry_instance:toggle_mark_buffer(buf)
  self:_render_entries()
end

---@private
function UI:_get_footer()
  return " Smart Order: " .. (self.registry_instance:is_smart_order_on() and "ON" or "OFF") .. " "
end

---@private
function UI:_toggle_smart_order()
  self.registry_instance:toggle_smart_order()
  vim.api.nvim_win_set_config(self._win_id, {
    footer = self:_get_footer(),
    footer_pos = "center",
  })
end

return UI:new(require("loft.registry"))
