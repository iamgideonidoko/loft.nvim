local commands = {}
local ui_instance = require("loft.ui")

commands.setup = function()
  vim.api.nvim_create_user_command("LoftToggle", function()
    ui_instance:toggle()
  end, { desc = "Toggle the Loft UI" })

  vim.api.nvim_create_user_command("LoftToggleSmartOrder", function()
    local new_state = ui_instance:toggle_smart_order()
    if not ui_instance:is_open() then
      if new_state then
        vim.notify("Smart Order is ON", vim.log.levels.INFO)
      else
        vim.notify("Smart Order is OFF", vim.log.levels.INFO)
      end
    end
  end, { desc = "Toggle Smart Order ON and OFF" })
end

return commands
