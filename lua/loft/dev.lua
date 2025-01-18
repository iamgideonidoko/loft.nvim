local dev = {}

dev.reload_loft = function()
  package.loaded["loft"] = nil
  require("loft").setup()
end

dev.create_reload_command = function()
  vim.api.nvim_create_user_command("ReloadLoft", function()
    dev.reload_loft()
    print("Loft.nvim reloaded!")
  end, {})
end

return dev
