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
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and mark_set[name] and not registry.is_buffer_marked(buf) then
        registry:_mark_buffer(buf, true)
      end
    end
  end

  -- Restore smart order state
  if type(data.smart_order) == "boolean" and data.smart_order ~= registry:is_smart_order_on() then
    registry:toggle_smart_order()
  end
end

--- Setup autocmds that save state on exit and restore it after a session is loaded.
--- Hooks into the native Neovim SessionLoadPost event as well as the post-load events
--- fired by the most common session plugins (auto-session, persisted.nvim,
--- resession.nvim, possession.nvim). Falls back to a deferred VimEnter handler for
--- users who do not use a session plugin.
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

  local restored = false
  local function try_restore()
    if restored then
      return
    end
    restored = true
    persistence.restore(registry, opts)
  end

  -- Native Neovim :mksession / :source session.vim
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = utils.get_augroup("PersistenceSessionLoad", true),
    callback = try_restore,
  })

  -- Session plugin post-load events
  vim.api.nvim_create_autocmd("User", {
    pattern = {
      "AutoSessionLoadPost", -- auto-session
      "PersistedLoadPost", -- persisted.nvim
      "ResessionLoadPost", -- resession.nvim
      "PossessionLoadPost", -- possession.nvim
    },
    group = utils.get_augroup("PersistencePluginLoad", true),
    callback = try_restore,
  })

  -- Fallback for users without a session plugin
  vim.api.nvim_create_autocmd("VimEnter", {
    group = utils.get_augroup("PersistenceVimEnter", true),
    once = true,
    callback = function()
      vim.schedule(try_restore)
    end,
  })
end

return persistence
