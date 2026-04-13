-- 아바타 오브젝트의 애니메이션을 제어하는 스크립트

---@class AvatarAnimationController
---@field AnimatorHash table<number, number> 애니메이터 파라미터 해시
---@field SpeakAnimationHash table<number, number> 발화 애니메이션 해시
---@field IsWalking boolean 걷기 애니메이션 파라미터
---@field IsTurning boolean 회전 애니메이션 파라미터
---@field TurnValue number 회전 각도 파라미터
---@field IsThinking boolean 생각 중 상태
---@field IsSpeaking boolean 말하기 상태
---@field IsPlayerEnter boolean 플레이어 입장 상태
---@field EventIndex number 일반 애니메이션 인덱스
---@field SetEmotionSpeakIndex fun(emotion:string) 감정에 따른 발화 애니메이션 인덱스 설정 함수
---@field StartLookAtTargetObject_Request fun(targetObjectName:string, limitAngle:number) 타겟 오브젝트를 바라봄. 모든 클라이언트에서 호출됩니다.
---@field StartLookAtTarget fun(targetTransform:Transform, limitAngle:number) 타겟
---@field StartLookAtPlayer_Request fun(playerId:string, limitAngle:number) 유저의 머리를 바라봄. 모든 클라이언트에서 호출됩니다.
---@field StartLookAtPlayer fun(playerId:string, limitAngle:number) 유저의 머리를 바라봄.
---@field StopLookAtTarget_Request fun() 타겟 바라보기 중지. 모든 클라이언트에서 호출됩니다.
---@field StopLookAtTarget fun() 타겟 바라보기 중지
---@field SetDefaultRotation fun(targetRotation:Quaternion) 아바타의 기본 회전값 설정
---@field CrossFade_Request fun(key:number, fadeTime:number) 애니메이터 CrossFade
---@field CrossFade fun(key:number, fadeTime:number) 애니메이터 CrossFade

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

---@type EventBus
local event

---@type AvatarVivenBridge
local avatarVivenBridge

---@type Animator
local animator

---@class AnimatorHash
---@field IsWalkingHash number 걷기 애니메이션 파라미터 해시
---@field IsTurningHash number 회전 애니메이션 파라미터 해시
---@field TurnValueHash number 회전 각도 파라미터 해시
---@field IsThinkingHash number 생각 중 상태 해시
---@field IsSpeakingHash number 말하기 상태 해시
---@field IsPlayerEnterHash number 플레이어 입장 상태 해시
---@field SpeakIndexHash number 말하기 애니메이션 인덱스 해시
---@field EventIndexHash number 일반 애니메이션 인덱스 해시
-- 애니메이터 파라미터 해시
AnimatorHash = {
    IsWalkingHash = Animator.StringToHash("IsWalking"),
    IsTurningHash = Animator.StringToHash("IsTurning"),
    TurnValueHash = Animator.StringToHash("TurnValue"),
    IsThinkingHash = Animator.StringToHash("IsThinking"),
    IsSpeakingHash = Animator.StringToHash("IsSpeaking"),
    IsPlayerEnterHash = Animator.StringToHash("IsPlayerEnter"),
    EventIndexHash = Animator.StringToHash("EventIndex"),
}

---@class SpeakAnimationHash
---@field [1] number 행복한 발화 애니메이션 해시
---@field [2] number 슬픈 발화 애니메이션 해시
---@field [3] number 화난 발화 애니메이션 해시
---@field [4] number 두려운 발화 애니메이션 해시
---@field [5] number 역겨운 발화 애니메이션 해시
---@field [6] number 놀란 발화 애니메이션 해시
---@field [7] number 중립 발화 애니메이션 해시 1
---@field [8] number 중립 발화 애니메이션 해시 2
---@field [9] number 중립 발화 애니메이션 해시 3
---@field [10] number 중립 발화 애니메이션 해시 4
---@field [11] number 중립 발화 애니메이션 해시 5
-- 발화 애니메이션 해시
SpeakAnimationHash = {
    [1] = Animator.StringToHash("Base Layer.Speak.Speak_Happy"),
    [2] = Animator.StringToHash("Base Layer.Speak.Speak_Sad"),
    [3] = Animator.StringToHash("Base Layer.Speak.Speak_Angry"),
    [4] = Animator.StringToHash("Base Layer.Speak.Speak_Fearful"),
    [5] = Animator.StringToHash("Base Layer.Speak.Speak_Disgusted"),
    [6] = Animator.StringToHash("Base Layer.Speak.Speak_Surprised"),
    [7] = Animator.StringToHash("Base Layer.Speak.Speak_Neutral_1"),
    [8] = Animator.StringToHash("Base Layer.Speak.Speak_Neutral_2"),
    [9] = Animator.StringToHash("Base Layer.Speak.Speak_Neutral_3"),
    [10] = Animator.StringToHash("Base Layer.Speak.Speak_Neutral_4"),
    [11] = Animator.StringToHash("Base Layer.Speak.Speak_Neutral_5"),
}

