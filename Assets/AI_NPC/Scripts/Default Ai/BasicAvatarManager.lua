-- AI의 기능을 관리하는 기본 아바타 매니저 스크립트

---@class BasicAvatarManager
---@field OnAvatarPlayerEnter fun(userId:string) 플레이어가 아바타 영역에 들어왔을때 호출되는 함수
---@field OnAvatarPlayerExit fun(userId:string) 플레이어가 아바타 영역에서 나갔을때 호출되는 함수
---@field OnAvatarAreaHasPlayerEnter fun() 아바타 영역에 플레이어가 들어왔을때 호출되는 함수
---@field OnAreaHasNoPlayer fun() 아바타 영역에 플레이어가 아무도 없을때 호출되는 함수
---@field OnPlayerSpeakDetected fun(isSpeaking:boolean) 나의 발화가 감지되었을때 호출되는 함수
---@field OnPlayerStopSpeak_Host fun() 플레이어가 말하기를 멈췄을때 호출되는 함수
---@field OnAiClientAudioDetected_Host fun(id:string, uuid:string) 사용자의 유효한 발화가 감지되었을때 호출되는 함수
---@field OnAiSpeakDetected fun(id:string, uuid:string, index:number, textKr:string, textEn:string, emotion:string, eventName:string) ai의 발화가 감지되었을 때 호출되는 함수
---@field OnAiSpeakUtteranceStarted fun(id:string, uuid:string, index:number) AI의 발화 문장이 시작되었을때 호출되는 함수
---@field OnAiSpeakUtteranceCompleted fun(id:string, uuid:string, index:number) AI의 발화 문장이 완료되었을때 호출되는 함수
---@field OnAiAudioDataIndexUpdated fun(id:string, uuid:string, index:number, eventName:string) AI의 오디오 데이터 인덱스가 업데이트 되었을때 호출되는 함수
---@field RequestAiStateChange_Host fun(newState:number) AI 상태 변경 요청 함수
---@field SetThinkState_Host fun(isThinking:boolean) 생각 상태 설정 요청 함수
---@field PlayMouthByWeight fun() 입 모양을 볼륨에 따라 설정하는 함수
---@field StopMouth fun() 입 모양 정지 함수
---@field RegisterSpeechInformation fun(uuid:string, index:number, textKr:string, textEn:string, emotion:string, eventName:string, speakIndex:number) AI의 발화 정보 등록 함수
---@field ResetAvatarTransform fun() 아바타의 위치와 회전을 시작 지점으로 초기화하는 함수

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
-- AI 아바타의 초기 위치를 지정하는 오브젝트. 반드시 AI 아바타 하위에 없는 오브젝트여야 함.
StartPointObject = checkInject(StartPointObject) -- {StartPoint}
_INJECTED_ORDER = 0
--endregion

local util = require 'xlua.util'

---@type AvatarVivenBridge
local avatarVivenBridge

---@type NetworkVoiceBridge
local networkVoiceBridge

---@type AvatarAnimationController
local avatarAnimationController

---@type AvatarSpeechController
local avatarSpeechController

---@type AvatarMoveController
local avatarMoveController

---@type AvatarBlendShapeController
local avatarBlendShapeController

---@type AvatarUIManager
local avatarUiManager

---@type MouthOpenCalculator
-- 기본 입 모양 계산기
local defaultMouthOpenCalculator

---@type AiConnector
local aiConnector

---@type EventBus
local event

---@class SpeechInfo
---@field uuid string 현재 문단의 고유 ID
---@field sentences table<number, SpeechSentenceInfo> 문장 정보 목록

---@class SpeechSentenceInfo
---@field textKr string 한국어 텍스트
---@field textEn string 영어 텍스트
---@field emotion string 감정
---@field speakAnimationIndex number 발화 애니메이션 인덱스
---@field eventName string 이벤트 이름

---@type SpeechInfo
local speechInfo = {
    uuid = "",  -- 현재 문단의 고유 ID
    sentences = {},  -- { [index] = { textKr = "문장(한국어)", textEn = "문장(영어)", emotion = "감정", speakAnimationIndex = 0, eventName = "이벤트" } }
}

local registeredUuids = {}

---@type coroutine
-- 입 모양 움직이는 루틴
local mouthMoveRoutine

