-- ai 모드 UI 스크립트

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
-- 큐레이터 AI 이미지
CuratorAiImage = checkInject(CuratorAiImage) -- {Curator AI 이미지}

---@type Sprite
-- 프라이빗 가이드 AI 이미지
PrivateGuideAiImage = checkInject(PrivateGuideAiImage) -- {Private Guide AI 이미지}

---@type GameObject
-- AI 모드 버튼 오브젝트
AiModeButtonObject = checkInject(AiModeButtonObject) --

PriavetGuideCountImageObject = checkInject(PriavetGuideCountImageObject) -- {프라이빗 가이드 잔여 횟수 이미지 오브젝트}

PriavetGuideCountTextObject = checkInject(PriavetGuideCountTextObject) -- {프라이빗 가이드 잔여 횟수 텍스트 오브젝트}

_INJECTED_ORDER = 0
--endregion

---@type EventBus
local event 

---@type AIModeManager
local aiModeManager

---@type Button
local aiModeButton

---@type Image
local aiModeImageComp

local PriavetGuideCountText

function start()
    event = Util.EventBus
    event:registerEvent("Avatar_ModeSelected", OnAiModeSwitchCompleted)

    aiModeManager = Global_AiModeManager

    aiModeButton = AiModeButtonObject:GetComponent(typeof(Button))
    aiModeButton.onClick:AddListener(OnAiModeSwitchButtonClicked)
    
    aiModeImageComp = AiModeButtonObject:GetComponent(typeof(Image))    

    PriavetGuideCountText = PriavetGuideCountTextObject:GetComponent(typeof(TMP_Text))
end

function OnAiModeSwitchButtonClicked()
    aiModeManager.OnAiModeSwitched()
end

function OnAiModeSwitchCompleted(aiMode)
    if aiMode == Global_AiMode.Multi then
        aiModeImageComp.sprite = CuratorAiImage

        PriavetGuideCountImageObject:SetActive(false)
    elseif aiMode == Global_AiMode.Private then
        aiModeImageComp.sprite = PrivateGuideAiImage

        PriavetGuideCountImageObject:SetActive(true)
    end
end

function UpdatePrivateGuideCount(count)
    PriavetGuideCountText.text = tostring(count)
end
