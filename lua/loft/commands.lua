local commands = {}
local ui_instance = require("loft.ui")
local actions = require("loft.actions")

commands.setup = function()
  vim.api.nvim_create_user_command("LoftToggle", function()
    ui_instance:toggle()
  end, { desc = "Toggle the Loft UI" })

  vim.api.nvim_create_user_command(
    "LoftToggleSmartOrder",
    actions.toggle_smart_order.func,
    { desc = actions.toggle_smart_order.desc }
  )

  vim.api.nvim_create_user_command(
    "LoftToggleMark",
    actions.toggle_mark_current_buffer.func,
    { desc = actions.toggle_mark_current_buffer.desc }
  )

  vim.api.nvim_create_user_command("LoftCloseOthers", function(cmd_opts)
    actions.close_others({ force = cmd_opts.bang })
  end, { bang = true, desc = "Close all buffers except the current one (! to force)" })

  vim.api.nvim_create_user_command("LoftCloseUnmarked", function(cmd_opts)
    actions.close_unmarked({ force = cmd_opts.bang })
  end, { bang = true, desc = "Close all unmarked buffers (! to force)" })
end

return commands
