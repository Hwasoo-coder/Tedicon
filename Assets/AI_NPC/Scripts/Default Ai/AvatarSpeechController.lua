-- 아바타의 말하기 관련 컨트롤러
---@class AvatarSpeechController
---@field IsValidListening boolean AI가 유효한 플레이어의 음성을 듣고 있는지 여부
---@field PlayerSpeakDetected fun(userID:string, isSpeaking:boolean) 플레이어의 말하기 감지 함수
---@field PlayerSpeakDetected_Host fun(userID:string, isSpeaking:boolean) 호스트용
---@field GetRecentSpeakStartPlayer fun():string 가장 최근에 말한 플레이어의 사용자 ID 반환 함수
---@field GetRecentSpeakEndPlayer fun():string 가장 최근에 말하기를 멈춘 플레이어의 사용자 ID 반환 함수

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
-- 아바타 루트 오브젝트
AvatarRootObject = checkInject(AvatarRootObject) --  {NPC}

_INJECTED_ORDER = 0
--endregion

local util = require 'xlua.util'

---@type EventBus
local event

---@type AvatarVivenBridge
local avatarVivenBridge

local speakingPlayer = {}

-- AI가 유효한 플레이어의 음성을 듣고 있는지 여부
IsValidListening = false

function start()
    event = Util.EventBus

    avatarVivenBridge = AvatarRootObject:GetLuaComponent("AvatarVivenBridge")
end

function onUserLeaveRoom(userData)
    if (avatarVivenBridge.GetIsMine() == false) then
        return
    end
    if (speakingPlayer[userData.userID] ~= nil) then
        speakingPlayer[userData.userID] = nil
    end
end

--#region Player Speech

function PlayerSpeakDetected(userID, isSpeaking)
    SendRPC_Host("PlayerSpeakDetected_Host", userID, isSpeaking)
end

function PlayerSpeakDetected_Host(userID, isSpeaking)    
    -- userID가 speakingPlayer에 없으면 초기화
    if speakingPlayer[userID] == nil then
        speakingPlayer[userID] = {
            IsSpeaking = false,
            LastTalkStartTime = 0,
            LastTalkEndTime = 0
        }
    end
    
    if (isSpeaking) then
        speakingPlayer[userID].LastTalkStartTime = Time.time
        speakingPlayer[userID].IsSpeaking = true
    else
        speakingPlayer[userID].IsSpeaking = false
        speakingPlayer[userID].LastTalkEndTime = Time.time
        for _ in pairs(speakingPlayer) do
            if speakingPlayer[_].IsSpeaking == true then
                return  -- 아직 말하는 플레이어가 있음
            end
        end

        -- 아무도 말하지 않음
        if IsValidListening then
            event:invoke("Avatar_PlayerStopSpeak")
            IsValidListening = false
        end
    end
end

-- 가장 최근에 말하기 시작한 플레이어의 사용자 ID를 반환하는 함수
function GetRecentSpeakStartPlayer()
    local time = -1
    local recentPlayer = ""
    for userID in pairs(speakingPlayer) do
        if speakingPlayer[userID]["LastTalkStartTime"] > time then
            time = speakingPlayer[userID]["LastTalkStartTime"]
            recentPlayer = userID
        end
    end
    return recentPlayer
end

-- 가장 최근에 말하기 끝낸 플레이어의 사용자 ID를 반환하는 함수
function GetRecentSpeakEndPlayer()
    local time = -1
    local recentPlayer = ""
    for userID in pairs(speakingPlayer) do
        if speakingPlayer[userID]["LastTalkEndTime"] > time then
            time = speakingPlayer[userID]["LastTalkEndTime"]
            recentPlayer = userID
        end
    end
    return recentPlayer
end

--#endregion



function sendSyncUpdate()
    local syncTable = {}
    syncTable[1] = IsValidListening

    return syncTable
end

function receiveSyncUpdate(syncTable)
    if (syncTable == nil) then return end

    IsValidListening = syncTable[1]
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