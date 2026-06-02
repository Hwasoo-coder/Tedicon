-- NavMeshAgent와 Animator 컴포넌트를 사용하여 아바타의 이동과 회전을 제어합니다.

---@class AvatarMoveController
---@field public IsWalking boolean 현재 위치 이동이 일어나고 있는지 여부
---@field public IsTurning boolean 현재 회전이 일어나고 있는지 여부
---@field public TurnValue number 회전 값 (-180 ~ 180)
---@field MoveToTargetPos fun(targetPosition:Vector3) 타겟 위치로 이동. NavMeshAgent 필요. Host에서 호출됩니다.
---@field MoveToTargetPos_Host fun(targetX:number, targetY:number, targetZ:number) 타겟 위치로 이동. NavMeshAgent 필요
---@field MoveToTargetObject fun(targetObjectName:string) 타겟 오브젝트로 이동. NavMeshAgent 필요. Host에서 호출됩니다.
---@field MoveToTargetObjectContinuous fun(targetObjectName:string, maxDistance:number) 타
---@field MoveByOffset fun(offset:Vector3) 아바타 캐릭터를 기준으로 파라미터만큼 이동. Host에서 호출됩니다.
---@field StopMove_Request fun() 이동 중지. Host에서 호출됩니다.
---@field StopMove_Host fun() 이동 중지
---@field WarpToNavMesh_Host fun() NPC를 가장 가까운 NavMesh 위치로 강제 이동
---@field SetNavAgentEnabled fun(enabled:boolean) NavMeshAgent 활성화/비활성화
---@

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
AvatarRootObject = checkInject(AvatarRootObject) -- 
_INJECTED_ORDER = 0
--endregion

local util = require 'xlua.util'

local avatarVivenBridge = AvatarRootObject:GetLuaComponent("AvatarVivenBridge")

---@type NavMeshAgent
local navAgent

---@type coroutine
-- 이동 루틴
local moveRoutine 

local moveTargetPos

local avatarTransform

function awake()
    navAgent = self:GetComponentInParent(typeof(NavMeshAgent))
end

function start()
    avatarTransform = AvatarRootObject.transform
end

function update()
    if (moveTargetPos == nil) then return end

    -- 이동하는 방향을 바라보도록 회전 처리 (실제로 이동 중일 때만)
    if navAgent.velocity.magnitude > 0.1 then
        local targetRot = Quaternion.LookRotation(navAgent.velocity, Vector3.up)
        avatarTransform.rotation =
            Quaternion.Slerp(avatarTransform.rotation, targetRot, 6.0 * Time.deltaTime)
    end
end
    
--#region 이동 

--- 타겟 위치로 이동. NavMeshAgent 필요. Host에서 호출됩니다.
---@param targetPosition Vector3 타겟 위치 (월드 좌표)
function MoveToTargetPos(targetPosition)
   SendRPC_Host("MoveToTargetPos_Host", targetPosition.x, targetPosition.y, targetPosition.z)
end

-- 타겟 위치로 이동. NavMeshAgent 필요
---@param targetX number 타겟 X 좌표
---@param targetY number 타겟 Y 좌표
---@param targetZ number 타겟 Z 좌표
function MoveToTargetPos_Host(targetX, targetY, targetZ)
    if (navAgent ~= nil and navAgent.enabled and navAgent.isOnNavMesh) then 
        moveTargetPos = Vector3(targetX, targetY, targetZ)
        navAgent:SetDestination(moveTargetPos)
    else
        if navAgent ~= nil and navAgent.enabled and not navAgent.isOnNavMesh then
            -- NPC가 NavMesh 위에 없을 때 로그 출력
            Debug.LogWarning("[AvatarMoveController] NPC가 NavMesh 영역 밖에 있습니다! 현재 위치: " .. tostring(avatarTransform.position))
        end
    end
end

-- 타겟 오브젝트로 이동. NavMeshAgent 필요. Host에서 호출됩니다.
---@param targetObjectName string 타겟 오브젝트 이름. 해당 타겟은 inject된 오브젝트이어야 합니다.
function MoveToTargetObject(targetObjectName)
   SendRPC_Host("MoveToTargetObject_Host", targetObjectName)
end

-- 타겟 오브젝트로 이동. NavMeshAgent 필요
---@param targetObjectName string 타겟 오브젝트 이름. 해당 타겟은 inject된 오브젝트이어야 합니다.
function MoveToTargetObject_Host(targetObjectName)
    if (navAgent ~= nil and navAgent.enabled and navAgent.isOnNavMesh) then
        moveTargetPos = targetObjectName.transform.position
        navAgent:SetDestination(moveTargetPos)
    end
end

