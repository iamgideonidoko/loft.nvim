local utils = require("loft.utils")
local constants = require("loft.constants")
local actions = require("loft.actions")

--- Extmark namespace used for all Loft highlight decorations.
local hl_ns = vim.api.nvim_create_namespace("loft_ui")

---@class (exact) loft.UIOtherOpts
---@field show_marked_mapping_num boolean
---@field marked_mapping_num_style 'solid'|'outline'
---@field timeout_on_curr_buf_move integer
---@field reverse_order boolean
---@field confirm_force_delete boolean

---@class (exact) loft.UIOpts
---@field keymaps loft.UIKeymapsConfig
---@field visual_keymaps? loft.UIVisualKeymapsConfig
---@field general_keymaps loft.GeneralKeymapsConfig
---@field window loft.WinOpts
---@field help_window loft.HelpWinOpts
---@field other_opts loft.UIOtherOpts

---@class loft.UI
---@field private _win_id integer|nil
---@field private _buf_id integer|nil
---@field private _last_win_before_loft integer|nil
---@field private _last_buf_before_loft integer|nil
---@field registry_instance loft.Registry
---@field private _keymaps loft.UIKeymapsConfig|nil
---@field private _visual_keymaps loft.UIVisualKeymapsConfig|nil
---@field private _general_keymaps loft.GeneralKeymapsConfig|nil
---@field private _help_win_id integer|nil
---@field private _help_buf_id integer|nil
---@field private _window loft.WinOpts|nil
---@field private _help_window loft.HelpWinOpts|nil
---@field private _marked_nums_solid string[]
---@field private _marked_nums_outline string[]
---@field private _other_opts loft.UIOtherOpts
---@field private _smart_order_symbol string
---@field private _debounce_close fun()
local UI = {}
UI.__index = UI

---@param registry_instance loft.Registry
function UI:new(registry_instance)
  local instance = setmetatable({}, self)
  instance.registry_instance = registry_instance
  instance._keymaps = {}
  instance._visual_keymaps = {}
  instance._general_keymaps = {}
  instance._marked_nums_solid = { "➊", "➋", "➌", "➍", "➎", "➏", "➐", "➑", "➒" }
  instance._marked_nums_outline = { "➀", "➁", "➂", "➃", "➄", "➅", "➆", "➇", "➈" }
  instance._smart_order_symbol = "⟅⇅⟆"
  return instance
end

---@param opts loft.UIOpts
function UI:setup(opts)
  self._keymaps = opts.keymaps
  self._visual_keymaps = opts.visual_keymaps
  self._general_keymaps = opts.general_keymaps
  self._window = opts.window
  self._help_window = opts.help_window
  self._other_opts = opts.other_opts
  self._debounce_close = utils.debounce(function()
    self:close()
  end, opts.other_opts.timeout_on_curr_buf_move or 800)
end

