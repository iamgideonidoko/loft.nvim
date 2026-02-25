local helper = require("loft.test_helper")

local child = helper.new_child_neovim()
local eq = helper.expect.equality

local test_set = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.setup()
      child.lua([[require("loft").setup()]])
    end,
    post_once = child.stop,
  },
  n_retry = helper.get_n_retry(1),
})

-- ── helpers ────────────────────────────────────────────────────────────

local function open_file(rel_path)
  child.lua(string.format([[vim.cmd("e %s")]], rel_path))
  return child.lua_get([[vim.api.nvim_get_current_buf()]])
end

local function make_tmp()
  return child.lua_get([[vim.fn.tempname() .. ".json"]])
end

local function do_save(tmp)
  child.lua(
    string.format([[require("loft.persistence").save(require("loft.registry"), { enabled = true, path = %q })]], tmp)
  )
end

local function do_restore(tmp)
  child.lua(
    string.format([[require("loft.persistence").restore(require("loft.registry"), { enabled = true, path = %q })]], tmp)
  )
end

local function read_json(tmp)
  -- stylua: ignore
  return child.lua_get(string.format( -- luacheck: ignore 631
    [[(function() local f = io.open(%q, "r"); if not f then return nil end; local c = f:read("*a"); f:close(); return vim.json.decode(c) end)()]],
    tmp
  ))
end

local function cleanup(tmp)
  child.lua(string.format([[vim.fn.delete(%q)]], tmp))
end

-- ── save: file creation ────────────────────────────────────────────────

test_set["save creates a JSON file on disk"] = function()
  open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  local tmp = make_tmp()
  do_save(tmp)
  eq(child.lua_get(string.format([[vim.fn.filereadable(%q)]], tmp)), 1)
  cleanup(tmp)
end

test_set["save does nothing when disabled"] = function()
  open_file("scripts/minimal_init.vim")
  local tmp = make_tmp()
  child.lua(
    string.format([[require("loft.persistence").save(require("loft.registry"), { enabled = false, path = %q })]], tmp)
  )
  eq(child.lua_get(string.format([[vim.fn.filereadable(%q)]], tmp)), 0)
end

-- ── save: order ────────────────────────────────────────────────────────

test_set["save encodes opened file paths in order field"] = function()
  open_file("scripts/minimal_init.vim")
  open_file("scripts/test_setup.lua")
  child.lua([[require("loft.registry"):clean()]])
  local tmp = make_tmp()
  do_save(tmp)
  local data = read_json(tmp)
  local found_minimal, found_setup = false, false
  for _, p in ipairs(data.order) do
    if p:match("minimal_init%.vim") then
      found_minimal = true
    end
    if p:match("test_setup%.lua") then
      found_setup = true
    end
  end
  eq(found_minimal, true)
  eq(found_setup, true)
  cleanup(tmp)
end

test_set["save preserves registry order in order field"] = function()
  open_file("scripts/minimal_init.vim")
  open_file("scripts/test_setup.lua")
  child.lua([[require("loft.registry"):clean()]])
  -- Swap so the first entry moves after the second
  child.lua([[require("loft.registry"):move_buffer_down(1, false)]])
  local tmp = make_tmp()
  do_save(tmp)
  local data = read_json(tmp)
  -- Find positions of both files in saved order
  local pos1, pos2 = nil, nil
  for i, p in ipairs(data.order) do
    if p:match("minimal_init%.vim") then
      pos1 = i
    end
    if p:match("test_setup%.lua") then
      pos2 = i
    end
  end
  -- buf1 moved down → should appear after buf2
  eq(pos1 > pos2, true)
  cleanup(tmp)
end

test_set["save skips unnamed scratch buffers"] = function()
  child.api.nvim_create_buf(true, true)
  child.lua([[require("loft.registry"):clean()]])
  local tmp = make_tmp()
  do_save(tmp)
  local data = read_json(tmp)
  for _, p in ipairs(data.order) do
    eq(p ~= "", true)
  end
  cleanup(tmp)
end

-- ── save: marks ────────────────────────────────────────────────────────

test_set["save encodes marked buffer paths in marks field"] = function()
  local buf = open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  local tmp = make_tmp()
  do_save(tmp)
  local data = read_json(tmp)
  local found = false
  for _, p in ipairs(data.marks) do
    if p:match("minimal_init%.vim") then
      found = true
    end
  end
  eq(found, true)
  cleanup(tmp)
end

