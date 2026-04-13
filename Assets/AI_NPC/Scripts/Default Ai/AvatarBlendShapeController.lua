-- VRM 블렌드쉐입 컨트롤러

---@class AvatarBlendShapeController
---@field PlayBlendShape_Request fun(key:string, targetValue:number)
---@field PlayBlendShape fun(key:string, targetValue:number)
---@field PlayBlendShapeRoutine_Request fun(key:string, targetValue:number, fadeInTime:number, fadeOutTime:number, duration:number, isEnableBlink:boolean)
---@field PlayBlendShapeRoutine fun(key:string, targetValue:number, fadeInTime:number, fadeOutTime:number, duration:number, isEnableBlink:boolean)
---@field SetEmotion_Request fun(emotion:string)
---@field SetEmotion fun(emotion:string)

local util = require 'xlua.util'

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
AvatarRootObject = checkInject(AvatarRootObject) -- {NPC}
_INJECTED_ORDER = 0
--endregion

BlendShapeKey = CS.VRM.BlendShapeKey
BlendShapePreset = CS.VRM.BlendShapePreset

---@class VRMBlendShapeProxy
-- 아바타 블렌드쉐입 프록시
local _blendShapeProxy

---@class Blinker
-- 눈 깜빡임 제어 클래스
local _blinker = nil

