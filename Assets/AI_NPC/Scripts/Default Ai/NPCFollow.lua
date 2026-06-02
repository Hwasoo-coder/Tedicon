-- NPCFollow.lua
-- NPC가 플레이어를 추적하는 기본 로직

local util = require 'xlua.util'

-- 하드코딩된 설정값 (AvatarMoveController에서 처리하므로 여기서는 거리만 사용)
stopDistance = 2.0 -- 플레이어와 유지할 최소 거리

---@type AvatarMoveController
local avatarMoveController

---@type AvatarVivenBridge
local avatarVivenBridge

function start()
    avatarMoveController = self:GetLuaComponentInChildren("AvatarMoveController")
    avatarVivenBridge = self:GetLuaComponent("AvatarVivenBridge")
    Debug.Log("[NPCFollow] 스크립트 시작.")

    -- 시작 시 NPC가 NavMesh 영역 내에 정상적으로 위치하도록 워프 명령 호출
    if avatarVivenBridge ~= nil and avatarVivenBridge.GetIsMine() and avatarMoveController ~= nil then
        avatarMoveController.WarpToNavMesh_Host()
    end
end

function update()
    -- 0. 내가 호스트(소유자)일 때만 이동 로직을 수행 (네트워크 동기화)
    if avatarVivenBridge == nil or not avatarVivenBridge.GetIsMine() then return end

    -- 1. 내 플레이어가 유효한지 먼저 확인 (오류 방지)
    if Player.Mine == nil or Player.Mine.CharacterController == nil then return end

    -- 2. 위치 정보를 가져옵니다.
    if avatarMoveController == nil then
        Debug.LogWarning("[NPCFollow] AvatarMoveController를 찾을 수 없습니다.")
        return
    end

    local playerPos = Player.Mine.CharacterController.transform.position
    local npcPos = self.transform.position

    -- 3. NPC와 플레이어 사이의 거리를 계산합니다.
    local distance = (playerPos - npcPos).magnitude

    -- 4. 정지 거리보다 멀리 있을 때만 이동합니다.
    if distance > stopDistance then
        avatarMoveController.MoveToTargetPos_Host(playerPos.x, playerPos.y, playerPos.z)
        -- Debug.Log("[NPCFollow] 이동 중... 거리: " .. distance)
    else
        avatarMoveController.StopMove_Host()
    end
end