test_set["save encodes empty marks when no buffer is marked"] = function()
  open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  local tmp = make_tmp()
  do_save(tmp)
  local data = read_json(tmp)
  eq(#data.marks, 0)
  cleanup(tmp)
end

-- ── save: smart_order ──────────────────────────────────────────────────

test_set["save encodes smart_order as true by default"] = function()
  open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  local tmp = make_tmp()
  do_save(tmp)
  local data = read_json(tmp)
  eq(data.smart_order, true)
  cleanup(tmp)
end

test_set["save encodes smart_order as false when toggled off"] = function()
  open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_smart_order()]])
  local tmp = make_tmp()
  do_save(tmp)
  local data = read_json(tmp)
  eq(data.smart_order, false)
  cleanup(tmp)
end

-- ── restore: order ─────────────────────────────────────────────────────

test_set["restore reorders registry to match saved order"] = function()
  local buf1 = open_file("scripts/minimal_init.vim")
  local buf2 = open_file("scripts/test_setup.lua")
  child.lua([[require("loft.registry"):clean()]])
  -- After opening buf2 last, order ends with buf1 then buf2
  local saved_reg = child.lua_get([[require("loft.registry"):get_registry()]])
  local tmp = make_tmp()
  do_save(tmp)
  -- Scramble by moving the last entry to the front
  child.lua([[require("loft.registry"):move_buffer_up(1, false)]])
  -- Restore and verify order matches what was saved
  do_restore(tmp)
  local restored_reg = child.lua_get([[require("loft.registry"):get_registry()]])
  local saved_idx1, saved_idx2 = nil, nil
  local rest_idx1, rest_idx2 = nil, nil
  for i, b in ipairs(saved_reg) do
    if b == buf1 then
      saved_idx1 = i
    end
    if b == buf2 then
      saved_idx2 = i
    end
  end
  for i, b in ipairs(restored_reg) do
    if b == buf1 then
      rest_idx1 = i
    end
    if b == buf2 then
      rest_idx2 = i
    end
  end
  eq(rest_idx1 ~= nil, true)
  eq(rest_idx2 ~= nil, true)
  eq((saved_idx2 > saved_idx1) == (rest_idx2 > rest_idx1), true)
  cleanup(tmp)
end

test_set["restore appends buffers absent from saved order to the end"] = function()
  local buf1 = open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  local tmp = make_tmp()
  do_save(tmp)
  -- Open a new file after saving
  local buf2 = open_file("scripts/test_setup.lua")
  do_restore(tmp)
  local reg = child.lua_get([[require("loft.registry"):get_registry()]])
  local idx1, idx2 = nil, nil
  for i, b in ipairs(reg) do
    if b == buf1 then
      idx1 = i
    end
    if b == buf2 then
      idx2 = i
    end
  end
  eq(idx1 ~= nil, true)
  eq(idx2 ~= nil, true)
  -- buf2 was not in saved state → must come after buf1
  eq(idx2 > idx1, true)
  cleanup(tmp)
end

test_set["restore silently skips file paths not currently open"] = function()
  open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  local tmp = make_tmp()
  -- Write a state file with a non-existent path mixed in
  child.lua(string.format(
    [[(function()
      local f = io.open(%q, "w")
      f:write(vim.json.encode({
        order = { "/non/existent/ghost.lua", vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()) },
        marks = {},
        smart_order = true,
      }))
      f:close()
    end)()]],
    tmp
  ))
  local ok = child.lua_get(string.format(
    [[(function()
      local ok = pcall(require("loft.persistence").restore, require("loft.registry"), { enabled = true, path = %q })
      return ok
    end)()]],
    tmp
  ))
  eq(ok, true)
  cleanup(tmp)
end

-- ── restore: marks ─────────────────────────────────────────────────────

test_set["restore marks the correct buffers"] = function()
  local buf = open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  local tmp = make_tmp()
  do_save(tmp)
  -- Unmark and verify
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), false)
  -- Restore
  do_restore(tmp)
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
  cleanup(tmp)
end

test_set["restore does not double-mark an already marked buffer"] = function()
  local buf = open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  local tmp = make_tmp()
  do_save(tmp)
  -- buf is still marked; restore must not toggle it off
  do_restore(tmp)
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
  cleanup(tmp)
end

-- ── restore: smart_order ───────────────────────────────────────────────

test_set["restore sets smart_order off when saved as false"] = function()
  open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_smart_order()]])
  local tmp = make_tmp()
  do_save(tmp)
  -- Turn smart order back on before restoring
  child.lua([[require("loft.registry"):toggle_smart_order()]])
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), true)
  do_restore(tmp)
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), false)
  cleanup(tmp)
end

test_set["restore sets smart_order on when saved as true"] = function()
  open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  -- Save with smart order on (default)
  local tmp = make_tmp()
  do_save(tmp)
  -- Turn smart order off before restoring
  child.lua([[require("loft.registry"):toggle_smart_order()]])
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), false)
  do_restore(tmp)
  eq(child.lua_get([[require("loft.registry"):is_smart_order_on()]]), true)
  cleanup(tmp)
