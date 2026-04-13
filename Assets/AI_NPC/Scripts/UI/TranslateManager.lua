-- 텍스트 한/영 번역 매니저

---@class BilingualText[]
-- 모든 BilingualText 컴포넌트들을 저장하는 테이블
local bilingualTexts = {}

---@enum LanguageOptions
local languageOptions = {
    KOR = 1,
    ENG = 2,
}

LanguageOptions = languageOptions
self.LuaEnv.Global.LanguageOptions = languageOptions


---@type LanguageOptions
-- 현재 언어
local currentLanguage = LanguageOptions.KOR -- 기본 언어 설정

function awake()
    Global_TranslateManager = self:GetLuaComponent("TranslateManager")
    self.LuaEnv.Global.Global_TranslateManager = Global_TranslateManager

    Initialize()
end

-- 모든 BilingualText 컴포넌트들을 초기화
function Initialize()
    -- 모든 TMP_Text 컴포넌트 찾음
    local allTextComponents = GameObject.FindObjectsByType(typeof(TMP_Text), CS.UnityEngine.FindObjectsSortMode.None)

    -- TMP_Text 중 BilingualText 컴포넌트가 붙어있는 것들만 필터링
    for i = 0, allTextComponents.Length - 1 do
        local textComponent = allTextComponents[i]
        local bilingualText = textComponent.gameObject:GetLuaComponent("BilingualText")
        if bilingualText then
            -- BilingualText 컴포넌트가 붙어있는 경우
            table.insert(bilingualTexts, bilingualText)
        end
    end
end

-- 모든 BilingualText 컴포넌트의 언어 변경
function ChangeLanguage()
    if (currentLanguage == languageOptions.KOR) then
        currentLanguage = languageOptions.ENG
    else
        currentLanguage = languageOptions.KOR
    end
    for _, bilingualText in ipairs(bilingualTexts) do
        bilingualText.UpdateText(currentLanguage)
    end
end