---@type Global_AIState
local aiState = { -- todo 너무 빨리 바꾸지 않도록 주의 -> 최소 한 틱 쉬고 바꿔주기
    DEFAULT = 0, -- 기본 상태. 아무 것도 하지 않음
    LISTEN = 1, -- 듣기 상태. 귀 기울이는 UI
    THINK = 2, -- 생각 상태. 생각하는 UI
    MOVE = 3, -- 이동 상태. 걷는 UI
    SPEAK = 4, -- 말하기 상태. 말하는 UI
    WAIT = 5, -- 대기 상태. 대기하는 UI. 
}

Global_AIState = aiState
self.LuaEnv.Global.Global_AIState = aiState

local currentAIState = -1

local isAiSessionInit = false

-- viseme 모드: "A", "E", "O"
local VIS_A = 1
local VIS_E = 2
local VIS_O = 3

function start()
    event = Util.EventBus
    avatarVivenBridge = self:GetLuaComponent("AvatarVivenBridge")
    networkVoiceBridge = avatarVivenBridge.NetworkVoiceBridgeObject:GetComponent("NetworkVoiceBridge")
    avatarAnimationController = self:GetLuaComponentInChildren("AvatarAnimationController")
    avatarSpeechController = self:GetLuaComponentInChildren("AvatarSpeechController")
    avatarMoveController = self:GetLuaComponentInChildren("AvatarMoveController")
    avatarBlendShapeController = self:GetLuaComponentInChildren("AvatarBlendShapeController")

    aiConnector = self:GetComponent("AiConnector")

    avatarUiManager = self:GetLuaComponentInChildren("AvatarUIManager")
    defaultMouthOpenCalculator = self:GetComponent("MouthOpenCalculator")

    event:registerEvent("Avatar_PlayerEnter", OnAvatarPlayerEnter)
    event:registerEvent("Avatar_PlayerExit", OnAvatarPlayerExit)
    event:registerEvent("Avatar_AreaHasPlayerEnter", OnAvatarAreaHasPlayerEnter)
    event:registerEvent("Avatar_AreaHasNoPlayer", OnAreaHasNoPlayer)
    event:registerEvent("Avatar_AiSpeakDetected", OnAiSpeakDetected)
    event:registerEvent("Avatar_AiDetectClientAudio", OnAiClientAudioDetected_Host)
    event:registerEvent("Avatar_PlayerSpeakDetected", OnPlayerSpeakDetected)
    event:registerEvent("Avatar_PlayerStopSpeak", OnPlayerStopSpeak_Host)
    event:registerEvent("Avatar_UtteranceStarted", OnAiSpeakUtteranceStarted)
    event:registerEvent("Avatar_UtteranceCompleted", OnAiSpeakUtteranceCompleted)
    event:registerEvent("Avatar_AiAudioDataIndexUpdated", OnAiAudioDataIndexUpdated)
    event:registerEvent("Avatar_AiErrorReceived", OnAiErrorReceived_Host)
    event:registerEvent("Avatar_ClientInitialized", OnClientInitialized)
    event:registerEvent("Avatar_Disconnected", OnDisconnect)
    PlayMouthByWeight()

    aiConnector.onAiTokenExceededReceived = OnAiTokenExceed
    aiConnector.onAiSessionInit = OnAiSessionInit
    aiConnector.onAiHostChanged = OnAiHostChanged

    -- 입 크기 민감도 기본값 설정. 이 값을 높이면 입 모양이 더 크게 벌어짐
    SetMouthSensitivity(100)
end

--#region 아바타 영역 관련 함수

-- 플레이어가 아바타 영역에 들어왔을때 호출되는 함수
---@param userId string 플레이어의 사용자 ID
function OnAvatarPlayerEnter(userId)
    if (userId == Player.Mine.UserID) then
        -- 자신이 영역에 들어왔을때 말하기 상태 활성화
        avatarVivenBridge.SetSpeakState(true)
    end
end

-- 아바타 영역에 플레이어가 들어왔을때 호출되는 함수
function OnAvatarAreaHasPlayerEnter()
end

