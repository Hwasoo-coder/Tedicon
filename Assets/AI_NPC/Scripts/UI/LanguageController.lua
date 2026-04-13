-- 언어를 변경하는 버튼 컨트롤러

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
-- 언어 변경 가능한 버튼
 LanguageButtonObject = checkInject(LanguageButtonObject) -- {displayName}

_INJECTED_ORDER = 0
--endregion

---@type Button
-- 언어 변경 버튼
local languageButton

---@class TranslateManager
-- 번역 매니저
local translateManager

function start()
    translateManager = Global_TranslateManager

    languageButton = LanguageButtonObject:GetComponent(typeof(Button))
    languageButton.onClick:AddListener(OnLanguageButtonClicked)
end

function OnLanguageButtonClicked()
    -- Handle the button click event
    translateManager.ChangeLanguage()
end