------ 애니메이션 파라미터  -------
-- 파라미터는 모두 동기화되어, Update() 함수에서 애니메이터에 반영됩니다.

-- 이동/회전 상태 변수
IsWalking = false
IsTurning = false
TurnValue = 0

-- 상태 변수들
IsThinking = false
IsSpeaking = false
IsPlayerEnter = false

-- 이벤트 인덱스
EventIndex = 0
---------------------------------

-- 위치/회전 추적 변수들
local avatarTransform
local previousPosition = Vector3.zero
local previousRotation = Quaternion.identity
local movementThreshold = 0.005  -- 이동 감지 임계값
local rotationThreshold = 1.0   -- 회전 감지 임계값 (도)

---@type Quaternion
-- 아바타의 기본 회전값
local defaultRot

---@type boolean
-- 타겟을 바라보고 있는지 여부
local isLookingTarget = false

---@type boolean
-- 몸체 회전 중인지 여부
local isTurningBody = false

---@type Transform
-- 바라보고 있는 타겟
local lookTarget

---@type number
-- IK 가중치 (0~1)
local lookWeight = 0.0

---@type number
-- IK 최대 회전 각도 (도)
local maxIKAngle = 60.0

local eventAnimationType = {
    [""] = 0,
    ["conversation_gesture"] = 1,
    ["excited_gesture"] = 2,
    ["shy_gesture"] = 3,
    ["sad_gesture"] = 4,
    ["bow_greeting"] = 5,
    ["nod_head"] = 6,
    ["shake_head"] = 7
}

local lookingPlayerId = ""

function start()
    avatarVivenBridge = AvatarRootObject:GetLuaComponent("AvatarVivenBridge")
    animator = AvatarRootObject:GetComponent(typeof(Animator))

    -- 초기 위치/회전 설정
    avatarTransform = AvatarRootObject.transform
    previousPosition = avatarTransform.position
    previousRotation = avatarTransform.rotation
    -- 기본 회전 값은 초기 회전 값으로 설정
    defaultRot = avatarTransform.rotation
end

function update()
    -- 애니메이터 파라미터 업데이트
    UpdateAnimatorParams()

    if avatarVivenBridge.GetIsMine() == false then
        -- 이동 및 회전은 호스트만 처리
        return
    end

    -- 이동 및 회전 상태 체크
    CheckMovementAndRotation_Host()

    -- 이동 중에는 시선 처리 하지 않음
    if (IsWalking) then
        preveWalkState = IsWalking
        return
    end

    if not isLookingTarget or lookTarget == nil then 
        -- 쳐다보고 있지 않으면 시선 가중치를 0으로 서서히 감소
        lookWeight = math.max(0.0, lookWeight - Time.deltaTime * 2.0)
        -- 아바타의 기본 회전값으로 서서히 회전
        local targetLook = Quaternion.LookRotation(
            defaultRot * Vector3.forward, Vector3.up)
        avatarTransform.rotation = Quaternion.Slerp(avatarTransform.rotation, targetLook, Time.deltaTime * 2.0)
        return 
    end
    
    -- 이미 몸체 회전 중이면 건너뜀
    if (isTurningBody) then
        return
    end

    -- 시선 가중치 서서히 증가
    lookWeight = math.min(1.0, lookWeight + Time.deltaTime * 2.0)

    local angleDiff, targetAngle = CalculateAvatarRotation()

    -- IK 한계를 넘어서는지 판단
    if math.abs(angleDiff) > maxIKAngle then
        self:StartCoroutine(util.cs_generator(RotateAvatarRoutine))
    end