-- 플레이어가 아바타 영역에서 나갔을때 호출되는 함수
---@param userID string
function OnAvatarPlayerExit(userID)
    if (userID == Player.Mine.UserID) then
        -- 자신이 영역에서 나갔을때 말하기 상태 비활성화
        avatarVivenBridge.SetSpeakState(false)
    end
end

-- 아바타 영역에 플레이어가 아무도 없을때 호출되는 함수
function OnAreaHasNoPlayer()
    if (avatarVivenBridge.GetIsMine() == true) then
        OnAreaHasNoPlayer_Host()
    end
end

function OnAreaHasNoPlayer_Host()
    -- 듣고 있던 상태에서 모든 유저가 공간을 벗어남 
    if (currentAIState == aiState.LISTEN) then
        RequestAiStateChange_Host(aiState.DEFAULT)
    end
    avatarAnimationController.StopLookAtTarget_Request()
end

--#endregion

--#region 플레이어 발화 관련 함수

-- 나의 발화가 감지되었을때 호출되는 함수
---@param isSpeaking boolean 사용자가 말하고 있는지 여부
function OnPlayerSpeakDetected(isSpeaking)
    avatarSpeechController.PlayerSpeakDetected(Player.Mine.UserID, isSpeaking)
end

-- 플레이어가 말하기를 멈췄을때 호출되는 함수
function OnPlayerStopSpeak_Host()
     -- ai 아바타가 생각하는 애니메이션 실행
    RequestAiStateChange_Host(aiState.THINK)
end

-- 사용자의 유효한 발화가 감지되었을때 호출되는 함수
---@param uuid string 발화한 시점에서 AI가 재생하고 있던 문단의 고유 ID
function OnAiClientAudioDetected_Host(id, uuid)
    if id ~= avatarVivenBridge.GetAiId() then
        Debug.Log("OnAiClientAudioDetected_Host: 다른 AI의 발화입니다. id=" .. id .. ", target id=" .. avatarVivenBridge.GetAiId() .. ")")
        return
    end

    Debug.Log("OnAiClientAudioDetected_Host: " .. id)

    -- 저장된 문장 정보 전부 리셋
    SendRPC_All("ResetSpeechInformation")
    -- 자막 초기화
    avatarUiManager.SetSpeechSub_Request("", "")
    avatarSpeechController.IsValidListening = true

    avatarAnimationController.IsSpeaking = false

    -- todo 모든 유저의 오디오 정지
    SendRPC_All("StopAudio")

    -- 최근에 말한 플레이어를 쳐다봄
    local recentSpeakingPlayer = avatarSpeechController.GetRecentSpeakStartPlayer()
    if (recentSpeakingPlayer ~= "") then
        avatarAnimationController.StartLookAtPlayer_Request(recentSpeakingPlayer, -1)
    end

    RequestAiStateChange_Host(aiState.LISTEN)
end

function StopAudio()
    aiConnector:ResetAudio(avatarVivenBridge.GetAiId())
end
--#endregion

--#region AI 발화 관련 함수

function OnAiAudioDataIndexUpdated(id, uuid, index, eventName)
    if id ~= avatarVivenBridge.GetAiId() then
        return
    end

    Debug.Log("[BasicAvatarManager] OnAiAudioDataIndexUpdated: " .. uuid .. ", " .. index .. ", " .. eventName)
    RegisterSpeechInformation(uuid, index, "", "", "", eventName, 0)
end

function OnAiErrorReceived_Host(id, uuid, index, errorMessage, detail)
    if id ~= avatarVivenBridge.GetAiId() then
        return
    end

    Debug.Log("[BasicAvatarManager] OnAiErrorReceived_Host: errorMessage = " .. errorMessage)
    if (errorMessage == "llm_no_inference_at_all" or errorMessage == "llm_error_in_the_middle" or errorMessage == "tts") then
        local lastRequest = avatarVivenBridge.GetLastRequest()
        if (lastRequest["behaviour"] ~= "") then
            -- 특정한 동작 요청하여 처리 중 이었다면, 동일한 요청을 다시 보냄
            avatarVivenBridge.SendRequestEvent(lastRequest["behaviour"], lastRequest["instruction"], lastRequest["inferenceMode"], lastRequest["interruptMode"])
        else
            -- 다시 말해 달라고 요청
            UI.ToastWarningMessage("AI가 답변을 생성하지 못했습니다. 다시 시도해 주세요.")
        end

        -- 발화 정보 초기화
        SendRPC_All("ResetSpeechInformation")

        -- 생각하거나 말하는 상태였다면, 취소
        if (currentAIState == aiState.THINK or currentAIState == aiState.SPEAK) then
            avatarVivenBridge.ForceStopAllAudio_Host()
            RequestAiStateChange_Host(aiState.DEFAULT)
        end
    elseif (errorMessage == "translation") then
      -- 번역 에러 발생으로 자막 정보가 들어오지 않음.
      -- 여기서는 추가적인 처리 하지 않음
    end
