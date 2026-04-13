-- 자막 on/off UI 스크립트

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

---@type Sprite
-- 자막 활성화 이미지
SubActiveImage = checkInject(SubActiveImage) -- {displayName}

---@type Sprite
-- 자막 비활성화 이미지
SubDeactiveImage = checkInject(SubDeactiveImage) -- {displayName}

---@type Sprite
-- 자막 활성화 상태의 배경 이미지
SubActiveBackgroundImage = checkInject(SubActiveBackgroundImage) -- {displayName}

---@type Sprite
-- 자막 비활성화 상태의 배경 이미지
SubDeactiveBackgroundImage = checkInject(SubDeactiveBackgroundImage) -- {displayName}

---@type GameObject
-- 자막 On/Off 가능한 버튼
 SubButtonObject = checkInject(SubButtonObject) -- {displayName}

---@type GameObject
-- 배경 이미지 오브젝트
 BackgroundImageObject = checkInject(BackgroundImageObject) -- {displayName}

 ButtonImageObject = checkInject(ButtonImageObject) -- {displayName}

AvatarUiManagerObject = checkInject(AvatarUiManagerObject) -- {AI NPC UI Manager}

_INJECTED_ORDER = 0
--endregion

local util = require 'xlua.util'

---@type Button
-- 자막 on/off 버튼
local subButton

---@type Image
-- top 이미지
local buttonImage

---@type Image
-- background 이미지
local backgroundImage

---@type AvatarUIManager
-- AI NPC UI 매니저
local avatarUiManager

---@type Coroutine
-- 이미지 보간 코루틴
local lerpRoutine 

---@type Vector3
-- 자막 활성화일때 버튼 위치
local activePos

--- @type Vector3
-- 자막 비활성화일때 버튼 위치
local deactivePos

function start()
    subButton = SubButtonObject:GetComponent(typeof(Button))
    subButton.onClick:AddListener(OnSubButtonClicked)

    buttonImage = ButtonImageObject:GetComponent(typeof(Image))
    backgroundImage = BackgroundImageObject:GetComponent(typeof(Image))

    activePos = SubButtonObject.transform.localPosition
    deactivePos = Vector3(-activePos.x, activePos.y, activePos.z)

    avatarUiManager = AvatarUiManagerObject:GetLuaComponent("AvatarUIManager")

    -- todo 초기 자막 상태 설정
end

function OnSubButtonClicked()
    -- Handle the button click event
    local isSubActivate = avatarUiManager.ChangeSubActivate()
    if (isSubActivate) then
        backgroundImage.sprite = SubActiveBackgroundImage
        buttonImage.sprite = SubActiveImage
    else
        backgroundImage.sprite = SubDeactiveBackgroundImage
        buttonImage.sprite = SubDeactiveImage
    end
    
    local targetPos = Vector3.zero
    if (isSubActivate) then
        targetPos = activePos
    else
        targetPos = deactivePos
    end

    PlayLerpImageRoutine(targetPos)
end

--- @param targetPos Vector3
function PlayLerpImageRoutine(targetPos)
    if (lerpRoutine ~= nil) then
        self:StopCoroutine(lerpRoutine)
    end
    
    lerpRoutine = self:StartCoroutine(util.cs_generator(function ()
        local currentPos = SubButtonObject.transform.localPosition
        local targetPos = Vector3(-currentPos.x, currentPos.y, currentPos.z)
        while (Vector3.Distance(currentPos, targetPos) > 0.1) do
            currentPos = SubButtonObject.transform.localPosition
            SubButtonObject.transform.localPosition = Vector3.Lerp(currentPos, targetPos, 0.3)
            coroutine.yield(nil)
        end
        SubButtonObject.transform.localPosition = targetPos
    end))
end
