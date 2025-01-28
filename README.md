<div align="center">
  <img src="assets/loft.nvim.png" alt="Logo" />
  <h3 align="center"><code>loft.nvim</code></h3>
  <p align="center">Streamlined plugin for productive buffer management</p>
</div>
<br />

## Table of Content

- [Introduction](#introduction)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
  - [Default Options](#default-options)
- [Commands](#commands)
- [Roadmap](#roadmap)

## Introduction

https://github.com/user-attachments/assets/312a06be-a2c0-4f4f-9fd2-e404c737cb89

`loft.nvim`, a powerful yet lightweight Neovim plugin for efficient buffer management with an intuitive UI and cool features like:

- Registry-based buffer tracking and state management.
- Smart Order (automatically reorganize buffers for quick access).
- Floating UI that displays a customizable list of entries (buffers + state).
- Mark/unmark buffers/entries you want to focus on with persistent tracking.
- Cyclic but slick buffer navigation to all/marked entry/buffer.
- Configurable window options, keybindings, and more for streamlined control.
- Dynamic help UI that displays commands, keymaps, and events.

With all these, it's a lot easier to just **focus** on your code.

## Requirements

- Neovim 0.8+

## Installation

lazy.nvim:

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
  -- Whether to move the current buffer to the second to last position (just before the
  -- selected buffer, which will be the last position) in the registry during Telescope selection
  move_curr_buf_on_telescope_select = true,
  close_invalid_buf_on_switch = true, -- Whether to close invalid buffers during navigation
  enable_smart_order_by_default = true, -- Whether to enable smart order by default
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
    },
  },
})
```

## Commands

| Commands                | Description                                |
| ----------------------- | ------------------------------------------ |
| `:LoftToggle`           | Open or close the Loft UI.                 |
| `:LoftToggleSmartOrder` | Enable or disable the smart order feature. |

## Autocmds

Loft user autocmds:

| Event                       | Description                                    | Argument                                  |
| --------------------------- | ---------------------------------------------- | ----------------------------------------- |
| `User LoftBufferMark`       | Triggered when a buffer is marked or unmarked. | `{ mark_state: boolean, buffer: number }` |
| `User LoftSmartOrderToggle` | Triggered when smart order state is toggled.   | `smart_order_state: number`               |

## Roadmap

- Improve documentation (Readme, Neovim help doc, contribution guide, etc.).
- Add a logger for debugging purposes.
- Improve quality with automated tests.
- Implement CI/CD to run tests.
- Registry/state persistence across sessions (investigate the plugin experience with session persistence plugins)
- Add buffer-relative UI to show info like the filename/path, marked/modified state, etc. (I'll only get to this if it's requested by many)