end

-- ai의 발화가 감지되었을 때 호출되는 함수
-- 문장 단위로 여러 개가 순서대로 들어옴
function OnAiSpeakDetected(id, uuid, index, textKr, textEn, emotion, eventName)
    if id ~= avatarVivenBridge.GetAiId() then
        return
    end
    
    if (avatarVivenBridge.GetIsMine() == true) then
        Debug.Log("[BasicAvatarManager] OnAiSpeakDetected: " .. id .. ", " .. uuid .. ", " .. index .. ", " .. textKr .. textEn .. ", " .. emotion .. ", " .. eventName)
        
        -- 가장 최근에 발화를 시작한 플레이어를 쳐다봄
        local recentSpeakingPlayer = avatarSpeechController.GetRecentSpeakStartPlayer()
        if (recentSpeakingPlayer ~= "") then
            avatarAnimationController.StartLookAtPlayer_Request(recentSpeakingPlayer, -1)
        end

        -- 말하기 애니메이션 설정
        local randomSpeakIndex = avatarAnimationController.SetEmotionSpeakIndex(emotion)

        SendRPC_All("RegisterSpeechInformation", uuid, index, textKr, textEn, emotion, eventName, randomSpeakIndex)
    else
        Debug.Log("[BasicAvatarManager] OnAiSpeakDetected: 다른 사용자의 AI 발화입니다. id=" .. id .. ", target id=" .. avatarVivenBridge.GetAiId() .. ")")
    end
end

-- AI의 발화 정보 등록
---@param uuid string 문단의 UUID
---@param index number 문장 인덱스
---@param textKr string 한국어 텍스트
---@param textEn string 영어 텍스트
---@param emotion string 감정
---@param eventName string 이벤트 이름
---@param speakIndex number 발화 애니메이션 인덱스
function RegisterSpeechInformation(uuid, index, textKr, textEn, emotion, eventName, speakIndex)
    Debug.Log("[BasicAvatarManager] SetSpeechText: " .. uuid .. ", " .. index .. ", " .. textKr .. ", " .. emotion .. ", " .. eventName .. ", " .. speakIndex)
    
    -- 문단이 바뀌었으면 초기화
    if speechInfo.uuid ~= uuid then
        speechInfo.uuid = uuid
        speechInfo.sentences = {}
    end

    speechInfo.sentences[index] = {
        textKr = textKr,
        textEn = textEn,
        emotion = emotion,
        speakAnimationIndex = speakIndex,
        eventName = eventName
    }
    
    -- 등록된 UUID 목록에 추가
    table.insert(registeredUuids, uuid)
end

function ResetSpeechInformation()
    speechInfo.uuid = ""
    speechInfo.sentences = {}
    registeredUuids = {}
end

-- AI의 발화 문장이 시작되었을때 호출되는 함수
---@param uuid string 문단의 UUID
---@param index number 문장 인덱스
function OnAiSpeakUtteranceStarted(id, uuid, index)
    if id ~= avatarVivenBridge.GetAiId() then
        Debug.Log("[BasicAvatarManager] OnAiSpeakUtteranceStarted: 다른 AI의 발화입니다. id=" .. id .. ", target id=" .. avatarVivenBridge.GetAiId() .. ")")
        return
    end

    self:StartCoroutine(util.cs_generator(function ()
        -- 약간의 딜레이를 준 후 실행 (자막이 바로 바뀌지 않는 문제 해결용)
        coroutine.yield(WaitForSeconds(0.1))
        if speechInfo.uuid ~= uuid or speechInfo.sentences[index] == nil then
            Debug.Log("[BasicAvatarManager] OnAiSpeakUtteranceStarted: 등록되지 않은 문장입니다. uuid=" .. uuid .. ", index=" .. index)
            return
        end

        Debug.Log("[BasicAvatarManager] OnAiSpeakUtteranceStarted: " .. uuid .. ", " .. index)
        local sentenceInfo = speechInfo.sentences[index]

        -- 발화 텍스트, 애니메이션, 감정 설정
        avatarUiManager.SetSpeechSub(sentenceInfo.textKr, sentenceInfo.textEn)
        avatarBlendShapeController.SetEmotion(sentenceInfo.emotion)
        avatarAnimationController.CrossFade(sentenceInfo.speakAnimationIndex, 0.1)
        if (avatarVivenBridge.GetIsMine()) then
            avatarAnimationController.IsSpeaking = true
            RequestAiStateChange_Host(aiState.SPEAK)
        end
    end))
