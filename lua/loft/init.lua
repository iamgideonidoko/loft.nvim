---@class Loft
local Loft = {}

function Loft:new()
	self.__index = self
	return setmetatable({}, self)
end

function Loft:setup()
	print("Hello Setup!")
end

local loft = Loft:new()

return loft
