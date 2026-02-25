local highlights = {}

--- Loft highlight groups with sensible defaults linked to standard Neovim groups.
--- All groups use `default = true` so colorschemes (and user config) can override
--- them freely without needing to explicitly clear loft's definitions.
---
--- Line-level groups (applied as background to the whole line):
---   LoftCurrentBuffer   – the buffer that was active when Loft opened
---   LoftMarkedBuffer    – a buffer that has been marked/pinned
---
--- Inline groups (applied to specific characters on the line):
---   LoftMark            – the mark indicator symbol  (✓ / ➊–➒)
---   LoftCurrentIndicator – the ● current-buffer dot
---   LoftModified        – the [+] unsaved-changes indicator
---   LoftBufferNumber    – the {N} buffer-number token
---
---@type table<string, vim.api.keyset.highlight>
highlights.groups = {
  LoftCurrentBuffer = { default = true, link = "PmenuSel" },
  LoftMarkedBuffer = { default = true, link = "DiffAdd" },
  LoftMark = { default = true, link = "DiagnosticInfo" },
  LoftCurrentIndicator = { default = true, link = "Statement" },
  LoftModified = { default = true, link = "DiagnosticWarn" },
  LoftBufferNumber = { default = true, link = "Comment" },
}

--- Set up all Loft highlight groups.
--- Safe to call multiple times (e.g. after a ColorScheme change).
function highlights.setup()
  for name, spec in pairs(highlights.groups) do
    vim.api.nvim_set_hl(0, name, spec)
  end
end

return highlights