end

function OnAiSpeakUtteranceCompleted(id, uuid, index)
    if id ~= avatarVivenBridge.GetAiId() then
        return
    end
    Debug.Log("[BasicAvatarManager] OnAiSpeakUtteranceCompleted: " .. uuid .. ", " .. index)

    -- 자막 초기화
    avatarUiManager.SetSpeechSub("", "")
    -- 감정 초기화
    avatarBlendShapeController.SetEmotion("")
    -- 말하기 애니메이션 초기화
    avatarAnimationController.IsSpeaking = false

    -- 만약 이 문장이 마지막 문장이었다면 이벤트 호출
    if speechInfo.uuid == uuid and speechInfo.sentences[index] ~= nil then
        local sentenceCount = #speechInfo.sentences
        if index == sentenceCount then
            event:invoke("Avatar_AiSpeechCompleted", avatarVivenBridge.GetAiId(), uuid, index)
            -- 플레이어 쳐다보는 것 멈춤
            avatarAnimationController.StopLookAtTarget()

            -- 문장에 이벤트 이름이 설정되어 있으면 이벤트 호출
            if speechInfo.sentences[index].eventName ~= "" then
                event:invoke("AI_EventReceived", speechInfo.sentences[index].eventName)
            end
            
            if avatarVivenBridge.GetIsMine() then
                RequestAiStateChange_Host(aiState.DEFAULT)
            end
        end
    end
end

--#endregion

--#region AI 상태 관리

function RequestAiStateChange_Host(newState)
    Debug.Log("[BasicAvatarManager] RequestAiStateChange_Host: " .. currentAIState .. " -> " .. newState)

     -- 이전 상태 정리
    if currentAIState == aiState.DEFAULT then
    elseif currentAIState == aiState.LISTEN then
    elseif currentAIState == aiState.THINK then
        SetThinkState_Host(false)
    elseif currentAIState == aiState.MOVE then
    elseif currentAIState == aiState.SPEAK then
    end
    
    if (newState == aiState.DEFAULT) then
    elseif (newState == aiState.LISTEN) then
        SetThinkState_Host(false)
    elseif (newState == aiState.THINK) then
        SetThinkState_Host(true)
        
    elseif (newState == aiState.MOVE) then
    elseif (newState == aiState.SPEAK) then
    end
    
    avatarUiManager.OnAiStateChanged_Host(newState)
    currentAIState = newState
end

-- 생각 상태 설정 요청
---@param isThinking boolean 생각 상태 여부
function SetThinkState_Host(isThinking)
    -- 생각 상태 설정
    avatarAnimationController.IsThinking = isThinking
    
if (isThinking) then
        -- 생각하는 표정 재생
        avatarBlendShapeController.SetEmotion_Request("")
        avatarBlendShapeController.PlayBlendShape_Request("Think", 1.0)
    else
        -- 생각하는 표정 제거
        avatarBlendShapeController.PlayBlendShape_Request("Think", 0.0)    
    end 
end

function ResetAvatarTransform()
    self.transform.position = StartPointObject.transform.position
    self.transform.rotation = StartPointObject.transform.rotation
end

function OnAiTokenExceed(aiId)
    if aiId ~= avatarVivenBridge.GetAiId() then
        return
    end

    Debug.Log("[BasicAvatarManager] OnAiTokenExceed: AI 토큰 한도 초과로 초기화 진행. aiId=" .. aiId)
    avatarMoveController.StopMove_Host()
    avatarAnimationController.SetDefaultRotation(StartPointObject.transform.rotation)
    ResetAvatarTransform()
    StopAudio()
