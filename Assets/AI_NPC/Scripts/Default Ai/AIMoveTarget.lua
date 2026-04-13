-- AI가 이동할 타겟의 위치와 조건을 정의하는 스크립트

---@class AIMoveTarget
---@field IsNpcTrigger boolean NPC가 현재 이 트리거에 도달했는지 여부


--region Injection list
local _INJECTED_ORDER = 0
local function checkInject(OBJECT) _INJECTED_ORDER = _INJECTED_ORDER+1 assert(OBJECT, _INJECTED_ORDER .. "th object is missing") return OBJECT end
local function NullableInject(OBJECT) _INJECTED_ORDER = _INJECTED_ORDER+1 if OBJECT == nil then Debug.Log(_INJECTED_ORDER .. "th object is missing") end return OBJECT end

--[[ 
---@type TYPE_OF_VARIABLE
--- : 
OBJECT = checkInject(OBJECT) -- {displayName}
]]
-- ... 
_INJECTED_ORDER = 0
--endregion

local util = require 'xlua.util'

local event

IsNpcTrigger = false

function start()
    event = Util.EventBus
end

function onTriggerEnter(col)
    -- 타겟 위치에 AI가 도달했음. 이동 종료
    if (col.gameObject:GetComponent("AiConnector") ~= nil) then
        -- 이동 도달 처리
        event:invoke("AI_ArrivedAtMoveTarget", self.gameObject.name)
        IsNpcTrigger = true
    end
end

function onTriggerExit(col)
    if (col.gameObject:GetComponent("AiConnector") ~= nil) then
        -- 이동 도달 처리
        event:invoke("AI_ArrivedAtMoveTarget", self.gameObject.name)
        IsNpcTrigger = false
    end
end