-- 이벤트를 저장할 테이블
---@class EventBus
---@field registerEvent fun(self: EventBus, eventName: string, handler: fun(...: any))
---@field invoke fun(self: EventBus, eventName: string, ...: any)
---@field unregisterEvent fun(self: EventBus, eventName: string, handler: fun(...: any))
---@field clearEvent fun(self: EventBus)
---@field clearEventWithName fun(self: EventBus, eventName: string)
---@field private eventList { [string]: fun(...: any)[] }
local events = {
    eventList = {},
}

-- 이벤트를 등록하는 함수
function events:registerEvent(eventName, handler)
    if self.eventList[eventName] == nil then
        self.eventList[eventName] = {handler}
    else
        table.insert(self.eventList[eventName], handler)
    end
end

-- 이벤트를 발생시키는 함수
function events:invoke(eventName, ...)
    if self.eventList[eventName] then
        for _, handler in ipairs(self.eventList[eventName]) do
            handler(...)
        end
    end
end

-- 이벤트를 해제하는 함수
function events:unregisterEvent(eventName, handler)
    if self.eventList[eventName] then
        for i, registeredHandler in ipairs(self.eventList[eventName]) do
            if registeredHandler == handler then
                table.remove(events.eventList[eventName], i)
                break
            end
        end
    end
end

function events:clearEvent()
    self.eventList = {}
end

function events:clearEventWithName(eventName)
    self.eventList[eventName] = nil
end

---@return EventBus
function events.GetLocalEventBus()
    local EventCallback_mt = { __index = events }
    local localEvent = setmetatable({ eventList = {} }, EventCallback_mt)
    return localEvent
end

return events