end

function OnAiSessionInit(modelName, isHost)
    event:invoke("Avatar_AiSessionInitialized", modelName, isHost)

    Debug.Log("[BasicAvatarManager] OnAiSessionInit: " .. modelName .. ", isHost=" .. tostring(isHost))

    if modelName ~= aiConnector.modelName then
        return
    end

    isAiSessionInit = true
    
    -- AI 세션 초기화 시점에 이미 영역에 들어와 있었다면 SetSpeakState 설정
    event:invoke("Avatar_CheckPlayerInArea")
    
    SendRPC_All("OnAiSessionInit_All", modelName, isHost)
    if isHost then
        SendRPC_All("StartAiAudio")
    end
end

function OnAiSessionInit_All(modelName, isHost)
    event:invoke("AiSessionInitialized_All", modelName, isHost)
end

function StartAiAudio()
    aiConnector:StartAiAudio()
end

function OnAiHostChanged(isHost)
    Debug.Log("[BasicAvatarManager] OnAiHostChanged: isHost=" .. tostring(isHost))
    event:invoke("Avatar_AiHostChanged", isHost)
end

function OnClientInitialized(isInit)
    if isInit then
        Debug.Log("[BasicAvatarManager] OnClientInitialized: AI Client initialized.")
        StartAiAudio()
        if (avatarVivenBridge.GetIsMine() == false) then
            self:StartCoroutine(util.cs_generator(function ()
                coroutine.yield(WaitUntil(function ()
                    return avatarVivenBridge.GetIsClientInit()
                end))
                Debug.Log("[BasicAvatarManager] AI Session initialized. Checking player in area...")
                event:invoke("Avatar_CheckPlayerInArea")
                SendRPC_Host("RequestAiSessionState", Player.Mine.UserID)
            end))
        end
    else
        Debug.Log("[BasicAvatarManager] OnClientInitialized: AI Client failed to initialize.")
    end
end

function RequestAiSessionState(userId)
    SyncView:SendTargetRPC("ReceiveAiSessionState", { userId }, isAiSessionInit)
end

function ReceiveAiSessionState(isAiSessionInit)
    event:invoke("AiSessionInitialized_All", aiConnector.modelName, isAiSessionInit)
end

function OnDisconnect()
    isAiSessionInit = false
end


--#endregion

--#region 현재 볼륨에 따른 입 모양과 말하는 애니메이션 제어

-- 입 모양을 볼륨에 따라 설정하는 함수
function PlayMouthByWeight()

    StopMouth()

    mouthMoveRoutine = self:StartCoroutine(util.cs_generator(function ()
    local currentViseme = VIS_A
    local visemeTimer = 0.0
    local visemeDuration = 0.1  -- viseme 변경 주기 (초)
        while (true) do
            local target = defaultMouthOpenCalculator:GetMouthWeight()

            if (target < 0.01 ) then
               currentViseme = VIS_A
            visemeTimer = 0.0

            avatarBlendShapeController.PlayBlendShape("A", 0)
            avatarBlendShapeController.PlayBlendShape("E", 0)
            avatarBlendShapeController.PlayBlendShape("O", 0)
                
            coroutine.yield(nil)
            else
                -- 말하는 중: viseme 타이머 진행
                visemeTimer = visemeTimer + Time.deltaTime
                if visemeTimer >= visemeDuration then
                    visemeTimer = 0.0
                    -- 0.08 ~ 0.18 사이에서 랜덤하게 유지 시간
                    visemeDuration = Random.Range(0.08, 0.18)
                    currentViseme = PickNextViseme(currentViseme)
                end

                local a, e, o = CalcVisemeWeights(currentViseme, target)

                Debug.Log(string.format("PlayMouthByWeight: target=%.2f, viseme=%d, a=%.2f, e=%.2f, o=%.2f", target, currentViseme, a, e, o))

                avatarBlendShapeController.PlayBlendShape("A", a)
                avatarBlendShapeController.PlayBlendShape("E", e)
                avatarBlendShapeController.PlayBlendShape("O", o)

            coroutine.yield(nil)
            end
        end
    end))
