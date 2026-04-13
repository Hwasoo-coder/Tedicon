-- 아바타의 충돌 이벤트 감지기

---@type EventBus
local event

---@type AvatarVivenBridge
local avatarVivenBridge

local util = require 'xlua.util'

---@type table
-- 영역에 들어온 유저 목록
local areaTriggeredUsers = {}

-- OnCheckPlayerInArea용 변수
local isCheckingPlayerInArea = false
local checkPlayerRoutine

function start()
    event = Util.EventBus
    avatarVivenBridge = self:GetLuaComponentInParent("AvatarVivenBridge")
    
    -- AI 세션 초기화 시 영역 내 플레이어 확인 이벤트 등록
    event:registerEvent("Avatar_CheckPlayerInArea", OnCheckPlayerInArea)
end

--#region 충돌 감지 이벤트

-- 아바타에 붙어있는 콜라이더의 OnTriggerEnter 이벤트
---@param col Collider 충돌한 콜라이더
function onTriggerEnter(col)
    event:invoke("Avatar_TriggerEnter", col)
end

-- 아바타에 붙어있는 콜라이더의 OnTriggerExit 이벤트
---@param col Collider 충돌이 끝난 콜라이더
function onTriggerExit(col)
    event:invoke("Avatar_TriggerExit", col)
end

-- 아바타에 붙어있는 콜라이더의 OnCollisionEnter 이벤트
---@param col Collision 충돌한 콜라이더
function onCollisionEnter(col)
    event:invoke("Avatar_CollisionEnter", col)
end

-- 아바타에 붙어있는 콜라이더의 OnCollisionExit 이벤트
---@param col Collision 충돌이 끝난 콜라이더
function onCollisionExit(col)
    event:invoke("Avatar_CollisionExit", col)
end

-- 플레이어가 아바타의 상호작용 범위에 들어왔을 때 호출되는 함수
---@param userId string 플레이어의 사용자 ID
function onPlayerEnter(userId)
    event:invoke("Avatar_PlayerEnter", userId)

    if (avatarVivenBridge.GetIsMine() == true) then
        HandlePlayerEnterArea_Host(userId)
    end
end

-- 플레이어가 아바타의 상호작용 범위에 머물러 있을 때 호출되는 함수
---@param userId string 플레이어의 사용자 ID
function onPlayerStay(userId)
    if not isCheckingPlayerInArea then return end
    
    -- 체크 중이고 내 아이디면 PlayerEnter 이벤트 발생
    if userId == Player.Mine.UserID then
        event:invoke("Avatar_PlayerEnter", userId)
        Debug.Log("AvatarCollisionDetector - onPlayerStay: 플레이어가 영역에 머무르고 있음 - userId: " .. userId)
        isCheckingPlayerInArea = false  -- 한 번만 호출되도록
    end
end

-- 플레이어가 아바타의 상호작용 범위에서 나갔을 때 호출되는 함수
---@param userId string 플레이어의 사용자 ID
function onPlayerExit(userId)
    event:invoke("Avatar_PlayerExit", userId)

    if avatarVivenBridge.GetIsMine() == true then
        HandlePlayerExitArea_Host(userId)
    end
end

--#endregion

-- 유저가 트리거 존에 들어왔을 때 내부 리스트에 등록
---@param userId string 플레이어의 사용자 ID
function HandlePlayerEnterArea_Host(userId)
    print("[AvatarCollision] HandlePlayerEnterArea_Host 호출 - userId: " .. tostring(userId))
    print("[AvatarCollision] 현재 areaTriggeredUsers 수: " .. #areaTriggeredUsers)
    
    local isNewUser = true
    for _, id in ipairs(areaTriggeredUsers) do
        print("[AvatarCollision] 체크 중인 유저: " .. tostring(id))
        if id == userId then
            -- 이미 영역에 들어와있는 유저인 경우 무시
            print("[AvatarCollision] 이미 등록된 유저 - 무시")
            isNewUser = false
            return
        end
    end

    if (isNewUser) then
        -- 새로운 유저가 영역에 들어옴
        print("[AvatarCollision] 새로운 유저 등록 - SendRPC_All 호출")
        SendRPC_All("RegisterPlayerEnterArea", userId)
    end
end

function HandlePlayerExitArea_Host(userId)
    for index, id in ipairs(areaTriggeredUsers) do
        if id == userId then
            SendRPC_All("RemovePlayerEnterArea", userId)
            return
        end
    end
end

-- 유저가 트리거 존에 들어왔을 때 내부 리스트에 등록
-- 최초 진입 시 이벤트 처리
function RegisterPlayerEnterArea(userId)
    table.insert(areaTriggeredUsers, userId)

    if (#areaTriggeredUsers > 0) then
        -- 영역에 진입한 플레이어가 하나라도 있을 때
        event:invoke("Avatar_AreaHasPlayerEnter")
    end
end

function RemovePlayerEnterArea(userId)
    for index, id in ipairs(areaTriggeredUsers) do
        if id == userId then
            table.remove(areaTriggeredUsers, index)
            break
        end
    end

    if (#areaTriggeredUsers == 0) then
        -- 마지막 유저가 영역에서 나갔을 때 처리
        event:invoke("Avatar_AreaHasNoPlayer")
    end
end

-- 유저가 방에 들어왔을때 호출되는 함수
function onRoomUserJoined(userData)
    if (avatarVivenBridge.GetIsMine() == false) then
        return
    end

    -- areaTriggeredUsers 동기화
    for _, id in ipairs(areaTriggeredUsers) do
        SyncView:SendTargetRPC("RegisterPlayerEnterArea", {userData.userId} ,id)
    end
end

-- 유저가 방에서 나갔을때 호출되는 함수
function onUserLeaveRoom(userData)
    if (avatarVivenBridge.GetIsMine() == false) then
        return
    end

    -- 유저가 방을 나갔을때 아바타 영역에서 나간것으로 처리
    HandlePlayerExitArea_Host(userData.userId)
end

-- AI 세션 초기화 시 현재 영역에 플레이어가 있는지 확인
function OnCheckPlayerInArea()    
    Debug.Log("AvatarCollisionDetector - OnCheckPlayerInArea called")
    -- 이전 루틴이 있으면 중지
    if checkPlayerRoutine ~= nil then
        self:StopCoroutine(checkPlayerRoutine)
        checkPlayerRoutine = nil
    end
    
    isCheckingPlayerInArea = true
    
    checkPlayerRoutine = self:StartCoroutine(util.cs_generator(function ()
        -- 0.5초 동안 onPlayerStay로 감지
        coroutine.yield(WaitForSeconds(0.5))
        isCheckingPlayerInArea = false
    end))
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

