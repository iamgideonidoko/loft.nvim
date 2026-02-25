<div align="center">
  <img src="assets/loft.nvim.png" alt="Logo" />
  <h3 align="center"><code> ⨳⨳ LOFT ⨳⨳ </code></h3>
  <p align="center">Streamlined plugin for productive buffer management</p>
</div>
<br />

## Table of Content

- [Introduction](#introduction)
- [Installation](#installation)
- [Configuration](#configuration)
  - [Default Options](#default-options)
- [Commands](#commands)
- [Roadmap](#roadmap)

## Introduction

https://github.com/user-attachments/assets/312a06be-a2c0-4f4f-9fd2-e404c737cb89

Loft is a powerful yet lightweight Neovim plugin that makes buffer management fast, intuitive, and frustration-free—so you can focus on what truly matters. 🚀

### 🛑 The Problem: Buffer Chaos!

Imagine your Neovim buffer list is like a messy desk. You start with a clean workspace, but as the day goes on, files pile up—some important, others just distractions. Before you know it, you’re **digging through a jungle of buffers**, closing the wrong ones, and losing track of key files.

Ever rage-quit Neovim just to start fresh? You’re not alone.

### ✅ The Solution: Loft 🔥

<div align="center">
  <img src="assets/showcase.png" alt="Showcase" />
</div>

Loft uses a registry to manage state and track buffers that can be cyclically navigated to. It provides a floating UI that lists these buffers as rearrangeable entries in order of recency from bottom to top. The catch is in Loft's flagship features—**Smart Ordering** and **Marking**:

- #### ⟅⇅⟆ Smart Ordering

  The smart ordering feature (represented with the symbol `⟅⇅⟆`) dynamically arranges your buffers based on recency. This means that if you navigate to a buffer without any Loft's action (say via [Telescope](https://github.com/nvim-telescope/telescope.nvim)), that buffer will be move to the last position in the registry. Also, the current buffer before navigation will be moved to second to the last position.

- #### (✓) Marking

  The marking feature allows you to bookmark important buffers. The marked buffers/entries (identified by the symbol `(✓)`) can be specially navigated to cyclically or by keybinding. You read right, keybinding; the nine most recent buffers are automatically mapped for quick access anytime.

No more scrambling to find where you left off. No more accidental closures. **Just smooth, intelligent buffer management.** 🚀

## Installation

**Note**: Loft requires Neovim 0.8+

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "iamgideonidoko/loft.nvim",
  config = true, -- Calls setup automatically
}
```

## Configuration

You need to call the plugin's `setup()` method if you haven't yet:

```lua
require("loft").setup()
```

### Default Options

```lua
local actions = require("loft.actions")
require("loft").setup({
  close_invalid_buf_on_switch = true, -- Whether to close invalid buffers during navigation
  enable_smart_order_by_default = true, -- Whether to enable smart order by default
  smart_order_marked_bufs = false, -- Whether smart order (`⟅⇅⟆`) should reposition marked buffers
  smart_order_alt_bufs = false, -- Whether smart order (`⟅⇅⟆`) should reposition alternate buffers
  enable_recent_marked_mapping = true, -- Whether the 9 most recently marked buffers should be switched to with a mapping (with keymaps)

  -- The character to use after leader when assigning keymap to the 9 most recently marked buffers
  post_leader_marked_mapping = "l",  -- Maps to <leader>l1...9 for navigation
  show_marked_mapping_num = true, -- Whether to show the mapping number for the 9 most recently marked buffers
  marked_mapping_num_style = "solid", -- The style of the mapping number

  --[[ The timeout in milliseconds to wait before closing the UI after moving the current buffer.
  Defaults to 800. Set to 0 to disable the UI from showing at all. ]]
  ui_timeout_on_curr_buf_move = 800
  window = {
    width = nil, -- Defaults to calculated width
    height = nil, -- Defaults to calculated height
    zindex = 100,
    title_pos = "center",
    border = "rounded",
  },
  keymaps = {
    --NB: all movements/navigations are cyclic
    -- Keybindings specific to Loft main UI
    ui = {
      ["k"] = "move_up", -- Move cursor up
      ["j"] = "move_down", -- Move cursor down
      ["<C-k>"] = "move_entry_up", -- Move entry (+buffer)
      ["<C-j>"] = "move_entry_down", -- Move entry (+buffer)
      ["<C-d>"] = "delete_entry", -- Delete entry (+buffer)
      ["<CR>"] = "select_entry", -- Select entry (+buffer)
      ["<Esc>"] = "close", -- Close Loft
      ["q"] = "close",
      ["x"] = "toggle_mark_entry", -- Mark or unmark entry
      ["<C-s>"] = "toggle_smart_order", -- Enable or disable smart order status
      ["?"] = "show_help", -- Show Loft help menu
      ["<M-k>"] = "move_up_to_marked_entry", -- Move up to the next marked entry
      ["<M-j>"] = "move_down_to_marked_entry", -- Move down to the next marked entry
    },
    -- Keybindings specific to editor
    general = {
      ["<leader>lf"] = actions.open_loft, -- Open Loft
      ["<Tab>"] = actions.switch_to_next_buffer, -- Navigate to the next buffer
      ["<S-Tab>"] = actions.switch_to_prev_buffer, -- Navigate to the prev buffer
      ["<leader>x"] = actions.close_buffer, -- Close buffer
      ["<leader>X"] = {
        callback = function()
          actions.close_buffer({ force = true })
        end,
        desc = "Force close buffer",
      },
      ["<leader>ln"] = actions.switch_to_next_marked_buffer, -- Navigate to the next marked buffer
      ["<leader>lp"] = actions.switch_to_prev_marked_buffer, -- Navigate to the previous marked buffer
      ["<leader>lm"] = actions.toggle_mark_current_buffer, -- Mark or unmark the current buffer
      ["<leader>ls"] = actions.toggle_smart_order, -- Toggle Smart Order ON and OFF
      ["<leader>la"] = actions.switch_to_alt_buffer, -- Switch to alternate buffer without updating the registry
      ["<S-M-i>"] = actions.move_buffer_up, --  Move the current buffer up while showing the UI briefly
      ["<S-M-o>"] = actions.move_buffer_down, --  Move the current buffer down while showing the UI briefly
    },
  },
  -- Session persistence: saves registry order, marks and smart order state to disk
  -- per working directory, and restores them on the next startup.
  persistence = {
    enabled = false, -- Opt-in: set to true to enable
    path = nil,      -- Defaults to stdpath("data")/loft/<cwd_hash>.json
  },
})
```

### Session plugin compatibility

When `persistence.enabled = true`, loft hooks into the following events to
restore state after a session is loaded:

| Plugin                                                                            | Event hooked                                   |
| --------------------------------------------------------------------------------- | ---------------------------------------------- |
| Native `:mksession` / any `:source session.vim`                                   | `SessionLoadPost` (Neovim built-in)            |
| [folke/persistence.nvim](https://github.com/folke/persistence.nvim)               | `User PersistenceLoadPost` + `SessionLoadPost` |
| [olimorris/persisted.nvim](https://github.com/olimorris/persisted.nvim)           | `User PersistedLoadPost` + `SessionLoadPost`   |
| [stevearc/resession.nvim](https://github.com/stevearc/resession.nvim)             | `User ResessionLoadPost`                       |
| [rmagatti/auto-session](https://github.com/rmagatti/auto-session)                 | `SessionLoadPost`                              |
| [Shatur/neovim-session-manager](https://github.com/Shatur/neovim-session-manager) | `SessionLoadPost`                              |
| No session plugin                                                                 | deferred `VimEnter` fallback                   |

**possession.nvim note**: [jedrzejboczar/possession.nvim](https://github.com/jedrzejboczar/possession.nvim) executes sessions via `nvim_exec2` instead of `:source`, so neither `SessionLoadPost` nor a post-load User event fires. Call loft's restore manually in your `after_load` hook:

```lua
require("possession").setup({
  hooks = {
    after_load = function()
      local p = require("loft.persistence")
      local cfg = require("loft.config").all.persistence
      p.restore(require("loft.registry"), cfg)
    end,
  },
})
```

````

## Commands

| Commands                | Description                                |
| ----------------------- | ------------------------------------------ |
| `:LoftToggle`           | Open or close the Loft UI.                 |
| `:LoftToggleSmartOrder` | Enable or disable the smart order feature. |
| `:LoftToggleMark`       | Toggle mark current buffer.                |

## Autocmds

Loft user autocmds:

| Event                       | Description                                    | Argument                                  |
| --------------------------- | ---------------------------------------------- | ----------------------------------------- |
| `User LoftBufferMark`       | Triggered when a buffer is marked or unmarked. | `{ mark_state: boolean, buffer: number }` |
| `User LoftSmartOrderToggle` | Triggered when smart order state is toggled.   | `smart_order_state: number`               |

## Tips

If you think bufferline sucks and prefer working with the info in statusline like me then you can show the smart order and marked info in your statusline.

Get the info from Loft UI's `smart_order_indicator()` and `get_buffer_mark()` methods and infuse like so:

```lua
vim.api.nvim_set_hl(0, "MiniStatuslineFilename", { fg = "#FFD700", bg = "#262D43", bold = true })
vim.api.nvim_set_hl(0, "StatusLineLoftSmartOrder", { fg = "#ffffff", bg = "#005f87", bold = true })
local smart_order_status = "%#StatusLineLoftSmartOrder#" .. require("loft.ui"):smart_order_indicator()
local buffer_mark = require("loft.ui"):get_buffer_mark()
local filename = MiniStatusline.section_filename({ trunc_width = 140 })
MiniStatusline.combine_groups({
  -- ...
  { hl = "StatusLineLoftSmartOrder", strings = { smart_order_status } },
  "%<",
  -- ...
  { hl = "MiniStatuslineFilename", strings = { filename .. buffer_mark } },
  "%=",
  -- ...
})
````

Then listen for the following Loft's user autocmds and redraw your statusline:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = { "LoftSmartOrderToggle", "LoftBufferMark" },
  callback = function()
    vim.cmd("redrawstatus")
  end,
})
```

Here's what your statusline would look like:

<div>
  <img src="assets/statusline_showcase.png" width="300" alt="Statusline Showcase" />
</div>
<br />

Another little tip: you can search (/) the loft UI by the ID of filename of the entry/buffer to get it.

### Usage with oil.nvim

If you use [`oil.nvim`](https://github.com/stevearc/oil.nvim) (which I recommend for file exploration, btw), you can hook into the `OilActionsPost` user autocmd to clean the Loft registry after file deletion:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "OilActionsPost",
  desc = "Clean Loft registry after oil.nvim deletions",
  callback = function(args)
    local actions = args.data and args.data.actions or {}
    local needs_clean = false
    for _, action in ipairs(actions) do
      if action.type == "delete" or action.type == "trash" then
        needs_clean = true
        break
      end
    end
    if needs_clean then
      local ok, registry = pcall(require, "loft.registry")
      if ok then
        registry:clean()
      end
    end
  end,
})
```

## Contributing

Contributions are welcome! Please feel free to check out the [contribution guide](./CONTRIBUTING.md).

## Roadmap

- **`LoftCloseOthers` command** — Close all buffers in the registry except the current one.
- **`LoftCloseUnmarked` command** — Close all unmarked buffers. Pairs naturally with marking: mark what you want to keep, then run this to clear the rest.
- **In-UI fuzzy filter** — A keymap (e.g. `f`) to filter registry entries in-place by filename/path, making the UI useful in very large buffer lists.
- **Pinned buffers** — A "pinned" state (distinct from marked) that locks a buffer to a fixed position in the registry, making it immune to smart order reordering.
- **`LoftBufferSwitch` event** — A `User` autocmd fired whenever Loft navigates to a buffer (next/prev/marked/alt), useful for statusline and other integrations.
- **`LoftRegistryChanged` event** — A `User` autocmd fired whenever the registry mutates (entries added, removed, reordered), enabling reactive integrations.
- **UI highlight groups** — Dedicated highlight groups (`LoftCurrentBuffer`, `LoftMarkedBuffer`, `LoftModifiedBuffer`, etc.) so the UI is themeable and visually scannable at a glance.
- **UI Customization** — More UI options like layout options (e.g. horizontal list).
- **Tab-local registries** — Option for each tab to maintain its own independent buffer registry, supporting project-separation workflows across tabs.
