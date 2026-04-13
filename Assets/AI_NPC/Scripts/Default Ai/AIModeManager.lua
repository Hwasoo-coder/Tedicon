-- AI의 소유권 및 모드를 관리

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

AiAvatarObject = checkInject(AiAvatarObject) -- {Multi AI}

MoveTargetsObject = checkInject(MoveTargetsObject) -- {이동 타겟들 오브젝트}

_INJECTED_ORDER = 0
--endregion

local util = require 'xlua.util'

---@type EventBus
local event

---@type AvatarVivenBridge
local multiAiVivenBridge

----@type AiConnector
local multiAiConnector

---@type Global_AiMode
local aiMode = 
{
    Multi = 0,
    Private = 1
}

Global_AiMode = aiMode
self.LuaEnv.Global.Global_AiMode = aiMode

---@type BasicAvatarManager
local avatarManager

local networkVoiceBridge

local isFindingHost = false
local hostResultCount = 0

local targetVObjects

function awake()
    ---@type AIModeManager
    Global_AiModeManager = self:GetLuaComponent("AIModeManager")
    self.LuaEnv.Global.Global_AiModeManager = Global_AiModeManager

    networkVoiceBridge = self:GetComponent("NetworkVoiceBridge")
    avatarManager = AiAvatarObject:GetLuaComponent("BasicAvatarManager")
    multiAiConnector = AiAvatarObject:GetComponent("AiConnector")

    -- 반드시 인증받은 클라이언트가 host가 되어야 하는 VObject 리스트
    targetVObjects = {
        AiAvatarObject:GetComponent(typeof(VObject)),
        self:GetComponent(typeof(VObject)),
        MoveTargetsObject:GetComponent(typeof(VObject))
    }
end

function start()
    event = Util.EventBus

    event:registerEvent("Avatar_ClientTranscriptReceived", OnClientTranscriptReceived)
end

function onSyncViewInitialized()
    awake()
    -- 서버 연결
    networkVoiceBridge:Connect()
end

function onRoomLeave()
    networkVoiceBridge:Disconnect()
end

function OnClientTranscriptReceived(textKr, textEn)
    -- 채팅 메시지 생성
    local chatText = "KR: " .. textKr .. "\nEN: " .. textEn
    networkVoiceBridge:SendChatText(chatText)
end

--#regidon 동기화 관련 함수

-- 시나리오 1. 인증받은 유저가 소유권 획득
-- IsClientInitialized=true, IsHost=false
-- RequestSessionHostChange() 호출 ✓
-- IsHost=true 로 변경
-- OnDiscussionSessionInit(isHost=true) 호출

-- 시나리오 2: 인증받지 않은 유저(A)가 소유권 획득
-- IsClientInitialized=false, IsHost=false
-- 나를 제외한 모든 유저에게 RequestClientInitInfo() 호출
-- 인증된 클라이언트(B)가 응답
-- A가 B에게 TransferOwnership 하라고 요청
-- B가 RequestControlUserIsMine 호출
-- B가 onOwnershipChanged(isMine=true) 받음
-- IsClientInitialized=true, IsHost=false
-- RequestSessionHostChange() 호출 ✓
-- IsHost=true 로 변경
-- OnDiscussionSessionInit(isHost=true) 호출


---@param isMine boolean 소유권이 자신에게 넘어왔는지 여부
function onOwnershipChanged(isMine)
    if (isMine) then
        if (networkVoiceBridge.IsClientInitialized and not networkVoiceBridge.IsHost) then
            Debug.Log("소유권이 나로 바뀌었는데, 나는 인증된 클라이언트이며 아직 나로 ai의 호스트가 변경되지 않았음")
            -- 소유권이 나로 바뀌었는데, 나는 인증된 클라이언트이며 아직 나로 ai의 호스트가 변경되지 않은 경우. 나로 host 변경을 요청한다.
            networkVoiceBridge:RequestSessionHostChange()
        elseif (not networkVoiceBridge.IsClientInitialized) then
            Debug.Log("소유권이 나로 바뀌었는데, 나는 아직 인증된 클라이언트가 아님")
            -- 소유권이 나로 바뀌었는데, 나는 아직 인증된 클라이언트가 아닌 경우. 인증이 완료된 클라이언트를 찾아서 넘겨준다.

            Debug.Log("소유권 양도 가능한 대상 탐색 시작")
            isFindingHost = true
            hostResultCount = 0
             -- 나를 포함한 모든 유저에게 인증된 클라이언트 여부를 묻는다.
            SendRPC_All("RequestClientInitInfo", Player.Mine.UserID)
        end
    end 
end

function RequestClientInitInfo(id)
    Debug.Log("인증된 클라이언트 여부 정보를 전달: " .. tostring(networkVoiceBridge.IsClientInitialized))
    SyncView:SendTargetRPC("ReceiveClientInitInfo", {id}, Player.Mine.UserID, networkVoiceBridge.IsClientInitialized)
end

function ReceiveClientInitInfo(clientId, isInitialized)
    if not isFindingHost then return end

    if isInitialized then
        isFindingHost = false

        -- 인증된 클라이언트가 발견됨. 소유권을 넘겨준다.
        Debug.Log("소유권 양도 대상 발견: " .. clientId)
        SyncView:SendTargetRPC("TransferOwnership", {clientId}, nil)
    end
    hostResultCount = hostResultCount + 1
    if hostResultCount >= Room.CurrentRoomPlayers.Count then
        -- 모든 응답을 받았으나 인증된 클라이언트가 없음.
        Debug.Log("소유권 양도 대상이 없음")
        isFindingHost = false

        multiAiConnector:OnAiSessionResultReceived(false, false)
        
        -- 위치 리셋
        avatarManager.ResetAvatarTransform()
    end
end

-- 소유권을 나에게로 요청. 요청되면 onOwnershipChanged에 의해서 세션 변경이 시도된다.
function TransferOwnership()
    Debug.Log("소유권 양도 요청 수신")
    for _, vObject in ipairs(targetVObjects) do
        if not vObject.IsMine then
            vObject:RequestControlUserIsMine()
        end
    end
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