---@type BlendShapeType
local _blendShapeTypes = {
    ["Neutral"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.Neutral),
    ["A"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.A),
    ["I"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.I),
    ["U"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.U),
    ["E"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.E),
    ["O"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.O),
    ["Blink"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.Blink),
    ["Blink_L"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.Blink_L),
    ["Blink_R"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.Blink_R),
    ["Angry"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.Angry),
    ["Fun"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.Fun),
    ["Joy"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.Joy),
    ["Sorrow"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.Sorrow),
    ["Surprised"] = BlendShapeKey.CreateUnknown("Surprised"),
    ["LookUp"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.LookUp),
    ["LookDown"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.LookDown),
    ["LookLeft"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.LookLeft),
    ["LookRight"] = BlendShapeKey.CreateFromPreset(BlendShapePreset.LookRight),
    ["BrowDownLeft"] = BlendShapeKey.CreateUnknown("BrowDownLeft"),
    ["BrowDownRight"] = BlendShapeKey.CreateUnknown("BrowDownRight"),
    ["BrowInnerUp"] = BlendShapeKey.CreateUnknown("BrowInnerUp"),
    ["BrowOuterUpLeft"] = BlendShapeKey.CreateUnknown("BrowOuterUpLeft"),
    ["BrowOuterUpRight"] = BlendShapeKey.CreateUnknown("BrowOuterUpRight"),
    ["CheekPuff"] = BlendShapeKey.CreateUnknown("CheekPuff"),
    ["CheekSquintLeft"] = BlendShapeKey.CreateUnknown("CheekSquintLeft"),
    ["CheekSquintRight"] = BlendShapeKey.CreateUnknown("CheekSquintRight"),
    ["EyeBlinkLeft"] = BlendShapeKey.CreateUnknown("EyeBlinkLeft"),
    ["EyeBlinkRight"] = BlendShapeKey.CreateUnknown("EyeBlinkRight"),
    ["EyeLookDownLeft"] = BlendShapeKey.CreateUnknown("EyeLookDownLeft"),
    ["EyeLookDownRight"] = BlendShapeKey.CreateUnknown("EyeLookDownRight"),
    ["EyeLookInLeft"] = BlendShapeKey.CreateUnknown("EyeLookInLeft"),
    ["EyeLookInRight"] = BlendShapeKey.CreateUnknown("EyeLookInRight"),
    ["EyeLookOutLeft"] = BlendShapeKey.CreateUnknown("EyeLookOutLeft"),
    ["EyeLookOutRight"] = BlendShapeKey.CreateUnknown("EyeLookOutRight"),
    ["EyeLookUpLeft"] = BlendShapeKey.CreateUnknown("EyeLookUpLeft"),
    ["EyeLookUpRight"] = BlendShapeKey.CreateUnknown("EyeLookUpRight"),
    ["EyeSquintLeft"] = BlendShapeKey.CreateUnknown("EyeSquintLeft"),
    ["EyeSquintRight"] = BlendShapeKey.CreateUnknown("EyeSquintRight"),
    ["EyeWideLeft"] = BlendShapeKey.CreateUnknown("EyeWideLeft"),
    ["EyeWideRight"] = BlendShapeKey.CreateUnknown("EyeWideRight"),
    ["JawForward"] = BlendShapeKey.CreateUnknown("JawForward"),
    ["JawLeft"] = BlendShapeKey.CreateUnknown("JawLeft"),
    ["JawOpen"] = BlendShapeKey.CreateUnknown("JawOpen"),
    ["JawRight"] =  BlendShapeKey.CreateUnknown("JawRight"),
    ["MouthClose"] = BlendShapeKey.CreateUnknown("MouthClose"),
    ["MouthDimpleLeft"] = BlendShapeKey.CreateUnknown("MouthDimpleLeft"),
    ["MouthDimpleRight"] = BlendShapeKey.CreateUnknown("MouthDimpleRight"),
    ["MouthFrownLeft"] = BlendShapeKey.CreateUnknown("MouthFrownLeft"),
    ["MouthFrownRight"] = BlendShapeKey.CreateUnknown("MouthFrownRight"),
    ["MouthFunnel"] = BlendShapeKey.CreateUnknown("MouthFunnel"),
    ["MouthLeft"] = BlendShapeKey.CreateUnknown("MouthLeft"),
    ["MouthLowerDownLeft"] = BlendShapeKey.CreateUnknown("MouthLowerDownLeft"),
    ["MouthLowerDownRight"] = BlendShapeKey.CreateUnknown("MouthLowerDownRight"),
    ["MouthPressLeft"] = BlendShapeKey.CreateUnknown("MouthPressLeft"),
    ["MouthPressRight"] = BlendShapeKey.CreateUnknown("MouthPressRight"),
    ["MouthPucker"] = BlendShapeKey.CreateUnknown("MouthPucker"),
    ["MouthRight"] = BlendShapeKey.CreateUnknown("MouthRight"),
    ["MouthRollLower"] = BlendShapeKey.CreateUnknown("MouthRollLower"),
    ["MouthRollUpper"] = BlendShapeKey.CreateUnknown("MouthRollUpper"),
    ["MouthShrugLower"] = BlendShapeKey.CreateUnknown("MouthShrugLower"),
    ["MouthShrugUpper"] = BlendShapeKey.CreateUnknown("MouthShrugUpper"),
    ["MouthSmileLeft"] = BlendShapeKey.CreateUnknown("MouthSmileLeft"),
    ["MouthSmileRight"] = BlendShapeKey.CreateUnknown("MouthSmileRight"),
    ["MouthStretchLeft"] = BlendShapeKey.CreateUnknown("MouthStretchLeft"),
    ["MouthStretchRight"] = BlendShapeKey.CreateUnknown("MouthStretchRight"),
    ["MouthUpperUpLeft"] = BlendShapeKey.CreateUnknown("MouthUpperUpLeft"),
    ["MouthUpperUpRight"] = BlendShapeKey.CreateUnknown("MouthUpperUpRight"),
    ["NoseSneerLeft"] = BlendShapeKey.CreateUnknown("NoseSneerLeft"),
    ["NoseSneerRight"] = BlendShapeKey.CreateUnknown("NoseSneerRight"),
    ["TongueOut"] = BlendShapeKey.CreateUnknown("TongueOut"),
    ["Fearful"] = BlendShapeKey.CreateUnknown("Fearful"),
    ["Think"] = BlendShapeKey.CreateUnknown("Think"),
    ["Disgusted"] = BlendShapeKey.CreateUnknown("Disgusted"),
    ["Happy"] = BlendShapeKey.CreateUnknown("Happy"),
    }

BlendShapeType = _blendShapeTypes
self.LuaEnv.Global.BlendShapeType = _blendShapeTypes