end

-- ── restore: edge cases ────────────────────────────────────────────────

test_set["restore does nothing when disabled"] = function()
  local buf = open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  local tmp = make_tmp()
  do_save(tmp)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), false)
  child.lua(
    string.format(
      [[require("loft.persistence").restore(require("loft.registry"), { enabled = false, path = %q })]],
      tmp
    )
  )
  -- Mark should still be false (restore was skipped)
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), false)
  cleanup(tmp)
end

test_set["restore is silent when the file does not exist"] = function()
  local tmp = make_tmp()
  local ok = child.lua_get(string.format(
    [[(function()
      local ok = pcall(require("loft.persistence").restore, require("loft.registry"), { enabled = true, path = %q })
      return ok
    end)()]],
    tmp
  ))
  eq(ok, true)
end

test_set["restore is silent on corrupted JSON"] = function()
  local tmp = make_tmp()
  child.lua(
    string.format([[(function() local f = io.open(%q, "w"); f:write("not valid json {{{{"); f:close() end)()]], tmp)
  )
  local ok = child.lua_get(string.format(
    [[(function()
      local ok = pcall(require("loft.persistence").restore, require("loft.registry"), { enabled = true, path = %q })
      return ok
    end)()]],
    tmp
  ))
  eq(ok, true)
  cleanup(tmp)
end

-- ── setup: autocmds ───────────────────────────────────────────────────

