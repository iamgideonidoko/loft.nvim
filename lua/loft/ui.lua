local utils = require("loft.utils")
local constants = require("loft.constants")
local actions = require("loft.actions")

---@class (exact) loft.UIOtherOpts
---@field show_marked_mapping_num boolean
---@field marked_mapping_num_style 'solid'|'outline'

---@class (exact) loft.UIOpts
---@field keymaps loft.UIKeymapsConfig
---@field general_keymaps loft.GeneralKeymapsConfig
---@field window loft.WinOpts
---@field other_opts loft.UIOtherOpts

---@class loft.UI
---@field private _win_id integer|nil
---@field private _buf_id integer|nil
---@field private _last_win_before_loft integer|nil
---@field private _last_buf_before_loft integer|nil
---@field registry_instance loft.Registry
---@field private _keymaps loft.UIKeymapsConfig|nil
---@field private _general_keymaps loft.GeneralKeymapsConfig|nil
---@field private _help_win_id integer|nil
---@field private _help_buf_id integer|nil
---@field private _window loft.WinOpts|nil
---@field private _marked_nums_solid string[]
---@field private _marked_nums_outline string[]
---@field private _other_opts loft.UIOtherOpts
---@field private _smart_order_symbol string
local UI = {}
UI.__index = UI

---@param registry_instance loft.Registry
function UI:new(registry_instance)
  local instance = setmetatable({}, self)
  instance.registry_instance = registry_instance
  instance._keymaps = {}
  instance._general_keymaps = {}
  instance._marked_nums_solid = { "➊", "➋", "➌", "➍", "➎", "➏", "➐", "➑", "➒" }
  instance._marked_nums_outline = { "➀", "➁", "➂", "➃", "➄", "➅", "➆", "➇", "➈" }
  instance._smart_order_symbol = "⟅⇅⟆"
  return instance
end

---@param opts loft.UIOpts
function UI:setup(opts)
  self._keymaps = opts.keymaps
  self._general_keymaps = opts.general_keymaps
  self._window = opts.window
  self._other_opts = opts.other_opts
end

--- Render a list of all the buffers in the registry (entries) in main UI buffer
---@private
function UI:_render_entries()
  if utils.buffer_exists(self._buf_id) then
    utils.buffer_modifiable(self._buf_id, true)
    --- Lines to render
    ---@type string[]
    local buf_lines = {}
    for _, buf_id in ipairs(self.registry_instance:get_registry()) do
      local buffer = vim.fn.getbufinfo(buf_id)[1]
      if buffer then
        local bufname = buffer.name ~= "" and buffer.name or "[No Name]"
        local bufnr = buffer.bufnr
        local flags = ""
        flags = flags .. self:get_buffer_mark(bufnr)
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
  local height = self._window.height
    or math.min(
      #self.registry_instance:get_registry() > 0 and #self.registry_instance:get_registry() or 1,
      math.floor(vim.o.lines * 0.8)
    )
  self._buf_id = vim.api.nvim_create_buf(false, true)
  local width = self._window.width or math.floor(vim.o.columns * 0.8)
  local title = " ⨳⨳ " .. string.upper(constants.DISPLAY_NAME) .. " ⨳⨳ "
  ---@type vim.api.keyset.win_config
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) * 0.5),
    col = math.floor((vim.o.columns - width) * 0.5),
    style = "minimal",
    border = self._window.border,
    title = title,
    title_pos = self._window.title_pos,
    noautocmd = true,
    footer = self:_get_footer(),
    footer_pos = self._window.title_pos,
    zindex = self._window.zindex,
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
  if utils.window_exists(self._win_id) then
    vim.api.nvim_win_close(self._win_id, true)
    self._win_id = nil
  end
  if utils.buffer_exists(self._buf_id) then
    vim.api.nvim_buf_delete(self._buf_id, { force = true })
    self._buf_id = nil
  end
end

---@private
function UI:_setup_autocmd()
  -- Prevent override
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = utils.get_augroup("PreventOverride", true),
    callback = function()
      if vim.api.nvim_get_current_win() == self._win_id then
        local current_buf = vim.api.nvim_get_current_buf()
        if current_buf ~= self._buf_id then
          vim.api.nvim_set_current_buf(self._buf_id)
          if not utils.table_includes(self.registry_instance:get_registry(), current_buf) then
            vim.api.nvim_buf_delete(current_buf, { force = true })
          end
        end
      end
      if vim.api.nvim_get_current_win() == self._help_win_id then
        local current_buf = vim.api.nvim_get_current_buf()
        if current_buf ~= self._help_buf_id then
          vim.api.nvim_set_current_buf(self._help_buf_id)
          if not utils.table_includes(self.registry_instance:get_registry(), current_buf) then
            vim.api.nvim_buf_delete(current_buf, { force = true })
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
      self:toggle_smart_order()
    end,
    ["show_help"] = function()
      self:_show_help()
    end,
    ["move_up_to_marked_entry"] = function()
      self:_move_to_marked_entry("up")
    end,
    ["move_down_to_marked_entry"] = function()
      self:_move_to_marked_entry("down")
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

--- Move cursor up in cyclic manner
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

--- Move cursor down in cyclic manner
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

--- Move entry up in cyclic manner
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

--- Move entry down in cyclic manner
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

--- Delete an entry (with its buffer)
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
  return " "
    .. self._smart_order_symbol
    .. ": "
    .. (self.registry_instance:is_smart_order_on() and "ON" or "OFF")
    .. " "
end

---@return boolean: New state of smart order
function UI:toggle_smart_order()
  local new_state = self.registry_instance:toggle_smart_order()
  if utils.window_exists(self._win_id) then
    vim.api.nvim_win_set_config(self._win_id, {
      footer = self:_get_footer(),
      footer_pos = "center",
    })
  end
  return new_state
