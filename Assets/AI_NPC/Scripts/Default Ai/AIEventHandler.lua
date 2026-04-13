-- AI가 이동할 타겟의 위치와 조건을 정의하는 스크립트


--region Injection list
local _INJECTED_ORDER = 0
local function checkInject(OBJECT) _INJECTED_ORDER = _INJECTED_ORDER+1 assert(OBJECT, _INJECTED_ORDER .. "th object is missing") return OBJECT end
local function NullableInject(OBJECT) _INJECTED_ORDER = _INJECTED_ORDER+1 if OBJECT == nil then Debug.Log(_INJECTED_ORDER .. "th object is missing") end return OBJECT end

--[[ 
---@type TYPE_OF_VARIABLE
--- : 
OBJECT = checkInject(OBJECT) -- {displayName}
]]


---
AiAvatarObject = checkInject(AiAvatarObject) -- AI와의 연결을 담당하는 오브젝트

ChoiceEventData = NullableInject(ChoiceEventData) -- AI가 행동을 선택할 때 전달할 이벤트 데이터
-- ... 
_INJECTED_ORDER = 0
--endregion

local util = require 'xlua.util'

---@type EventBus
local event

---@type JsonUtil
local json

---@type string
-- AI의 선택 이벤트 이름들
local choiceNames

---@type string
-- AI의 선택 이벤트에 대한 추가 지시사항
local subInstruction

---@type AvatarVivenBridge
local avatarVivenBridge

---@type AiConnector
local aiConnector

---@type BasicAvatarManager
local avatarManager

---@type AvatarMoveController
local avatarMoveController

---@type AvatarAnimationController
local avatarAnimationController

---@type table<string, AIMoveTarget>
local moveTargets = {}


---@type string
-- 현재 이동 타겟 이름
local currentMoveTargetName = ""

function start()
    event = Util.EventBus
    json = Util.JsonUtil
    
    -- 선택지 이벤트 데이터 디코딩
    DecodeJson()

    -- avatar 관련 컴포넌트 초기화
    avatarVivenBridge = AiAvatarObject:GetLuaComponent("AvatarVivenBridge")
    aiConnector = AiAvatarObject:GetComponent("AiConnector")
    avatarMoveController = AiAvatarObject:GetLuaComponentInChildren("AvatarMoveController")
    avatarAnimationController = AiAvatarObject:GetLuaComponentInChildren("AvatarAnimationController")
    avatarManager = AiAvatarObject:GetLuaComponent("BasicAvatarManager")

    -- 이동 타겟들 초기화
    local targets = self:GetLuaComponentsInChildren("AIMoveTarget")
    for i = 1, targets.Length do
        local target = targets[i-1]
        Debug.Log("Registering Move Target: " .. target.self.gameObject.name)
        moveTargets[target.self.gameObject.name] = target
    end

    -- 이벤트 구독
    event:registerEvent("AI_EventReceived", OnAiEventReceived_Host)
    event:registerEvent("AI_ArrivedAtMoveTarget", OnAiArrivedAtMoveTarget)
    event:registerEvent("Avatar_AiSessionInitialized", OnAiSessionInit)
    event:registerEvent("Avatar_AiHostChanged", OnAiHostChanged)
end

-- AI와의 연결이 성립되었을 때 실행
function OnAiSessionInit(modelName, isHost)
    -- AI에게 행동 선택 이벤트 전달 (있으면)
if choiceNames == "" or choiceNames == nil then
        return
    end

    -- 호스트인 경우에만 이벤트 전송
    if (isHost and modelName == avatarVivenBridge.GetModelName()) then
        avatarVivenBridge.SendChoiceEvent(choiceNames, subInstruction, -1, -1)
    end
end

-- AI 호스트 변경 이벤트 핸들러
function OnAiHostChanged(modelName, isHost)
    if not isHost then return end
    
    if (currentMoveTargetName ~= "" and currentMoveTargetName ~= nil) then
        -- 호스트가 된 후에도 이동 중이던 타겟이 있으면, 이동 재개
        avatarMoveController.SetNavAgentEnabled(true)
        local targetTransform = moveTargets[currentMoveTargetName].self.transform
        if targetTransform ~= nil then
            avatarMoveController.MoveToTargetPos_Host(targetTransform.position.x, targetTransform.position.y, targetTransform.position.z)
            avatarAnimationController.SetDefaultRotation(moveTargets[currentMoveTargetName].self.transform.rotation)
        end
    end

end

-- AI 이벤트 수신 처리
--- @param eventName string
function OnAiEventReceived_Host(eventName)
    -- eventName에 'Move to '로 시작하는 경우 이동 명령 처리 (대소문자 무시)
    if eventName:lower():sub(1, 8) == "move to " then
        local targetName = eventName:sub(9)
        Debug.Log("Received Move Command to Target: " .. targetName)
        if (moveTargets[targetName].IsNpcTrigger) then
            Debug.Log("이미 해당 이동 타겟에 도달한 상태입니다: " .. targetName)
            return
        end
        local targetTransform = moveTargets[targetName].self.transform
        if targetTransform ~= nil then
            currentMoveTargetName = targetName
            avatarVivenBridge.SendInterruptModeChangeEvent(1)
            avatarManager.RequestAiStateChange_Host(Global_AIState.MOVE)
            avatarMoveController.MoveToTargetPos_Host(targetTransform.position.x, targetTransform.position.y, targetTransform.position.z)
            avatarAnimationController.SetDefaultRotation(moveTargets[targetName].self.transform.rotation)
        else
            Debug.Log("이동 타겟을 찾을 수 없습니다: " .. targetName)
        end
    end
end

function OnAiArrivedAtMoveTarget(targetName)
    if avatarVivenBridge.GetIsMine() == false then
        return
    end
    -- 도착한 이동 타겟에 대한 처리
    Debug.Log("AI가 이동 타겟에 도착했습니다: " .. targetName)
    avatarMoveController.StopMove_Host()

    self:StartCoroutine(util.cs_generator(function ()
        local targetRotation = moveTargets[targetName].self.transform.rotation
        while true do
            -- 회전 도달 여부 확인
            Debug.Log("CuratorScenario: Rotating to Target " .. targetName)
            if Quaternion.Angle(avatarManager.self.transform.rotation, targetRotation) < 1 then
                Debug.Log("CuratorScenario: Rotate Target " .. targetName .. " reached")
                break
            end
            coroutine.yield(nil)
        end

        currentMoveTargetName = ""

        -- 회전 도달 후 AI 상태 변경
        avatarManager.RequestAiStateChange_Host(Global_AIState.DEFAULT)

        avatarVivenBridge.SendNotyEvent("Arrived at " .. targetName, -1, -1)
    end))

end

function sendSyncUpdate()
    local syncTable = {}
    syncTable[1] = currentMoveTargetName
    
    return syncTable
end

function receiveSyncUpdate(syncTable)
    if syncTable == nil then return end
    currentMoveTargetName = syncTable[1] 
end

function DecodeJson()
   -- AI의 이동 조건에 대한 JSON 디코딩 
   if ChoiceEventData == nil then
       choiceNames = ""
       subInstruction = ""
       return
   end

   -- json 형식
    -- {
    --    "eventName": "Move to A, Move to B",
    --    "instruction": "some instruction"
    -- }

    local jsonData = ChoiceEventData.text
    local data = json.decode(jsonData)
    choiceNames = data.event_name
    subInstruction = data.instruction

    Debug.Log("Decoded ChoiceEventData: " .. choiceNames)
    Debug.Log("Decoded SubInstruction: " .. subInstruction)
end