-- 타겟 오브젝트 위치로 이동. StopMove 호출 전까지 이동 지속. Host에서 호출됩니다.
---@param targetObjectName string 타겟 오브젝트 이름. 해당 타겟은 inject된 오브젝트이어야 합니다.
---@param maxDistance number 최대 거리
function MoveToTargetObjectContinuous(targetObjectName, maxDistance)
   SendRPC_Host("MoveToTargetObjectContinuous_Host", targetObjectName, maxDistance)
end

-- 타겟 오브젝트 위치로 이동. StopMove 호출 전까지 이동 지속
---@param targetObjectName string 타겟 오브젝트 이름. 해당 타겟은 inject된 오브젝트이어야 합니다.
---@param maxDistance number 최대 거리
function MoveToTargetObjectContinuous_Host(targetObjectName, maxDistance)
    if moveRoutine ~= nil then
        self:StopCoroutine(moveRoutine)
        moveRoutine = nil
    end
    moveTargetPos = targetObjectName.transform.position

    if (navAgent ~= nil) then
        moveRoutine = self:StartCoroutine(util.cs_generator(function () 
        local isArriveFirst = true
            while (true) do
                if (Vector3.Distance(avatarTransform.position, targetObjectName.transform.position) < maxDistance) then
                    -- 도착 지점에 도달 
                    if (not isArriveFirst) then
                        -- 도착한 직후이면 타겟을 바라보게 함
                        isArriveFirst = true
                        avatarTransform:DoLookAt(targetObjectName.transform.position, 1)
                    end
                    navAgent:ResetPath()
                else
                    if (isArriveFirst) then
                        -- 이동 시작 시 타겟을 바라보게 함
                        avatarTransform:DoLookAt(targetObjectName.transform.position, 1)
                    end
                    isArriveFirst = false
                    if navAgent.enabled and navAgent.isOnNavMesh then
                        navAgent:SetDestination(targetObjectName.transform.position)
                    end
                end
                coroutine.yield(nil)
            end
        end))
    end
end

-- 아바타 캐릭터를 기준으로 파라미터만큼 이동. Host에서 호출됩니다.
---@param offset Vector3 이동할 오프셋
function MoveByOffset(offset)
   SendRPC_Host("MoveByOffset_Host", offset.x, offset.y, offset.z)
end

-- 아바타 캐릭터를 기준으로 파라미터만큼 이동
---@param offsetX number X 오프셋
---@param offsetY number Y 오프셋
---@param offsetZ number Z 오프셋
function MoveByOffset_Host(offsetX, offsetY, offsetZ)
    local worldOffset = avatarTransform:TransformDirection(offsetX, offsetY, offsetZ)
    local targetPosition = avatarTransform.position + worldOffset
    if (navAgent ~= nil and navAgent.enabled and navAgent.isOnNavMesh) then
        navAgent:SetDestination(targetPosition)
    end
end

-- 이동 중지. Host에서 호출됩니다.
function StopMove_Request()
   SendRPC_Host("StopMove_Host")
end

-- 이동 중지
function StopMove_Host()
    moveTargetPos = nil
    if (navAgent ~= nil and navAgent.enabled and navAgent.isOnNavMesh) then
        navAgent:ResetPath()
    end
    if (moveRoutine ~= nil) then
        self:StopCoroutine(moveRoutine)
        moveRoutine = nil
    end
end

-- NPC를 가장 가까운 유효한 NavMesh 위로 강제 이동(워프) 시킵니다.
function WarpToNavMesh_Host()
    if navAgent == nil then return end
    
    -- NavMesh.SamplePosition(현재위치, 검색반경, 영역마스크)
    -- XLua에서 out 매개변수는 return 값으로 전달됩니다. (success, hit)
    local success, hit = CS.UnityEngine.AI.NavMesh.SamplePosition(avatarTransform.position, 2.0, CS.UnityEngine.AI.NavMesh.AllAreas)
    
    if success then
        navAgent:Warp(hit.position)
        Debug.Log("[AvatarMoveController] NPC를 NavMesh 위치로 워프했습니다: " .. tostring(hit.position))
    else
        Debug.LogWarning("[AvatarMoveController] 근처 2.0m 내에서 유효한 NavMesh 위치를 찾을 수 없습니다. 지형 배치를 확인해주세요.")
    end
end

function onSyncViewInitialized()
    if (avatarVivenBridge.GetIsMine() == false) then
        navAgent.enabled = false
    else
        -- 호스트라면 시작 시 NavMesh 위로 안착 시도
        WarpToNavMesh_Host()
    end
end

function onOwnershipChanged(isMine)
    if (isMine == true) then
        navAgent.enabled = true
        WarpToNavMesh_Host() -- 소유권이 넘어왔을 때 다시 한 번 워프 시도
    end
end

function SetNavAgentEnabled(enabled)
    navAgent.enabled = enabled
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