--- Render a list of all the buffers in the registry (entries) in main UI buffer
---@private
function UI:_render_entries()
  if not utils.buffer_exists(self._buf_id) then
    return
  end
  utils.buffer_modifiable(self._buf_id, true)
  --- Lines to render
  ---@type string[]
  local buf_lines = {}
  --- Highlight specs: { lnum, col_start, col_end, hl_group }
  --- col_end < 0 means line-level highlight (line_hl_group).
  ---@type table[]
  local hl_specs = {}
  local registry = self.registry_instance:get_registry()
  local n = #registry
  for display_pos = 1, n do
    local reg_idx = self:_line_to_reg_idx(display_pos, n)
    local lnum = display_pos - 1 -- 0-indexed extmark row
    local buf_id = registry[reg_idx]
    local buffer = vim.fn.getbufinfo(buf_id)[1]
    if buffer then
      local bufname = buffer.name ~= "" and buffer.name or "[No Name]"
      local bufnr = buffer.bufnr
      local col = 0
      local flags = ""

      -- 1. Mark indicator symbol  (✓ / ➊–➒)
      local mark = self:get_buffer_mark(bufnr)
      if mark ~= "" then
        table.insert(hl_specs, { lnum, col, col + #mark, "LoftMark" })
        col = col + #mark
        flags = flags .. mark
      end

      -- 2. Modified indicator [+]
      local is_modified = vim.api.nvim_get_option_value("modified", { buf = bufnr })
      if is_modified then
        local mod = "[+]"
        table.insert(hl_specs, { lnum, col, col + #mod, "LoftModified" })
        col = col + #mod
        flags = flags .. mod
      end

      -- 3. Current-buffer indicator ●
      local is_current_buf = self._last_buf_before_loft == bufnr
      if is_current_buf then
        local ind = "●"
        table.insert(hl_specs, { lnum, col, col + #ind, "LoftCurrentIndicator" })
        col = col + #ind
        flags = flags .. ind
      end

      -- 4. ">" separator  (1 ASCII byte, no dedicated highlight)
      col = col + 1

      -- 5. Buffer number {N}
      local bufnr_str = string.format("{%d}", bufnr)
      table.insert(hl_specs, { lnum, col, col + #bufnr_str, "LoftBufferNumber" })

      -- 6. Line-level background (current > marked > none)
      if is_current_buf then
        table.insert(hl_specs, { lnum, 0, -1, "LoftCurrentBuffer" })
      elseif mark ~= "" then
        table.insert(hl_specs, { lnum, 0, -1, "LoftMarkedBuffer" })
      end

      local relative_path = vim.fn.fnamemodify(bufname, ":.")
      table.insert(buf_lines, string.format("%s>{%d}%s", flags, bufnr, relative_path))
    end
  end
  vim.api.nvim_buf_set_lines(self._buf_id, 0, -1, false, buf_lines)
  utils.buffer_modifiable(self._buf_id, false)
  self:_apply_highlights(hl_specs)
end

--- Apply extmark-based highlights to the UI buffer.
--- col_end < 0 in a spec means a full-line (line_hl_group) extmark.
---@param hl_specs table[]
---@private
function UI:_apply_highlights(hl_specs)
  if not utils.buffer_exists(self._buf_id) then
    return
  end
  vim.api.nvim_buf_clear_namespace(self._buf_id, hl_ns, 0, -1)
  for _, spec in ipairs(hl_specs) do
    local lnum, col_start, col_end, group = spec[1], spec[2], spec[3], spec[4]
    if col_end < 0 then
      -- Line-level background highlight (lower priority so inline fg shows on top)
      vim.api.nvim_buf_set_extmark(self._buf_id, hl_ns, lnum, 0, {
        line_hl_group = group,
        priority = 100,
      })
    else
      -- Inline character highlight (higher priority to overlay the line bg)
      vim.api.nvim_buf_set_extmark(self._buf_id, hl_ns, lnum, col_start, {
        end_col = col_end,
        hl_group = group,
        priority = 200,
      })
    end
  end
end

--- Convert a 1-indexed display line to a 1-indexed registry position.
--- In reverse mode line 1 maps to the last registry item.
---@param line integer 1-indexed display line
---@param n integer total number of registry entries
---@return integer
---@private
function UI:_line_to_reg_idx(line, n)
  if self._other_opts.reverse_order then
    return n - line + 1
  end
  return line
end

--- Convert a 1-indexed registry position to a 1-indexed display line.
---@param idx integer 1-indexed registry index
---@param n integer total number of registry entries
---@return integer
---@private
function UI:_reg_idx_to_line(idx, n)
  if self._other_opts.reverse_order then
    return n - idx + 1
  end
  return idx
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
  local width = self._window.width or math.floor(vim.o.columns * 0.8)
  local row = (self._window.row or math.floor((vim.o.lines - height) * 0.5)) + (self._window.row_offset or 0)
  local col = (self._window.col or math.floor((vim.o.columns - width) * 0.5)) + (self._window.col_offset or 0)
  self._buf_id = vim.api.nvim_create_buf(false, true)
  ---@type vim.api.keyset.win_config
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = self._window.border,
    noautocmd = true,
    zindex = self._window.zindex,
  }
  -- Title / footer (version-gated)
  local major, minor = utils.get_nvim_version()
  if major > 0 or minor >= 9 then
    win_opts.title = self._window.title or self._get_title()
    win_opts.title_pos = self._window.title_pos
  end
  if major > 0 or minor >= 10 then
    win_opts.footer = self._window.footer or self:_get_footer()
    win_opts.footer_pos = self._window.footer_pos or self._window.title_pos
  elseif major > 0 or minor >= 9 then
    -- Fold footer into title for 0.9
    if not self._window.title then
      win_opts.title = self._get_title(self:_get_footer())
    end
  end
  self._win_id = vim.api.nvim_open_win(self._buf_id, true, win_opts)
  vim.api.nvim_set_option_value("cursorline", true, { win = self._win_id })
  vim.api.nvim_set_option_value("modifiable", false, { buf = self._buf_id })
  vim.api.nvim_set_option_value("wrap", false, { win = self._win_id })
  -- Disable spell-checking and column highlights in the Loft buffer
  vim.api.nvim_set_option_value("spell", false, { win = self._win_id })
  vim.api.nvim_set_option_value("cursorcolumn", false, { win = self._win_id })
  -- Fortify: no swap file, wipe on hide, disable undo
  vim.api.nvim_set_option_value("swapfile", false, { buf = self._buf_id })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = self._buf_id })
  vim.api.nvim_set_option_value("undolevels", -1, { buf = self._buf_id })
  -- Correct filetype so syntax engines don't accidentally activate
  vim.api.nvim_set_option_value("filetype", "loft", { buf = self._buf_id })
  self:_render_entries()
  -- Move cursor to current entry
  local registry = self.registry_instance:get_registry()
  local last_buf_index = utils.get_index(registry, self._last_buf_before_loft)
  if last_buf_index then
    local display_line = self:_reg_idx_to_line(last_buf_index, #registry)
    vim.api.nvim_win_set_cursor(self._win_id, { display_line, 1 })
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
      if utils.window_exists(self._win_id) and vim.api.nvim_get_current_win() == self._win_id then
        local current_buf = vim.api.nvim_get_current_buf()
        if current_buf ~= self._buf_id then
          -- _buf_id was replaced in the loft window (e.g. it was wiped due to bufhidden=wipe).
          -- Close the loft window gracefully instead of trying to restore the wiped buffer.
          vim.schedule(function()
            self:close()
          end)
        end
      end
      if utils.window_exists(self._help_win_id) and vim.api.nvim_get_current_win() == self._help_win_id then
        local current_buf = vim.api.nvim_get_current_buf()
        if current_buf ~= self._help_buf_id then
          vim.schedule(function()
            self:_close_help()
          end)
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
      self:_delete_entry(false)
    end,
    ["force_delete_entry"] = function()
      self:_delete_entry(true)
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
  -- Normal mode keymaps
  for key, value in pairs(self._keymaps) do
    if value ~= false then
      local action = type(value) == "function" and value or mappings[value]
      if action then
        vim.api.nvim_buf_set_keymap(self._buf_id, "n", key, "", {
          noremap = true,
          silent = true,
          callback = action,
        })
      end
    end
  end
  -- Visual mode keymaps
  if self._visual_keymaps then
    ---@type table<loft.UIVisualKeymapsActions, function>
    local visual_mappings = {
      ["delete_selected_entries"] = function()
        -- Read the live visual range BEFORE exiting visual mode.
        -- line(".") is the cursor end, line("v") is the anchor start.
        -- '< / '> are only updated after leaving visual mode, so we don't use them.
        local s = math.min(vim.fn.line("."), vim.fn.line("v"))
        local e = math.max(vim.fn.line("."), vim.fn.line("v"))
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
        vim.schedule(function()
          self:_delete_selected_entries(false, s, e)
        end)
      end,
      ["force_delete_selected_entries"] = function()
        local s = math.min(vim.fn.line("."), vim.fn.line("v"))
        local e = math.max(vim.fn.line("."), vim.fn.line("v"))
        -- Exit visual mode first so the confirm dialog isn't dismissed by the Esc key
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
        vim.schedule(function()
          self:_delete_selected_entries(true, s, e)
        end)
      end,
    }
    for key, value in pairs(self._visual_keymaps) do
      if value ~= false then
        local action = type(value) == "function" and value or visual_mappings[value]
        if action then
          vim.api.nvim_buf_set_keymap(self._buf_id, "x", key, "", {
            noremap = true,
            silent = true,
            callback = action,
          })
        end
      end
    end
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
  local new_line = ((current_line - vim.v.count1 - 1) % no_of_entries) + 1
  vim.api.nvim_win_set_cursor(self._win_id, { new_line, 1 })
end

--- Move cursor down in cyclic manner
---@private
function UI:_move_down()
  local current_line = vim.fn.line(".")
  local no_of_entries = #self.registry_instance:get_registry()
  if no_of_entries == 0 then
    return
  end
  local new_line = ((current_line + vim.v.count1 - 1) % no_of_entries) + 1
  vim.api.nvim_win_set_cursor(self._win_id, { new_line, 1 })
end

--- Move entry up in cyclic manner
---@private
function UI:_move_entry_up()
  local current_line = vim.fn.line(".")
  local no_of_entries = #self.registry_instance:get_registry()
  if no_of_entries == 0 then
    return
  end
  local reg_idx = self:_line_to_reg_idx(current_line, no_of_entries)
  -- Visually moving up in reversed mode means advancing toward higher registry indices
  if self._other_opts.reverse_order then
    self.registry_instance:move_buffer_down(reg_idx, true)
  else
    self.registry_instance:move_buffer_up(reg_idx, true)
  end
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
  local reg_idx = self:_line_to_reg_idx(current_line, no_of_entries)
  -- Visually moving down in reversed mode means retreating toward lower registry indices
  if self._other_opts.reverse_order then
    self.registry_instance:move_buffer_up(reg_idx, true)
  else
    self.registry_instance:move_buffer_down(reg_idx, true)
  end
  local new_line = 1
  if current_line < no_of_entries then
    new_line = current_line + 1
  end
  vim.api.nvim_win_set_cursor(self._win_id, { new_line, 1 })
  self:_render_entries()
end

--- Resize the floating window to match the current registry size.
---@private
function UI:_resize_win()
  if not utils.window_exists(self._win_id) then
    return
  end
  local win_config = vim.api.nvim_win_get_config(self._win_id)
  local no_of_entries = #self.registry_instance:get_registry()
  win_config.height = math.min(no_of_entries > 0 and no_of_entries or 1, vim.o.lines - 2)
  vim.api.nvim_win_set_config(self._win_id, win_config)
end

--- Show a confirmation dialog for force-delete operations.
--- Returns true if the operation should proceed.
---@param count integer number of buffers to be deleted
---@return boolean
---@private
function UI:_confirm_force_delete(count)
  if not self._other_opts.confirm_force_delete then
    return true
  end
  local msg = count == 1 and "Force delete 1 buffer? Unsaved changes will be lost."
    or string.format("Force delete %d buffers? Unsaved changes will be lost.", count)
  local answer = vim.fn.confirm(msg, "&Yes\n&No", 2)
  return answer == 1
end

--- Delete an entry (with its buffer).
---@param force? boolean When true, close without saving. Defaults to false.
---@private
function UI:_delete_entry(force)
  force = force or false
  local current_line = vim.fn.line(".")
  local n = #self.registry_instance:get_registry()
  if n == 0 then
    return
  end
  local reg_idx = self:_line_to_reg_idx(current_line, n)
  local buf = self.registry_instance:get_registry()[reg_idx]
  if buf == nil then
    return
  end
  if force and not self:_confirm_force_delete(1) then
    return
  end
  actions.close_buffer({ force = force, buffer = buf })
  self:_render_entries()
  self:_resize_win()
  -- Clamp cursor to valid range after deletion
  local new_n = #self.registry_instance:get_registry()
  if new_n > 0 and utils.window_exists(self._win_id) then
    local cursor_line = vim.fn.line(".")
    if cursor_line > new_n then
      vim.api.nvim_win_set_cursor(self._win_id, { new_n, 1 })
    end
  end
end

--- Delete a range of entries selected in visual mode.
---@param force boolean When true, close without saving.
---@param start_line integer 1-indexed display start line of the selection.
---@param end_line integer 1-indexed display end line of the selection.
---@private
function UI:_delete_selected_entries(force, start_line, end_line)
  local registry = self.registry_instance:get_registry()
  local n = #registry
  if n == 0 then
    return
  end
  -- Snapshot buffers to delete before mutating the registry
  local bufs_to_delete = {}
  local lo = math.min(start_line, end_line)
  local hi = math.max(start_line, end_line)
  for line = lo, hi do
    local reg_idx = self:_line_to_reg_idx(line, n)
    local buf = registry[reg_idx]
    if buf then
      table.insert(bufs_to_delete, buf)
    end
  end
  if #bufs_to_delete == 0 then
    return
  end
  if force and not self:_confirm_force_delete(#bufs_to_delete) then
    return
  end
  for _, buf in ipairs(bufs_to_delete) do
    actions.close_buffer({ force = force, buffer = buf })
  end
  self:_render_entries()
  self:_resize_win()
  -- Clamp cursor to valid range after deletion
  local new_n = #self.registry_instance:get_registry()
  if new_n > 0 and utils.window_exists(self._win_id) then
    local cursor_line = vim.fn.line(".")
    if cursor_line > new_n then
      vim.api.nvim_win_set_cursor(self._win_id, { new_n, 1 })
    end
  end
end

---@private
function UI:_select_entry()
  self.registry_instance:pause_update()
  local current_line = vim.fn.line(".")
  local n = #self.registry_instance:get_registry()
  local reg_idx = self:_line_to_reg_idx(current_line, n)
  self:close()
  local selected_buffer = self.registry_instance:get_registry()[reg_idx]
  if selected_buffer ~= nil and utils.window_exists(self._last_win_before_loft) then
    pcall(vim.api.nvim_win_set_buf, self._last_win_before_loft, selected_buffer)
  end
  self.registry_instance:resume_update()
end

---@private
function UI:_toggle_mark_entry()
  local current_line = vim.fn.line(".")
  local n = #self.registry_instance:get_registry()
  local reg_idx = self:_line_to_reg_idx(current_line, n)
  local buf = self.registry_instance:get_registry()[reg_idx]
  if buf == nil then
    return
  end
  self.registry_instance:toggle_mark_buffer(buf)
  self:_render_entries()
end

---@private
function UI:_get_footer()
  local smart_order_indicator = self:smart_order_indicator()
  if smart_order_indicator == "" then
    return ""
  end
  return " " .. self:smart_order_indicator() .. " "
end

---@param extras string|nil
---@private
function UI._get_title(extras)
  extras = extras and " (" .. extras .. ")" or ""
  return " ⨳⨳ " .. string.upper(constants.DISPLAY_NAME) .. extras .. " ⨳⨳ "
end

---@return boolean: New state of smart order
function UI:toggle_smart_order()
  local new_state = self.registry_instance:toggle_smart_order()
  if utils.window_exists(self._win_id) then
    ---@type vim.api.keyset.win_config
    local win_opts = {}
    local major, minor = utils.get_nvim_version()
    -- Only update the dynamic smart-order indicator when no custom title/footer was set
    if major > 0 or minor >= 10 then
      if not self._window.footer then
        win_opts.footer = self:_get_footer()
        win_opts.footer_pos = self._window.footer_pos or self._window.title_pos
      end
    elseif major > 0 or minor >= 9 then
      if not self._window.title then
        win_opts.title = self._get_title(self:_get_footer())
      end
    end
    if next(win_opts) then
      vim.api.nvim_win_set_config(self._win_id, win_opts)
    end
  end
  return new_state
end

---@private
function UI:_show_help()
  -- Respect the disable flag
  if self._help_window and self._help_window.disable then
    return
  end
  -- Focus existing window
  if utils.window_exists(self._help_win_id) then
    return vim.api.nvim_set_current_win(self._help_win_id)
  end
  local content = {
    " ⨳⨳ LOFT HELP ⨳⨳ ",
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
    ["force_delete_entry"] = "Force delete entry (+buffer, no save)",
  }
  for key, value in pairs(self._keymaps) do
    if value ~= false and type(value) == "string" then
      local desc = ui_keymaps_desc[value]
      table.insert(content, string.format("  %s: %s", key, desc))
    end
  end
  -- Visual mode keymaps
  if self._visual_keymaps then
    local visual_desc = {
      ["delete_selected_entries"] = "Delete selected entries (+buffers)",
      ["force_delete_selected_entries"] = "Force delete selected entries (no save)",
    }
    for key, value in pairs(self._visual_keymaps) do
      if value ~= false and type(value) == "string" then
        local desc = visual_desc[value]
        table.insert(content, string.format("  %s (visual): %s", key, desc))
      end
    end
  end
  for key, value in pairs(self._general_keymaps) do
    if value ~= false then
      local desc = type(value) == "table" and value.desc
        or type(value) == "table" and type(value.callback) == "table" and value.callback.desc
        or "No description"
      table.insert(content, string.format("  %s: %s", key, desc))
    end
  end
  for _, value in pairs({
    "",
    "Commands:",
    " :LoftToggle - Toggle the Loft UI",
    " :LoftToggleSmartOrder - Toggle Smart Order ON and OFF",
    " :LoftToggleMark - Toggle mark current buffer",
    " :LoftCloseOthers - Close all buffers except the current one.",
    " :LoftCloseOthers! - Force-close all other buffers (ignores modified state).",
    " :LoftCloseUnmarked - Close all unmarked buffers. Mark what you want to keep, then run this to clear the rest.",
    " :LoftCloseUnmarked! - Force-close all unmarked buffers.",
  }) do
    table.insert(content, value)
  end
  self._help_buf_id = vim.api.nvim_create_buf(false, true)
  local hw = self._help_window or {}
  local width = hw.width or 70
  local height = hw.height or math.min(#content, math.floor(vim.o.lines * 0.8))
  local row = (hw.row or math.floor((vim.o.lines - height) * 0.5)) + (hw.row_offset or 0)
  local col = (hw.col or math.floor((vim.o.columns - width) * 0.5)) + (hw.col_offset or 0)
  -- zindex must always be > main window zindex so help floats on top
  local main_zindex = self._window.zindex or 100
  local help_zindex = hw.zindex or (main_zindex + 10)
  if help_zindex <= main_zindex then
    help_zindex = main_zindex + 1
  end
  ---@type vim.api.keyset.win_config
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = hw.border or self._window.border,
    noautocmd = true,
    zindex = help_zindex,
  }
  self._help_win_id = vim.api.nvim_open_win(self._help_buf_id, true, opts)
  vim.api.nvim_buf_set_lines(self._help_buf_id, 0, -1, false, content)
  vim.api.nvim_set_option_value("wrap", false, { win = self._help_win_id })
  vim.api.nvim_set_option_value("modifiable", false, { buf = self._help_buf_id })
  vim.api.nvim_set_option_value("spell", false, { win = self._help_win_id })
  vim.api.nvim_set_option_value("cursorcolumn", false, { win = self._help_win_id })
  -- Fortify: no swap file, wipe on hide, disable undo
  vim.api.nvim_set_option_value("swapfile", false, { buf = self._help_buf_id })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = self._help_buf_id })
  vim.api.nvim_set_option_value("undolevels", -1, { buf = self._help_buf_id })
  vim.api.nvim_set_option_value("filetype", "loft-help", { buf = self._help_buf_id })
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
  local n = #registry
  local reg_idx = self:_line_to_reg_idx(current_line, n)
  local current_buf = registry[reg_idx]
  if current_buf == nil then
    return
  end
  -- In reversed mode visual "up" = higher registry index ("next"), "down" = lower ("prev")
  local registry_dir
  if self._other_opts.reverse_order then
    registry_dir = direction == "up" and "next" or "prev"
  else
    registry_dir = direction == "up" and "prev" or "next"
  end
  local goto_buf = self.registry_instance:get_marked_buffer(registry_dir, current_buf)
  ---@type integer|nil
  local goto_line
  for i, buf in ipairs(registry) do
    if buf == goto_buf then
      goto_line = self:_reg_idx_to_line(i, n)
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
  local is_marked = self.registry_instance.is_buffer_marked(buf)
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
  return is_smart_order_on and self._smart_order_symbol or ""
end

--- Move the current buffer up the registry in cyclic manner while showing the UI briefly
function UI:move_buffer_up()
  self.registry_instance:clean()
  local registry = self.registry_instance:get_registry()
  local no_of_buffers = #registry
  if no_of_buffers == 0 then
    return
  end
  local buf = utils.is_floating_window() and vim.api.nvim_win_get_buf(vim.fn.win_getid(vim.fn.winnr("#")))
    or vim.api.nvim_get_current_buf()

  local buf_idx = utils.get_index(registry, buf)
  if buf_idx == nil then
    return
  end
  if self._other_opts.timeout_on_curr_buf_move > 0 then
    if not utils.window_exists(self._win_id) then
      self:open()
    end
    self._debounce_close()
  end
  self.registry_instance:move_buffer_up(buf_idx, true)
  if utils.window_exists(self._win_id) then
    local new_reg_idx = buf_idx > 1 and buf_idx - 1 or no_of_buffers
    local new_line = self:_reg_idx_to_line(new_reg_idx, no_of_buffers)
    vim.api.nvim_win_set_cursor(self._win_id, { new_line, 1 })
    self:_render_entries()
  end
end

--- Move the current buffer down the registry in a cyclic manner while showing the UI briefly
function UI:move_buffer_down()
  self.registry_instance:clean()
  local registry = self.registry_instance:get_registry()
  local no_of_buffers = #registry
  if no_of_buffers == 0 then
    return
  end
  local buf = utils.is_floating_window() and vim.api.nvim_win_get_buf(vim.fn.win_getid(vim.fn.winnr("#")))
    or vim.api.nvim_get_current_buf()
  local buf_idx = utils.get_index(registry, buf)
  if buf_idx == nil then
    return
  end
  if self._other_opts.timeout_on_curr_buf_move > 0 then
    if not utils.window_exists(self._win_id) then
      self:open()
    end
    self._debounce_close()
  end
  self.registry_instance:move_buffer_down(buf_idx, true)
  if utils.window_exists(self._win_id) then
    local new_reg_idx = buf_idx < no_of_buffers and buf_idx + 1 or 1
    local new_line = self:_reg_idx_to_line(new_reg_idx, no_of_buffers)
    vim.api.nvim_win_set_cursor(self._win_id, { new_line, 1 })
    self:_render_entries()
  end
end

return UI:new(require("loft.registry"))