local emotionBlendType = {
    ["happy"] = "Happy",
    ["sad"] = "Sorrow",
    ["angry"] = "Angry",
    ["fearful"] = "Fearful",
    ["disgusted"] = "Disgusted",
    ["surprised"] = "Surprised",
    ["calm"] = "Neutral",
    ["fluent"] = "Neutral",
    ["neutral"] = "Neutral"
}

function awake()
    _blendShapeProxy = AvatarRootObject:GetComponent("VRMBlendShapeProxy")
    _blinker = AvatarRootObject:GetComponent("Blinker")
end

--#region 블렌드쉐입 제어

-- 블렌드쉐입 즉시 재생. 모든 클라이언트에서 호출됩니다.
---@param key string 블렌드쉐입 키
---@param targetValue number 목표 값 (0.0 ~ 1.0)
function PlayBlendShape_Request(key, targetValue)
    SendRPC_All("PlayBlendShape", key, targetValue)
end

-- 블렌드쉐입 즉시 재생
---@param key string 블렌드쉐입 키
---@param targetValue number 목표 값 (0.0 ~ 1.0)
function PlayBlendShape(key, targetValue)
    local blendType = _blendShapeTypes[key]
    _blendShapeProxy:ImmediatelySetValue(blendType, targetValue)
    _blendShapeProxy:Apply()
end

-- 블렌드쉐입 애니메이션 재생 요청. 모든 클라이언트에서 호출됩니다.
---@param key string 블렌드쉐입 키
---@param targetValue number 목표 값 (0.0 ~ 1.0)
---@param fadeInTime number 페이드 인 시간 (초)
---@param fadeOutTime number 페이드 아웃 시간 (초)
---@param duration number 지속 시간 (초)
---@param isEnableBlink boolean 눈 깜빡임 활성화 여부
function PlayBlendShapeRoutine_Request(key, targetValue, fadeInTime, fadeOutTime, duration, isEnableBlink)
    SendRPC_All("PlayBlendShapeRoutine", key, targetValue, fadeInTime, fadeOutTime, duration, isEnableBlink)
end

-- 블렌드쉐입 애니메이션 재생
---@param key string 블렌드쉐입 키
---@param targetValue number 목표 값 (0.0 ~ 1.0)
---@param fadeInTime number 페이드 인 시간 (초)
---@param fadeOutTime number 페이드 아웃 시간 (초)
---@param duration number 지속 시간 (초)
---@param isEnableBlink boolean 눈 깜빡임 활성화 여부
function PlayBlendShapeRoutine(key, targetValue, fadeInTime, fadeOutTime, duration, isEnableBlink)
    -- 눈 깜빡임 여부 설정
    if not isEnableBlink then
        _blinker.enabled = false
        _blendShapeProxy:ImmediatelySetValue(_blendShapeTypes["Blink"], 0)
    end

    self:StartCoroutine(util.cs_generator(function ()
        local elapsed = 0
        while (elapsed < fadeInTime) do
            elapsed = elapsed + Time.deltaTime
            local t = math.min(elapsed / fadeInTime, 1)
            _blendShapeProxy:ImmediatelySetValue(_blendShapeTypes[key], t * targetValue)
            coroutine.yield()
        end
        coroutine.yield(WaitForSeconds(duration))

        -- fade out
        elapsed = 0
        while (elapsed < fadeOutTime) do
            elapsed = elapsed + Time.deltaTime
            local t = math.min(elapsed / fadeOutTime, 1)
            _blendShapeProxy:ImmediatelySetValue(_blendShapeTypes[key], (1 - t) * targetValue)
            coroutine.yield()
        end
        
        _blinker.enabled = true
    end))
end

--#endregion

--#region 감정 제어

function SetEmotion_Request(emotion)
    SendRPC_All("SetEmotion", emotion)
end

function SetEmotion(emotion)
    local blendType = emotionBlendType[emotion]
    Debug.Log("SetEmotion: " .. emotion .. " -> " .. tostring(blendType))
    if (blendType == "" or blendType == nil) then
        blendType = "Neutral"
    end

    -- reset
    for _, v in pairs(emotionBlendType) do
        PlayBlendShape(v, 0.0)
    end

    PlayBlendShape(blendType, 1.0)
end

--#endregion

--#region RPC 통신 함수

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