test_set["setup registers VimLeavePre autocmd when enabled"] = function()
  child.lua([[
    require("loft.persistence").setup(require("loft.registry"), {
      enabled = true,
      path = vim.fn.tempname() .. ".json",
    })
  ]])
  eq(child.lua_get([[#vim.api.nvim_get_autocmds({ group = "LoftPersistenceSave", event = "VimLeavePre" })]]), 1)
end

test_set["setup registers SessionLoadPost autocmd when enabled"] = function()
  child.lua([[
    require("loft.persistence").setup(require("loft.registry"), {
      enabled = true,
      path = vim.fn.tempname() .. ".json",
    })
  ]])
  eq(
    child.lua_get([[#vim.api.nvim_get_autocmds({ group = "LoftPersistenceSessionLoad", event = "SessionLoadPost" })]]),
    1
  )
end

test_set["setup registers VimEnter autocmd when enabled and no session loaded"] = function()
  child.lua([[
    require("loft.persistence").setup(require("loft.registry"), {
      enabled = true,
      path = vim.fn.tempname() .. ".json",
    })
  ]])
  eq(child.lua_get([[#vim.api.nvim_get_autocmds({ group = "LoftPersistenceVimEnter", event = "VimEnter" })]]), 1)
end

test_set["setup skips VimEnter autocmd when session already loaded (vim.v.this_session set)"] = function()
  local tmp = make_tmp()
  -- Simulate a session already being loaded by setting vim.v.this_session
  child.lua(string.format([[vim.v.this_session = "/some/session.vim"]], tmp))
  child.lua(
    string.format([[require("loft.persistence").setup(require("loft.registry"), { enabled = true, path = %q })]], tmp)
  )
  -- luacheck: ignore 631
  local augroup_check =
    [[(function() local ok, cmds = pcall(vim.api.nvim_get_autocmds, { group = "LoftPersistenceVimEnter" }); return ok and #cmds or 0 end)()]]
  local count = child.lua_get(augroup_check)
  eq(count, 0)
  child.lua([[vim.v.this_session = ""]])
end

test_set["setup registers User event autocmds for session plugins when enabled"] = function()
  child.lua([[
    require("loft.persistence").setup(require("loft.registry"), {
      enabled = true,
      path = vim.fn.tempname() .. ".json",
    })
  ]])
  -- luacheck: ignore 631
  local count = child.lua_get(
    [[(function() local cmds = vim.api.nvim_get_autocmds({ group = "LoftPersistencePluginLoad", event = "User" }); return #cmds end)()]]
  )
  eq(count > 0, true)
end

test_set["PersistenceLoadPost event triggers restore (folke/persistence.nvim)"] = function()
  local buf = open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  local tmp = make_tmp()
  do_save(tmp)
  -- Unmark, then fire the PersistenceLoadPost User event to simulate persistence.nvim
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), false)
  child.lua(
    string.format([[require("loft.persistence").setup(require("loft.registry"), { enabled = true, path = %q })]], tmp)
  )
  child.lua([[vim.api.nvim_exec_autocmds("User", { pattern = "PersistenceLoadPost" })]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
  cleanup(tmp)
end

test_set["PersistedLoadPost event triggers restore (olimorris/persisted.nvim)"] = function()
  local buf = open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  local tmp = make_tmp()
  do_save(tmp)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), false)
  child.lua(
    string.format([[require("loft.persistence").setup(require("loft.registry"), { enabled = true, path = %q })]], tmp)
  )
  child.lua([[vim.api.nvim_exec_autocmds("User", { pattern = "PersistedLoadPost" })]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
  cleanup(tmp)
end

test_set["ResessionLoadPost event triggers restore (stevearc/resession.nvim)"] = function()
  local buf = open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  local tmp = make_tmp()
  do_save(tmp)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), false)
  child.lua(
    string.format([[require("loft.persistence").setup(require("loft.registry"), { enabled = true, path = %q })]], tmp)
  )
  child.lua([[vim.api.nvim_exec_autocmds("User", { pattern = "ResessionLoadPost" })]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
  cleanup(tmp)
end

test_set["setup restores immediately when session was loaded before setup ran"] = function()
  local buf = open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  local tmp = make_tmp()
  do_save(tmp)
  -- Unmark to simulate state after a fresh load
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), false)
  -- Simulate loft being loaded lazily after the session was already sourced
  child.lua([[vim.v.this_session = "/some/session.vim"]])
  child.lua(
    string.format([[require("loft.persistence").setup(require("loft.registry"), { enabled = true, path = %q })]], tmp)
  )
  -- vim.schedule restore should have been queued; wait for it
  child.lua([[vim.wait(200, function() return require("loft.registry").is_buffer_marked(]] .. buf .. [[) end)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
  child.lua([[vim.v.this_session = ""]])
  cleanup(tmp)
end

test_set["direct vim.schedule fallback restores when no session plugin fires"] = function()
  local buf = open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  local tmp = make_tmp()
  do_save(tmp)
  -- Unmark
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), false)
  -- Call setup; no session plugin fires, VimEnter won't re-fire in test, but
  -- the direct vim.schedule inside setup() should run the fallback
  child.lua(
    string.format([[require("loft.persistence").setup(require("loft.registry"), { enabled = true, path = %q })]], tmp)
  )
  child.lua([[vim.wait(200, function() return require("loft.registry").is_buffer_marked(]] .. buf .. [[) end)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
  cleanup(tmp)
end

test_set["session load event can re-restore after a new session is loaded"] = function()
  local buf = open_file("scripts/minimal_init.vim")
  child.lua([[require("loft.registry"):clean()]])
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  local tmp = make_tmp()
  do_save(tmp)
  child.lua(
    string.format([[require("loft.persistence").setup(require("loft.registry"), { enabled = true, path = %q })]], tmp)
  )
  -- First restore via SessionLoadPost
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  child.lua([[vim.api.nvim_exec_autocmds("SessionLoadPost", {})]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
  -- Unmark and fire event again (simulating a second session load)
  child.lua([[require("loft.registry"):toggle_mark_buffer(]] .. buf .. [[)]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), false)
  child.lua([[vim.api.nvim_exec_autocmds("SessionLoadPost", {})]])
  eq(child.lua_get([[require("loft.registry").is_buffer_marked(]] .. buf .. [[)]]), true)
  cleanup(tmp)
end

test_set["setup does not register autocmds when disabled"] = function()
  child.lua([[
    require("loft.persistence").setup(require("loft.registry"), {
      enabled = false,
      path = vim.fn.tempname() .. ".json",
    })
  ]])
  local augroup_check = -- luacheck: ignore 631
    [[(function() local ok, cmds = pcall(vim.api.nvim_get_autocmds, { group = "LoftPersistenceSave" }); return ok and #cmds or 0 end)()]]
  local count = child.lua_get(augroup_check)
  eq(count, 0)
end

-- ── config integration ─────────────────────────────────────────────────

test_set["default persistence.enabled is false"] = function()
  eq(child.lua_get([[require("loft.config").all.persistence.enabled]]), false)
end

test_set["default persistence.path is nil"] = function()
  eq(child.lua_get([[require("loft.config").all.persistence.path == nil]]), true)
end

test_set["setup accepts persistence config and stores it"] = function()
  local tmp = make_tmp()
  child.lua(string.format([[require("loft").setup({ persistence = { enabled = true, path = %q } })]], tmp))
  eq(child.lua_get([[require("loft.config").all.persistence.enabled]]), true)
  eq(child.lua_get(string.format([[require("loft.config").all.persistence.path == %q]], tmp)), true)
end

test_set["persistence uses per-cwd default path when no path given"] = function()
  local path_expr = -- luacheck: ignore 631
    [[(function() local d = vim.fn.stdpath("data") .. "/loft"; return d .. "/" .. vim.fn.sha256(vim.fn.getcwd()) .. ".json" end)()]]
  local default_path = child.lua_get(path_expr)
  eq(type(default_path), "string")
  eq(default_path:match("%.json$") ~= nil, true)
end

return test_set
