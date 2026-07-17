---@diagnostic disable: invisible
local utils = require("loft.utils")

local persistence = {}

---@class (exact) loft.PersistenceConfig
---@field enabled boolean Whether persistence is enabled
---@field path? string Custom file path for state; defaults to stdpath("data")/loft/<cwd_hash>.json

--- Return the file path used to persist state for the current working directory
---@param opts loft.PersistenceConfig
---@return string
local function get_file_path(opts)
  if opts.path then
    return opts.path
  end
  local data_dir = vim.fn.stdpath("data") .. "/loft"
  vim.fn.mkdir(data_dir, "p")
  return data_dir .. "/" .. vim.fn.sha256(vim.fn.getcwd()) .. ".json"
end

--- Save registry state (order, marks, smart_order) to disk
---@param registry loft.Registry
---@param opts loft.PersistenceConfig
function persistence.save(registry, opts)
  if not opts.enabled then
    return
  end
  local order = {}
  local marks = {}
  for _, buf in ipairs(registry:get_registry()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" then
      table.insert(order, name)
      if registry.is_buffer_marked(buf) then
        table.insert(marks, name)
      end
    end
  end
  local ok, encoded = pcall(vim.json.encode, {
    order = order,
    marks = marks,
    smart_order = registry:is_smart_order_on(),
  })
  if not ok then
    return
  end
  local file_path = get_file_path(opts)
  local f = io.open(file_path, "w")
  if f then
    f:write(encoded)
    f:close()
  end
end

--- Restore registry state from disk, mapping saved file paths back to current buffer numbers.
--- Buffers not present in the saved state are appended at the end.
--- Silently ignores paths that are not currently open.
---@param registry loft.Registry
---@param opts loft.PersistenceConfig
function persistence.restore(registry, opts)
  if not opts.enabled then
    return
  end
  local file_path = get_file_path(opts)
  local f = io.open(file_path, "r")
  if not f then
    return
  end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then
    return
  end
  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= "table" then
    return
  end

  -- Build a path → bufnr map for all currently valid buffers
  local path_to_buf = {}
  for _, buf in ipairs(utils.get_all_valid_buffers()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" then
      path_to_buf[name] = buf
    end
  end

  -- Restore registry order
  if type(data.order) == "table" then
    local ordered = {}
    local seen = {}
    for _, saved_path in ipairs(data.order) do
      local buf = path_to_buf[saved_path]
      if buf and not seen[buf] then
        table.insert(ordered, buf)
        seen[buf] = true
      end
    end
    -- Append any currently valid buffers absent from the saved state
    for _, buf in ipairs(registry:get_registry()) do
      if not seen[buf] then
        table.insert(ordered, buf)
        seen[buf] = true
      end
    end
    registry._registry = ordered
    registry:on_change()
  end

  -- Restore marks (only mark buffers that are not already marked)
  if type(data.marks) == "table" then
    local mark_set = {}
    for _, saved_path in ipairs(data.marks) do
      mark_set[saved_path] = true
    end
    for _, buf in ipairs(registry:get_registry()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local name = vim.api.nvim_buf_get_name(buf)
        if name ~= "" and mark_set[name] and not registry.is_buffer_marked(buf) then
          registry:_mark_buffer(buf, true)
        end
      end
    end
  end

  -- Restore smart order state
  if type(data.smart_order) == "boolean" and data.smart_order ~= registry:is_smart_order_on() then
    registry:toggle_smart_order()
  end
end

--- Setup autocmds that save state on exit and restore it after a session is loaded.
---
--- Hooks into the native Neovim SessionLoadPost event and the post-load User
--- autocmds fired by the most common session plugins:
---   - folke/persistence.nvim  → User PersistenceLoadPost  (+ native SessionLoadPost)
---   - olimorris/persisted.nvim → User PersistedLoadPost    (+ native SessionLoadPost)
---   - stevearc/resession.nvim  → User ResessionLoadPost    (no native SessionLoadPost)
---   - rmagatti/auto-session    → native SessionLoadPost only (no custom User event)
---   - Shatur/neovim-session-manager → native SessionLoadPost + User SessionLoadPost
---
--- Falls back to a deferred VimEnter handler and a direct vim.schedule call for
--- users without a session plugin, or when loft is loaded lazily inside VimEnter
--- (in which case a VimEnter autocmd can no longer fire for the current event).
---
--- Design:
---   • session load events always trigger restore (no once-only guard), so loading
---     a different session mid-session re-applies loft state correctly.
---   • session_plugin_fired prevents the VimEnter / vim.schedule fallbacks from
---     running redundantly after a real session-load event has fired.
---   • vim.v.this_session is checked at setup() time so that loft can restore
---     immediately when it was loaded lazily after the session was already sourced
---     (common when using lazy.nvim with event = "VimEnter" or similar).
---
--- possession.nvim note: it uses vim.api.nvim_exec2 instead of :source, so it
--- does not fire SessionLoadPost or any User event after loading. Users should
--- call require("loft.persistence").restore() in their possession.nvim after_load
--- hook: hooks = { after_load = function() require("loft.persistence").restore(...) end }
---@param registry loft.Registry
---@param opts loft.PersistenceConfig
function persistence.setup(registry, opts)
  if not opts.enabled then
    return
  end

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = utils.get_augroup("PersistenceSave", true),
    callback = function()
      persistence.save(registry, opts)
    end,
  })

  -- Tracks whether at least one session load event has fired. Used by the
  -- VimEnter / vim.schedule fallbacks to avoid restoring before session buffers
  -- are available.
  local session_plugin_fired = false

  local function on_session_load()
    session_plugin_fired = true
    persistence.restore(registry, opts)
  end

  -- Native Neovim :mksession / :source session.vim
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = utils.get_augroup("PersistenceSessionLoad", true),
    callback = on_session_load,
  })

  -- Session plugin post-load User events
  vim.api.nvim_create_autocmd("User", {
    pattern = {
      "PersistenceLoadPost", -- folke/persistence.nvim
      "PersistedLoadPost", -- olimorris/persisted.nvim
      "ResessionLoadPost", -- stevearc/resession.nvim
    },
    group = utils.get_augroup("PersistencePluginLoad", true),
    callback = on_session_load,
  })

  -- If a session was already loaded before setup() was called (e.g., loft was
  -- loaded lazily by a plugin manager whose VimEnter ran after the session
  -- plugin's VimEnter already sourced the session file), SessionLoadPost fired
  -- before our handler was registered. Detect this via vim.v.this_session and
  -- restore immediately.
  if vim.v.this_session ~= nil and vim.v.this_session ~= "" then
    vim.schedule(function()
      persistence.restore(registry, opts)
    end)
    return
  end

  -- VimEnter fallback: handles loft loaded before VimEnter with no session
  -- plugin, or with a session plugin that fires SessionLoadPost synchronously
  -- (e.g. folke/persistence.nvim) — the SessionLoadPost handler beats this
  -- fallback and sets session_plugin_fired = true first.
  vim.api.nvim_create_autocmd("VimEnter", {
    group = utils.get_augroup("PersistenceVimEnter", true),
    once = true,
    callback = function()
      vim.schedule(function()
        if not session_plugin_fired then
          persistence.restore(registry, opts)
        end
      end)
    end,
  })

  -- Direct vim.schedule fallback: safety net for the case where loft is loaded
  -- lazily INSIDE VimEnter processing (so the VimEnter autocmd above will never
  -- fire for the current event) but no session was loaded yet. The check against
  -- session_plugin_fired makes this a no-op when a real session event fires.
  -- When loft is loaded before VimEnter this runs early and is harmless: if the
  -- saved state has no matching buffers open yet, restore() is effectively a
  -- no-op; the VimEnter fallback or SessionLoadPost handler corrects state later.
  vim.schedule(function()
    if not session_plugin_fired then
      persistence.restore(registry, opts)
    end
  end)
end

return persistence
