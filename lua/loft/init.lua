local utils = require("loft.utils")
local registry_instance = require("loft.registry")
local config = require("loft.config")

local loft = {}

---@type fun(opts: loft.SetupConfig?)
loft.setup = function(opts)
  registry_instance:setup()
  config.setup(opts)
  if utils.is_dev() then
    require("loft.dev").create_reload_command()
  end
end

return loft