end

-- 플레이어와 타겟 간의 각도 차이를 계산하는 함수
---@return number angleDifference, number targetAngle
function CalculateAvatarRotation()
    if not lookTarget then
        isLookingTarget = false
        return 0, 0
    end
    
    -- 파괴된 객체 접근 시 예외 발생 가능성 체크
    local success, targetPosition = pcall(function() return lookTarget.position end)
    if not success then
        -- 객체가 파괴됨
        isLookingTarget = false
        StopLookAtTarget()
        return 0, 0
    end
    
    -- 플레이어와 아바타 간의 각도 계산
    local avatarPosition = avatarTransform.position

    local deltaX = targetPosition.x - avatarPosition.x
    local deltaZ = targetPosition.z - avatarPosition.z
    local targetAngle = math.atan(deltaX, deltaZ) * (180 / math.pi)
    
    -- 현재 아바타의 Y축 회전 고려
    local currentBodyAngle = avatarTransform.rotation.eulerAngles.y
    local angleDifference = targetAngle - currentBodyAngle
    
    -- 각도를 -180 ~ 180 범위로 정규화
    while angleDifference > 180 do
        angleDifference = angleDifference - 360
    end
    while angleDifference < -180 do
        angleDifference = angleDifference + 360
    end

    return angleDifference, targetAngle
end

-- 아바타 몸체를 타겟을 향해 회전시키는 코루틴
function RotateAvatarRoutine()
    isTurningBody = true
    while true do
        local angleDiff, targetAngle = CalculateAvatarRotation()
        if math.abs(angleDiff) < 5.0 then
            break
        end

        avatarTransform.rotation = Quaternion.Slerp( 
            avatarTransform.rotation, Quaternion.Euler(0, targetAngle, 0), Time.deltaTime * 2.0 )            
        coroutine.yield(nil)
    end

    isTurningBody = false
end

function CheckMovementAndRotation_Host()
    local currentPosition = avatarTransform.position
    local currentRotation = avatarTransform.rotation

    -- 회전 방향 계산 (Y축 회전만 고려)
    local currentY = currentRotation.eulerAngles.y
    local previousY = previousRotation.eulerAngles.y
    local yawDelta = currentY - previousY
    
    -- 각도를 -180 ~ 180 범위로 정규화
    while yawDelta > 180 do
        yawDelta = yawDelta - 360
    end
    while yawDelta < -180 do
        yawDelta = yawDelta + 360
    end

    IsWalking = Vector3.Distance(currentPosition, previousPosition) > movementThreshold
    IsTurning = Quaternion.Angle(currentRotation, previousRotation) > rotationThreshold
    TurnValue = yawDelta

    -- 이전 값 업데이트
    previousPosition = currentPosition
    previousRotation = currentRotation
end

-- IK 업데이트
function onAnimatorIK(layerIndex)
    if not lookTarget or lookWeight <= 0 then 
        return
    end
    
    -- 파괴된 객체 접근 시 예외 발생 가능성 체크
    local success = pcall(function()
        animator:SetLookAtWeight(lookWeight, 0.1, 0.7, 0.3, 0.8)
        animator:SetLookAtPosition(lookTarget.position)
    end)
    
    if not success then
        -- 객체가 파괴됨
        isLookingTarget = false
        StopLookAtTarget()
    end
end

--#region Speech Animation

-- 감정에 따른 발화 애니메이션 인덱스 설정
---@param emotion string 감정 문자열
function SetEmotionSpeakIndex(emotion)
    -- 소문자로 변환
    emotion = string.lower(emotion)
    if emotion == "happy" then
        return SpeakAnimationHash[1]
    elseif emotion == "sad" then
        return SpeakAnimationHash[2]
    elseif emotion == "angry" then
        return SpeakAnimationHash[3]
    elseif emotion == "fearful" then
        return SpeakAnimationHash[4]
    elseif emotion == "disgusted" then
        return SpeakAnimationHash[5]
    elseif emotion == "surprised" then
        return SpeakAnimationHash[6]
    else 
        -- neutral, fluent, calm 
        return SpeakAnimationHash[math.random(7, 11)]
    end
end

--#endregion

