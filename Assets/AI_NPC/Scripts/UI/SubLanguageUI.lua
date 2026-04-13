-- 자막 언어 설정 UI 스크립트

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
-- 언어 영어/한국어 전환하는 드랍박스 오브젝트
 DropdownObject = checkInject(DropdownObject) -- {displayName}

---@type GameObject
-- Avatar UI 매니저 오브젝트
 AvatarUiManagerObject = checkInject(AvatarUiManagerObject) -- {displayName}

 ---@type GameObject
ArrowImageObject = checkInject(ArrowImageObject) -- 드롭다운 화살표 이미지 오브젝트
_INJECTED_ORDER = 0
--endregion

local util = require 'xlua.util'

---@type Dropdown
local languageDropdown

---@type AvatarUIManager
local avatarUiManager

function start()
    languageDropdown = DropdownObject:GetComponent(typeof(TMP_Dropdown))

    avatarUiManager = AvatarUiManagerObject:GetLuaComponent("AvatarUIManager")

    -- todo 초기 자막 상태 설정
    languageDropdown.onValueChanged:AddListener(OnLanguageButtonClicked)
end

function OnLanguageButtonClicked(index)
    Debug.Log("SubLanguageUI - OnLanguageButtonClicked : " .. index)
    -- Handle the button click event
    if index == 0 then
        avatarUiManager.SetSubLanguage(Global_LanguageMode.EN)
    elseif index == 1 then
        avatarUiManager.SetSubLanguage(Global_LanguageMode.KR)
    end
end