local utils = require("loft.utils")
local registry_instance = require("loft.registry")

local loft = {}

loft.setup = function()
  registry_instance:setup()
  if utils.is_dev() then
    require("loft.dev").create_reload_command()
  end
end

return loft
