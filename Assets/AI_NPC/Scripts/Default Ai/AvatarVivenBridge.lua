-- Viven(C#)과 Lua 이벤트 시스템 사이의 브릿지
-- Viven에서 받은 이벤트를 Lua로 전파하고, Lua에서 Viven으로 명령을 전달합니다.

---@class AvatarVivenBridge
---@field NetworkVoiceBridgeObject GameObject NetworkVoiceBridge 오브젝트
---@field SetSpeakState fun(isCanSpeak:boolean) 말하기 상태 설정
---@field SetAiMode fun(isSet:boolean) AI 모드 설정
---@field OnAiSpeakDetected fun(uuid:string, index:number, textKr:string, textEn:string, emotion:string, eventName:string) ai의 발화가 감지되었을 때 호출되는 함수
---@field OnAiDetectClientAudio fun(uuid:string) 사용자의 유효한 발
---@field OnPlayerSpeakDetected fun(isSpeaking:boolean) 나의 발화가 감지되었을때 호출되는 함수
---@field OnUtteranceStarted fun(uuid:string, index:number) 발화가 시작되었을 때 호출되는 함수
---@field OnUtteranceCompleted fun(uuid:string, index:number) 발화가 완료되었을 때 호출되는 함수
---@field SendNotyEvent fun(notyInfo:string, inferenceMode:number, interruptMode:number) 알림 이벤트 전송
---@field SendRequestEvent fun(behaviour:string, instruction:string, inferenceMode:number, interrupt
---@field SendChoiceEvent fun(behaviours:string, instruction:string, inferenceMode:number, interruptMode:number) 요청 이벤트 전송
---@field SendApplyConversationEvent fun(speakerType:string, speakerName:string, text:string, inferenceMode:number, interruptMode:number) 대화 반영 이벤트 전송
---@field SendInterruptModeChangeEvent fun(interruptMode:number) 인터럽트만 변경하는 이벤트 전송
---@field ForceStopAllAudio_Host fun() 강제로 현재 들어온 모든 오디오를 중단
---@field GetIsMine fun() boolean 소유권이 자신인지 여부 반환
---@field GetControlUser fun() string 소유자 사용자 ID 반환
---@field SetUri fun(uri:string) URI 설정
---@field SetPath fun(path:string) 경로 설정
---@field SetAiName fun(name:string) AI 이름 설정
---@field SetModelName fun(name:string) 모델 이름 설정
---@field GetModelName fun() string 모델 이름 반환
---@field GetAiName fun() string AI 이름 반환
---@field GetAiId fun() string AI ID 반환
---@field SendEventTrigger fun(eventType:string, eventName:string, eventReference:string) 이벤트 트리거 전송
---@field ResetAllServer fun() 서버의 모든 상태를 초기화합니다. 반드시 필요한 경우에만 사용하세요.

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
---@type GameObject
-- NetworkVoiceBridge 오브젝트
 NetworkVoiceBridgeObject = checkInject(NetworkVoiceBridgeObject) --  AIManager
_INJECTED_ORDER = 0
--endregion

local vObject

---@type EventBus
local event

---@type NetworkVoiceBridge
local networkVoiceBridge    

---@type AiConnector
local aiConnector

---@type number
-- AI 커넥터 수
local aiCount = 0

-- 플레이어가 말할 수 있는지 여부
local isPlayerCanSpeak = false

-- AI 모드가 설정되었는지 여부
local isModeSet = false

-- 재연결 중인지 여부 (ReconnectServer 후 host 복구용)
local isReconnecting = false

-- 마지막으로 요청한 동작과 지시문
local lastRequest = {
    ["behaviour"] = "",
    ["instruction"] = "",
    ["inferenceMode"] = 0,
    ["interruptMode"] = 0
}

local util = require 'xlua.util'

function awake()
    event = Util.EventBus
    networkVoiceBridge = NetworkVoiceBridgeObject:GetComponent("NetworkVoiceBridge")
    aiConnector = self:GetComponent("AiConnector")
    vObject = self:GetComponent(typeof(VObject))
end

function start()
    networkVoiceBridge.onPlayerSpeakDetected = OnPlayerSpeakDetected
    networkVoiceBridge.onClientTranscriptReceived = OnClientTranscriptReceived
    networkVoiceBridge.onClientInitialized = OnClientInitialized
    networkVoiceBridge.onDisconnected = OnDisconnected
    aiConnector.onAiSpeakDetected = OnAiSpeakDetected
    aiConnector.onAiDetectClientAudio = OnAiDetectClientAudio
    aiConnector.onUtteranceStarted = OnUtteranceStarted
    aiConnector.onUtteranceCompleted = OnUtteranceCompleted
    aiConnector.onAiAudioDataIndexUpdated = OnAiAudioDataIndexUpdated
    aiConnector.onAiErrorReceived = OnAiErrorReceived
    aiCount = networkVoiceBridge:GetAiConnectorCount()
    if (aiCount < 2) then
        isModeSet = true
    end

    event:registerEvent("Avatar_Reconnect", ReconnectServer)
end


--#region Voice Chat

-- 말하기 상태 설정
---@param isCanSpeak boolean 말할 수 있는지 여부
function SetSpeakState(isCanSpeak)
    if (aiConnector ~= nil) then
        isPlayerCanSpeak = isCanSpeak
        isCanSpeak = isPlayerCanSpeak and isModeSet
        aiConnector:SetCanSpeak(isCanSpeak)
    end
end

-- AI 모드 설정
---@param isSet boolean 모드가 설정되었는지 여부
function SetAiMode(isSet)
    isModeSet = isSet
    SetSpeakState(isPlayerCanSpeak)
end

-- ai의 발화가 감지되었을 때 호출되는 함수
---@param uuid string 문단의 UUID
---@param index number 문장 인덱스
---@param textKr string 한국어 텍스트
---@param textEn string 영어 텍스트
---@param emotion string 감정
---@param eventName string 이벤트 이름
function OnAiSpeakDetected(uuid, index, textKr, textEn, emotion, eventName)
    event:invoke("Avatar_AiSpeakDetected", GetAiId(), uuid, index, textKr, textEn, emotion, eventName)
end

-- ai의 오디오 데이터 인덱스가 업데이트되었을 때 호출되는 함수
---@param uuid string 문단의 UUID
---@param index number 문장 인덱스
---@param eventName string 이벤트 이름
function OnAiAudioDataIndexUpdated(uuid, index, eventName)
    if (aiConnector == nil) then return end

    if (eventName == lastRequest["behaviour"]) then
        lastRequest["behaviour"] = ""
        lastRequest["instruction"] = ""
    end

    event:invoke("Avatar_AiAudioDataIndexUpdated", GetAiId(), uuid, index, eventName)
end

-- 사용자의 유효한 발화가 감지되었을 때 호출되는 함수. 호스트에서만 호출됩니다.
---@param uuid string 감지된 시점에서 재생되고 있던 문단의 UUID
function OnAiDetectClientAudio(uuid)
    event:invoke("Avatar_AiDetectClientAudio", GetAiId(), uuid)
end

-- 나의 발화가 감지되었을때 호출되는 함수. 서버에 연결되어 있고, NPC 근처에서 말한 경우에만 호출됩니다.
---@param isSpeaking boolean 사용자가 말하고 있는지 여부
function OnPlayerSpeakDetected(isSpeaking)
    event:invoke("Avatar_PlayerSpeakDetected", isSpeaking)
end

-- 내 음성의 전사 결과가 도착했을 때 호출되는 함수
---@param textKr string 한국어 전사 텍스트
---@param textEn string 영어 전사 텍스트
function OnClientTranscriptReceived(textKr, textEn)
    if (aiConnector == nil) then return end
    event:invoke("Avatar_ClientTranscriptReceived", textKr, textEn)
end

function OnUtteranceStarted(id, uuid, index)
    event:invoke("Avatar_UtteranceStarted", id, uuid, index)
end

function OnUtteranceCompleted(id, uuid, index)
    event:invoke("Avatar_UtteranceCompleted", id, uuid, index)
end

function OnAiErrorReceived(id, uuid, index, errorMessage, detail)
    event:invoke("Avatar_AiErrorReceived", id, uuid, index, errorMessage, detail)
end

function OnClientInitialized(isInitialized)
    Debug.Log("[AvatarVivenBridge] OnClientInitialized: " .. tostring(isInitialized) .. ", isReconnecting=" .. tostring(isReconnecting) .. ", IsMine=" .. tostring(vObject.IsMine))
    event:invoke("Avatar_ClientInitialized", isInitialized)

    if isReconnecting and isInitialized and vObject.IsMine then
        local currentAiId = aiConnector:GetAiId()
        if currentAiId ~= nil and currentAiId ~= "" then
            -- AI 세션이 살아있는 경우 (여럿일 때): host 복구 + 영역 재감지
            Debug.Log("[AvatarVivenBridge] Reconnect 후 AI host 복구 요청 - RequestSessionHostChange 호출 (aiId=" .. currentAiId .. ")")
            networkVoiceBridge:RequestSessionHostChange()
            Debug.Log("[AvatarVivenBridge] Reconnect 후 플레이어 영역 재감지 요청 - Avatar_CheckPlayerInArea")
            event:invoke("Avatar_CheckPlayerInArea")
        else
            -- AI 세션이 삭제된 경우 (혼자일 때): TryInitializeAi에서 새로 init → 정상 흐름 처리
            Debug.Log("[AvatarVivenBridge] Reconnect - aiId 비어있음. AI 재초기화는 정상 흐름으로 처리")
        end
        isReconnecting = false
    elseif isReconnecting and not isInitialized then
        Debug.Log("[AvatarVivenBridge] Reconnect 중 client init 실패 - isReconnecting 리셋")
        isReconnecting = false
    end
end

function OnDisconnected()
    event:invoke("Avatar_Disconnected")
end

-- 알림 이벤트 전송
-- 비벤에서 발생하는 일들에 대해 AI에게 알리는 역할 -> 이것으로 LLM을 트리거 시키지는 않음.
---@param notyInfo string 알림 정보
---@param inferenceMode number LLM 트리거 모드
---@param interruptMode number 인터럽트 모드
function SendNotyEvent(notyInfo, inferenceMode, interruptMode)
    if aiConnector then
        aiConnector:SendNotyEvent(notyInfo, inferenceMode, interruptMode)
    end
end

-- 요청 이벤트 전송
-- AI에게 어떠한 행동을 요청하는 것
    ---@param behaviour string 요청할 동작
    ---@param instruction string 세부 지시문
    ---@param inferenceMode number LLM 트리거 모드. 1: 트리거 함, -1: 트리거 안함
    ---@param interruptMode number 인터럽트 모드 1의 경우 inference를 켜준다면 추론 신호를 한번 주고 만약 현재 어떤 데이터를 처리 중이거나 llm이 추론 중이라면, 추론이 중지되고 반영. 그렇지 않은 경우 바로 반영.
    function SendRequestEvent(behaviour, instruction, inferenceMode, interruptMode)
        if aiConnector then
            lastRequest["behaviour"] = behaviour
            lastRequest["instruction"] = instruction
            lastRequest["inferenceMode"] = inferenceMode
            lastRequest["interruptMode"] = interruptMode
            aiConnector:SendRequestEvent(behaviour, instruction, inferenceMode, interruptMode)
        end
    end

    -- 요청 이벤트 전송
    -- AI에게 어떤 행동을 할지 선택지를 주는 것
    ---@param behaviours string AI에게 제공할 행동 선택지. 쉼표(,)로 구분된 문자열
    ---@param instruction string 세부 지시문
    ---@param inferenceMode number LLM 트리거 모드. 1: 트리거 함, -1: 트리거 안함
    ---@param interruptMode number 인터럽트 모드 1의 경우 inference를 켜준다면 추론 신호를 한번 주고 만약 현재 어떤 데이터를 처리 중이거나 llm이 추론 중이라면, 추론이 중지되고 반영. 그렇지 않은 경우 바로 반영.
    function SendChoiceEvent(behaviours, instruction, inferenceMode, interruptMode)
        if aiConnector then
            Debug.Log("SendChoiceEvent: behaviours=" .. behaviours .. ", instruction=" .. instruction .. ", inferenceMode=" .. tostring(inferenceMode) .. ", interruptMode=" .. tostring(interruptMode))
            aiConnector:SendChoiceEvent(behaviours, instruction, inferenceMode, interruptMode)
        else
            Debug.Log("SendChoiceEvent failed: aiConnector is nil")
        end
    end

    -- 대화 반영 이벤트 전송
    -- 사전에 만들어놓은 음성이 LLM과 무관하게 재생되었을 때 대화 반영을 위함 
    ---@param speakerType string 화자 유형 'ai' or 'user'
    ---@param speakerID string 화자 ID
    ---@param speakerName string 화자 이름
    ---@param text string 대화 텍스트
    ---@param inferenceMode number LLM 트리거 모드 1: 트리거 함, -1: 트리거 안함
    ---@param interruptMode number 인터럽트 모드 1의 경우 inference를 켜준다면 추론 신호를 한번 주고 만약 현재 어떤 데이터를 처리 중이거나 llm이 추론 중이라면, 추론이 중지되고 반영. 그렇지 않은 경우 바로 반영.
    function SendApplyConversationEvent(speakerType, speakerName, text, inferenceMode, interruptMode)
        if aiConnector then
            aiConnector:SendApplyConversationEvent(speakerType, speakerName, text, inferenceMode, interruptMode)
        end
    end

    -- 인터럽트만 변경하는 이벤트 전송
    ---@param interruptMode number 인터럽트 모드 1의 경우 inference를 켜준다면 추론 신호를 한번 주고 만약 현재 어떤 데이터를 처리 중이거나 llm이 추론 중이라면, 추론이 중지되고 반영. 그렇지 않은 경우 바로 반영.
    function SendInterruptModeChangeEvent(interruptMode)
        if aiConnector then
            aiConnector:SendInterruptModeChangeEvent(interruptMode)
    end
end

-- 강제로 현재 들어온 모든 오디오를 중단하고자 할 때 실행됩니다. 특정 이벤트가 호출되었을 때 말을 하고 싶지 않을 때 등 사용하면 됩니다.
function ForceStopAllAudio_Host()
    if aiConnector then
        aiConnector:StopAllAudio()
    end
end

--#endregion

--#region 동기화 관련 함수

-- 소유권이 자신인지 여부 반환
---@return boolean isMine 소유권이 자신인지 여부
function GetIsMine()
    return vObject.IsMine
end

-- 소유자 사용자 ID 반환
---@return string userId 소유자 사용자 ID
function GetControlUser()
    return vObject.ControlUserId
end

-- #endregion

--#region NetworkVoiceBridge 설정 함수

function ReconnectServer()
    local playerCount = Room.CurrentRoomPlayers.Count
    Debug.Log("[AvatarVivenBridge] ReconnectServer 호출 - IsMine=" .. tostring(vObject.IsMine) .. ", playerCount=" .. tostring(playerCount))
    isReconnecting = true

    -- 혼자일 때 DoFullDisconnect에서 Multi AI가 삭제되므로
    -- aiId를 리셋하여 TryInitializeAi에서 새로 InitAiSession하도록 함
    if playerCount <= 1 and aiCount >= 2 then
        Debug.Log("[AvatarVivenBridge] 방에 혼자 - Multi AI aiId 리셋하여 재초기화 준비")
        aiConnector.aiId = ""
    end

    networkVoiceBridge:ReconnectServer()
end

-- URI 설정
---@param uri string 서버 URI
function SetUri(uri)
    networkVoiceBridge.uri = uri
end

-- 경로 설정
---@param path string 서버 경로
function SetPath(path)
    networkVoiceBridge.path = path
end

-- AI 이름 설정
---@param name string AI 이름
function SetAiName(name)
    aiConnector.aiName = name
end

function GetAiName()
    return aiConnector.aiName
end

function GetAiName()
    return aiConnector.aiName
end

function GetAiId()
    return aiConnector:GetAiId()
end

function GetIsClientInit()
    return networkVoiceBridge.IsClientInitialized
end

function SetModelName(name)
    aiConnector.modelName = name
end

function GetModelName()
    return aiConnector.modelName
end

--#endregion

--#reigion Debug

--- 서버의 모든 상태를 초기화합니다. 반드시 필요한 경우에만 사용하세요.
function ResetAllServer()
    networkVoiceBridge:ResetEntireServer()
end

function GetLastRequest()
    return lastRequest
end

--#endregion