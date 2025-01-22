local config = require("loft.config")
local utils = require("loft.utils")
local registry_instance = require("loft.registry")
local ui_instance = require("loft.ui")

local loft = {}

---@type fun(opts: loft.SetupConfig?)
loft.setup = function(opts)
  config.setup(opts)
  registry_instance:setup()
  ui_instance:setup({ config = config.all })
  if utils.is_dev() then
    require("loft.dev").create_reload_command()
  end
end

return loft