end

-- 입 모양 정지 함수
function StopMouth()
    if (mouthMoveRoutine ~= nil) then
        self:StopCoroutine(mouthMoveRoutine)
    end
end

-- viseme 가중치 계산 함수
---@param mode number viseme 모드 (VIS_A, VIS_E, VIS_O)
---@param baseWeight number 기본 입 모양 가중치 (0.0 ~ 1.0)
---@return number aWeight, number eWeight, number oWeight
function CalcVisemeWeights(mode, baseWeight)
    -- baseWeight = GetMouthWeight() 그대로 사용 (0~1)
    if baseWeight <= 0 then
        return 0, 0, 0
    end

    -- 기본 비율은 적당히 감으로 잡은 값. 필요하면 나중에 조정.
    if mode == VIS_A then
        -- A 위주, E/O 살짝
        return baseWeight * 1.0, baseWeight * 0.35, baseWeight * 0.20
    elseif mode == VIS_E then
        -- E 위주, A/O 보조
        return baseWeight * 0.50, baseWeight * 1.0, baseWeight * 0.30
    elseif mode == VIS_O then
        -- O 위주, A/E 보조
        return baseWeight * 0.40, baseWeight * 0.25, baseWeight * 1.0
    else
        -- fallback: 그냥 A만
        return baseWeight, 0, 0
    end
end

-- 랜덤으로 다음 viseme 선택 (직전이랑 계속 같지 않게)
---@param prev number 직전 viseme 모드 (VIS_A, VIS_E, VIS_O)
---@return number nextVisemeMode
function PickNextViseme(prev)
    local r = math.random(0, 2)  -- 0,1,2 중 하나
    local m = r + 1               -- 1~3 → VIS_A/E/O

    if m == prev then
        -- 같은게 나왔으면 하나만 다시 굴려서 바꿔줄 수도 있음
        m = ((m) % 3) + 1
    end
    return m
end

function SetMouthSensitivity(val)
    defaultMouthOpenCalculator.sensitivity = val
end

--#endregion

--#region 동기화 함수

function onRoomUserJoined(userData)
    -- 방에 들어온 유저에게 speechInfo 동기화
    if (avatarVivenBridge.GetIsMine()) then
        for _, uuid in ipairs(registeredUuids) do
            for index, sentenceInfo in pairs(speechInfo.sentences) do
                SyncView:SendTargetRPC("RegisterSpeechInformation", {userData.userID} , avatarVivenBridge.GetAiId(), uuid, index, sentenceInfo.textKr, sentenceInfo.textEn, sentenceInfo.emotion, sentenceInfo.eventName, sentenceInfo.speakAnimationIndex)
            end
        end
    end
end

function sendSyncUpdate()
    local syncTable = {}
    syncTable[1] = currentAIState
    return syncTable
end

function receiveSyncUpdate(syncTable)
    currentAIState = syncTable[1]
end

function onSyncViewInitialized()
    if (avatarVivenBridge.GetIsMine() == false) then
        -- 내가 첫 번째로 들어온 유저가 아닌 경우
        self:StartCoroutine(util.cs_generator(function ()
            -- 동기화 정보가 올 때까지 대기
            coroutine.yield(WaitUntil(function ()
                return currentAIState >= 0
            end))
            avatarUiManager.OnAiStateChanged(currentAIState)
        end))
        if (currentAIState == aiState.THINK) then
            avatarBlendShapeController.PlayBlendShape("Think", 1.0)
        end
    else
        RequestAiStateChange_Host(aiState.DEFAULT)
        -- 초기 위치 리셋
        self.transform.position = StartPointObject.transform.position
        self.transform.rotation = StartPointObject.transform.rotation
    end
end

function SendRPC_Host(funcName, ...)
    local param = { ... }
    SyncView:SendTargetRPC(funcName, { avatarVivenBridge.GetControlUser() }, param)
end

function SendRPC_All(funcName, ...)
    local param = { ... }
    SyncView:SendRPC(funcName, RPCSendOption.All, param)
end

function SendRPC_Others(funcName, ...)
    local param = { ... }
    SyncView:SendRPC(funcName, RPCSendOption.Others, param)
end

--#endregion