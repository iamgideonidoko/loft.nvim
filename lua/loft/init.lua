local utils = require("loft.utils")

local loft = {}

loft.setup = function()
  print("Setup initialized")
  if utils.is_dev() then
    require("loft.dev").create_reload_command()
  end
end

return loft
