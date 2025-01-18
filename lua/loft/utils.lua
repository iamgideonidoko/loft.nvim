local constants = require("loft.constants")

local utils = {}

utils.is_dev = function()
  return require("lazy.core.config").plugins[constants.PLUGIN_NAME].dev
end

return utils