--- Animator의 모든 파라미터 업데이트
function UpdateAnimatorParams()
    SetAnimatorBool(AnimatorHash.IsWalkingHash, IsWalking)
    SetAnimatorBool(AnimatorHash.IsTurningHash, IsTurning)
    SetAnimatorFloat(AnimatorHash.TurnValueHash, TurnValue)
    SetAnimatorBool(AnimatorHash.IsThinkingHash, IsThinking)
    SetAnimatorBool(AnimatorHash.IsSpeakingHash, IsSpeaking)
    SetAnimatorFloat(AnimatorHash.EventIndexHash, EventIndex)
end

--#region Look target

-- 타겟 오브젝트를 바라봄. 모든 클라이언트에서 호출됩니다.
---@param targetObjectName string 타겟 오브젝트 이름. 해당 타겟은 inject된 오브젝트이어야 합니다.
---@param limitAngle number IK 최대 회전 각도 (도).이 값을 넘어서면 몸체 회전 코루틴이 실행됩니다. 몸체를 회전하지 않으려면 음수 값을 전달하세요.
function StartLookAtTargetObject_Request(targetObjectName, limitAngle)
    SendRPC_All("StartLookAtTargetObject", targetObjectName, limitAngle)
end

-- 타겟 오브젝트를 바라봄
---@param targetObjectName string 타겟 오브젝트 이름. 해당 타겟은 inject된 오브젝트이어야 합니다.
---@param limitAngle number IK 최대 회전 각도 (도).이 값을 넘어서면 몸체 회전 코루틴이 실행됩니다. 몸체를 회전하지 않으려면 음수 값을 전달하세요.
function StartLookAtTargetObject(targetObjectName, limitAngle)
    isLookingTarget = true
    lookTarget = targetObjectName.transform
    maxIKAngle = limitAngle
end

-- 타겟 Transform을 바라봄.
---@param targetTransform Transform 타겟 트랜스폼
---@param limitAngle number IK 최대 회전 각도 (도).이 값을 넘어서면 몸체 회전 코루틴이 실행됩니다. 몸체를 회전하지 않으려면 음수 값을 전달하세요.
function StartLookAtTarget(targetTransform, limitAngle)
    isLookingTarget = true
    lookTarget = targetTransform
    maxIKAngle = limitAngle
end

-- 유저의 머리를 바라봄. 모든 클라이언트에서 호출됩니다.
function StartLookAtPlayer_Request(playerId, limitAngle)
    SendRPC_All("StartLookAtPlayer", playerId, limitAngle)
end 

-- 유저의 머리를 바라봄.
---@param playerId string 플레이어 ID
---@param limitAngle number IK 최대 회전 각도 (도).이 값을 넘어서면 몸체 회전 코루틴이 실행됩니다. 몸체를 회전하지 않으려면 음수 값을 전달하세요.
function StartLookAtPlayer(playerId, limitAngle)
    isLookingTarget = true
    Debug.Log("StartLookAtPlayer: " .. playerId)
    -- 플레이어의 머리 위치를 타겟으로 설정
    if (playerId == Player.Mine.UserID) then
        lookTarget = Player.Mine.CharacterHead
    else
        lookTarget = Player.Other.GetOtherPlayerHead(playerId)
    end
    if lookTarget == nil then
        Debug.Log("StartLookAtPlayer: lookTarget is nil for playerId " .. playerId)
        isLookingTarget = false
        return
    end

    lookingPlayerId = playerId
    
    maxIKAngle = limitAngle
end

-- 타겟 바라보기 중지. 모든 클라이언트에서 호출됩니다.
function StopLookAtTarget_Request()
    SendRPC_All("StopLookAtTarget")
end

-- 타겟 바라보기 중지
function StopLookAtTarget()
    isLookingTarget = false
    lookTarget = nil
    lookingPlayerId = ""
    Debug.Log("StopLookAtTarget called")
end

function SetDefaultRotation(rot)
   defaultRot = rot 
end

function onUserLeaveRoom(userData)
    -- 쳐다보고 있는 플레이어가 나간 것이라면 더 이상 쳐다보지 않음
    if (lookingPlayerId == "" or lookingPlayerId ~= userData.userId) then
        Debug.Log("onUserLeaveRoom: ignoring user" .. userData.userId  .. ", lookingPlayerId is " .. lookingPlayerId)
        return
    end
    StopLookAtTarget()