end

---@private
function UI:_show_help()
  -- Focus existing window
  if utils.window_exists(self._help_win_id) then
    return vim.api.nvim_set_current_win(self._help_win_id)
  end
  local content = {
    "Help (v" .. constants.PLUGIN_VERSION .. "):",
    "`loft.nvim` streamlines buffer management while you focus on your code",
    "",
    "Keymaps:",
  }
  ---@type table<loft.UIKeymapsActions, string>
  local ui_keymaps_desc = {
    ["move_up"] = "Move cursor up",
    ["move_down"] = "Move cursor down",
    ["move_entry_up"] = "Move entry up",
    ["move_entry_down"] = "Move entry down",
    ["delete_entry"] = "Delete entry (+buffer)",
    ["select_entry"] = "Select entry (+buffer)",
    ["close"] = "Close Loft",
    ["toggle_mark_entry"] = "Toggle entry mark status",
    ["toggle_smart_order"] = "Toggle smart order status",
    ["show_help"] = "Show this help",
    ["move_up_to_marked_entry"] = "Move up to the next marked entry",
    ["move_down_to_marked_entry"] = "Move down to the next marked entry",
  }
  for key, value in pairs(self._keymaps) do
    if value == false or type(value) ~= "string" then
      return
    end
    local desc = ui_keymaps_desc[value]
    table.insert(content, string.format("  %s: %s", key, desc))
  end
  for key, value in pairs(self._general_keymaps) do
    if value == false then
      return
    end
    local desc = type(value) == "table" and value.desc
      or type(value) == "table" and type(value.callback) == "table" and value.callback.desc
      or "No description"
    table.insert(content, string.format("  %s: %s", key, desc))
  end
  for _, value in pairs({
    "",
    "Commands:",
    " :LoftToggle - Toggle the Loft UI",
    " :LoftToggleSmartOrder - Toggle Smart Order ON and OFF",
    " :LoftToggleMark - Toggle mark current buffer",
    "",
  }) do
    table.insert(content, value)
  end
  self._help_buf_id = vim.api.nvim_create_buf(false, true)
  local width = 70
  local height = math.min(#content + 1, math.floor(vim.o.lines * 0.8))
  ---@type vim.api.keyset.win_config
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) * 0.5),
    col = math.floor((vim.o.columns - width) * 0.5),
    style = "minimal",
    border = self._window.border,
    noautocmd = true,
    zindex = self._window.zindex + 10,
  }
  self._help_win_id = vim.api.nvim_open_win(self._help_buf_id, true, opts)
  vim.api.nvim_buf_set_lines(self._help_buf_id, 0, -1, false, content)
  vim.api.nvim_set_option_value("wrap", false, {
    win = self._help_win_id,
  })
  vim.api.nvim_set_option_value("wrap", true, {
    scope = "local",
    win = self._help_win_id,
  })
  vim.api.nvim_set_option_value("modifiable", false, {
    buf = self._help_buf_id,
  })
  for _, key in ipairs({ "?", "q", "<CR>", "<Esc>" }) do
    vim.api.nvim_buf_set_keymap(self._help_buf_id, "n", key, "", {
      noremap = true,
      silent = true,
      callback = function()
        self:_close_help()
      end,
    })
  end
end

---@private
function UI:_close_help()
  if utils.buffer_exists(self._help_buf_id) then
    vim.api.nvim_buf_delete(self._help_buf_id, { force = true })
    self._help_buf_id = nil
  end
  if utils.window_exists(self._help_win_id) then
    vim.api.nvim_win_close(self._help_win_id, true)
    self._help_win_id = nil
  end
end

--- Toggle the main UI window
function UI:toggle()
  if utils.window_exists(self._win_id) then
    self:close()
  else
    self:open()
  end
end

--- Check if the main UI window is open
function UI:is_open()
  return utils.window_exists(self._win_id)
end

--- Move up to next marked entry in the main UI window
---@param direction  'up'|'down'
---@private
function UI:_move_to_marked_entry(direction)
  local current_line = vim.fn.line(".")
  local registry = self.registry_instance:get_registry()
  local current_buf = registry[current_line]
  if current_buf == nil then
    return
  end
  local goto_buf = self.registry_instance:get_marked_buffer(direction == "up" and "prev" or "next", current_buf)
  ---@type integer|nil
  local goto_line
  for i, buf in ipairs(registry) do
    if buf == goto_buf then
      goto_line = i
      break
    end
  end
  if goto_line then
    vim.api.nvim_win_set_cursor(self._win_id, { goto_line, 1 })
  end
end

--- Get the mark (string) of the given or current buffer
---@param buffer? integer
function UI:get_buffer_mark(buffer)
  local buf = buffer or vim.api.nvim_get_current_buf()
  local is_marked = self.registry_instance:is_buffer_marked(buf)
  if is_marked then
    local mark_symbol = "(✓)"
    if self._other_opts.show_marked_mapping_num then
      local marked_index = self.registry_instance:get_marked_buffer_keymap_index(buf)
      if marked_index ~= nil then
        local mark_nums = self._other_opts.marked_mapping_num_style == "outline" and self._marked_nums_outline
          or self._marked_nums_solid
        local marked_num = mark_nums[marked_index]
        if marked_num then
          return marked_num .. mark_symbol
        end
      end
    end
    return mark_symbol
  end
  return ""
end

--- Get the smart order indicator (string)
function UI:smart_order_indicator()
  local is_smart_order_on = self.registry_instance:is_smart_order_on()
  local status = is_smart_order_on and "ON" or "OFF"
  return self._smart_order_symbol .. ": " .. status
end

return UI:new(require("loft.registry"))
