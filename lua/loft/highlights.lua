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
--- Uses `default = true` on Neovim 0.9+ so colorschemes can override any group.
--- On 0.8 the flag is omitted (not supported) and groups are set unconditionally.
function highlights.setup()
  local has_default = vim.fn.has("nvim-0.9") == 1
  for name, spec in pairs(highlights.groups) do
    local s = spec
    if not has_default then
      -- Strip the `default` key so nvim_set_hl doesn't error on older Neovim
      s = {}
      for k, v in pairs(spec) do
        if k ~= "default" then
          s[k] = v
        end
      end
    end
    vim.api.nvim_set_hl(0, name, s)
  end
end

return highlights