end 

--#endregion

--#region Animation

-- 애니메이터 CrossFade 파라미터 업데이트. 모든 클라이언트에서 호출됩니다.
---@param key integer CrossFade 키
---@param fadeTime number 페이드 시간
function CrossFade_Request(key, fadeTime)
    SendRPC_All("CrossFade", key, fadeTime)
end

-- 애니메이터 CrossFade 파라미터 업데이트.
---@param key integer CrossFade 키
---@param fadeTime number 페이드 시간
function CrossFade(key, fadeTime)
    animator:CrossFade(key, fadeTime)
end

-- 애니메이터 Trigger 파라미터 업데이트. 모든 클라이언트에서 호출됩니다.
---@param key integer Trigger 키
function SetAnimatorTrigger_Request(key)
    SendRPC_All("SetAnimatorTrigger", key)
end

-- 애니메이터 트리거 설정
---@param key integer 트리거 키
function SetAnimatorTrigger(key)
    if (animator ~= nil) then
        animator:SetTrigger(key)
    end
end

-- 애니메이터 Float 파라미터 업데이트. 모든 클라이언트에서 호출됩니다.
---@param key integer Float 키
---@param value number Float 값
function SetAnimatorFloat_Request(key, value)
    SendRPC_All("SetAnimatorFloat", key, value)
end

-- 애니메이터 Float 설정
---@param key integer Float 키
---@param value number Float 값
function SetAnimatorFloat(key, value)
    if (animator ~= nil) then
        animator:SetFloat(key, value)
    end
end

-- 애니메이터 Integer 파라미터 업데이트. 모든 클라이언트에서 호출됩니다.
---@param key integer Integer 키
---@param value number Integer 값
function SetAnimatorInteger_Request(key, value)
    SendRPC_All("SetAnimatorInteger", key, value)
end

-- 애니메이터 Integer 설정
---@param key integer Integer 키
---@param value number 정수 값
function SetAnimatorInteger(key, value)
    if (animator ~= nil) then
        animator:SetInteger(key, value)
    end
end

-- 애니메이터 Bool 파라미터 업데이트. 모든 클라이언트에서 호출됩니다.
---@param key integer Bool 키
---@param value boolean Bool 값
function SetAnimatorBool_Request(key, value)
    SendRPC_All("SetAnimatorBool", key, value)
end

-- 애니메이터 Bool 설정
---@param key integer Bool 키
---@param value boolean Bool 값
function SetAnimatorBool(key, value)
    if (animator ~= nil) then
        animator:SetBool(key, value)
    end
end

--#endregion

-- 동기화 업데이트 전송
-- [1] IsWalking boolean 걷기 애니메이션 파라미터
-- [2] IsTurning boolean 회전 애니메이션 파라미터
-- [3] TurnValue number 회전 각도 파라미터
-- [4] IsThinking boolean 생각 중 상태
-- [5] IsSpeaking boolean 말하기 상태
-- [6] IsPlayerEnter boolean 플레이어 입장 상태
-- [7] EventIndex number 일반 애니메이션 인덱스
function sendSyncUpdate()
    local syncTable = {}

    syncTable[1] = IsWalking
    syncTable[2] = IsTurning
    syncTable[3] = TurnValue
    syncTable[4] = IsThinking
    syncTable[5] = IsSpeaking
    syncTable[6] = IsPlayerEnter
    syncTable[7] = EventIndex

    return syncTable
end

-- 동기화 업데이트 수신
function receiveSyncUpdate(syncTable)
    if (syncTable == nil) then
        return
    end

    IsWalking = syncTable[1]
    IsTurning = syncTable[2]
    TurnValue = syncTable[3]
    IsThinking = syncTable[4]
    IsSpeaking = syncTable[5]
    IsPlayerEnter = syncTable[6]
    EventIndex = syncTable[7]
end

function SendRPC_Host(funcName, ...)
    local param = { ... }
    SyncView:SendTargetRPC(funcName, { avatarUtil.GetControlUser() }, param)
end

function SendRPC_All(funcName, ...)
    local param = { ... }
    SyncView:SendRPC(funcName, RPCSendOption.All, param)
end

function SendRPC_Others(funcName, ...)
    local param = { ... }
    SyncView:SendRPC(funcName, RPCSendOption.Others, param)
end