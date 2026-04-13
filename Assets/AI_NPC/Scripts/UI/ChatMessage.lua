-- 채팅 메시지

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
-- 이름 텍스트 오브젝트
NameTextObject = checkInject(NameTextObject) -- {displayName}

---@type GameObject
-- 한국어 텍스트 오브젝트
KoreanTextObject = checkInject(KoreanTextObject) -- {displayName}

---@type GameObject
-- 영어 텍스트 오브젝트
EnglishTextObject = checkInject(EnglishTextObject) -- {displayName}
_INJECTED_ORDER = 0
--endregion

---@class ChatMessage
---@field Init fun() 초기화 함수
---@field SetText fun(name:string, kr:string, en:string) 텍스트 설정 함수

---@type TMP_Text
-- 이름 텍스트 컴포넌트
local nameTextComp

---@type TMP_Text
-- 한국어 텍스트 컴포넌트
local krTextComp

---@type TMP_Text
-- 영어 텍스트 컴포넌트k
local enTextComp

-- 초기화
function awake()
    nameTextComp = NameTextObject:GetComponent(typeof(TMP_Text))
    krTextComp = KoreanTextObject:GetComponent(typeof(TMP_Text))
    enTextComp = EnglishTextObject:GetComponent(typeof(TMP_Text))
end

-- 텍스트 설정
---@param name string 이름 텍스트
---@param kr string 한국어 텍스트
---@param en string 영어 텍스트
function SetText(name, kr, en)
    nameTextComp.text = name
    krTextComp.text = kr
    enTextComp.text = en
end