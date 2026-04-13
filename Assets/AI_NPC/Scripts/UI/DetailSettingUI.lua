-- 세부 설정 UI 스크립트

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

DeactivateImage = checkInject(DeactivateImage) -- {비활성화 이미지}
ActivateImage = checkInject(ActivateImage) -- {활성화 이미지}
---@type GameObject
-- 세부 설정 
DetailSettingPanelObject = checkInject(DetailSettingPanelObject) -- 

---@type GameObject
-- 세부 설정 버튼 오브젝트
DetailSettingButtonObject = checkInject(DetailSettingButtonObject) -- {세부 설정 버튼 오브젝트}

_INJECTED_ORDER = 0
--endregion

---@type Button
-- 세부 설정 버튼
local detailSettingButton

local isDetailSettingPanelActive = false

local image


function start()
    detailSettingButton = DetailSettingButtonObject:GetComponent(typeof(Button))
    detailSettingButton.onClick:AddListener(OnDetailSettingButtonClicked)

    image = DetailSettingButtonObject:GetComponent(typeof(Image))

    -- 초기에는 세부 설정 패널 비활성화
    isDetailSettingPanelActive = false
    DetailSettingPanelObject:SetActive(false)
end

function OnDetailSettingButtonClicked()
    if isDetailSettingPanelActive then
        DetailSettingPanelObject:SetActive(false)
        isDetailSettingPanelActive = false
        image.sprite = DeactivateImage
    else
        DetailSettingPanelObject:SetActive(true)
        isDetailSettingPanelActive = true
        image.sprite = ActivateImage
    end
end