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
    { desc = "Toggle Smart Order ON and OFF" }
  )
end

return commands
