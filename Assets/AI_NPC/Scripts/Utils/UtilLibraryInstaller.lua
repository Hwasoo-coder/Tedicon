-- Utility Libraries Installer

local eventBus = ImportLuaScript(EventBus)
local jsonUtil = ImportLuaScript(JsonUtil)

---@class Utility
---@field EventBus EventBus
---@field JsonUtil json

local utilityLibraries = {
    EventBus = eventBus,
    JsonUtil = jsonUtil,
}

self.LuaEnv.Global.Util = utilityLibraries
Util = utilityLibraries

return utilityLibraries