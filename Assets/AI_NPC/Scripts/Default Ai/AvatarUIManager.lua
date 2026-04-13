-- 아바타 npc의 ui를 관리하는 스크립트

---@class AvatarUIManager
---@field public ThinkStateObject GameObject 생각 상태 UI 오브젝트
---@field public ChatBubbleUiObject GameObject 채팅 버블 UI 오브젝트
---@field public SubTextObject GameObject 발화 자막 오브젝트
---@field public WaitStateObject GameObject 대기 상태 UI 오브젝트
---@field public ListenStateObject GameObject 듣기 상태 UI 오브젝트
---@field public MoveStateObject GameObject 이동 상태 UI 오브젝트
---@field public SetSpeechSub_Request fun(kr:string, en:string) 발화 자막 설정 요청 함수
---@field public SetSpeechSub fun(kr:string, en:string) 발화 자막 설정 함수
---@field public ChangeSubActivate fun():boolean 자막 활성화/비활성화 변경 함수
---@field public ChangeSubLanguage fun():languageMode 자막 언어
---@field public OnAiStateChanged_Host fun(newState:Global_AIState) AI 상태 변경 호스트용 함수
---@field public OnAiStateChanged fun(newState:Global_AIState) AI 상태 변경 함수

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
ThinkStateObject = checkInject(ThinkStateObject) -- 

---@type GameObject
ChatBubbleUiObject = checkInject(ChatBubbleUiObject) -- 채팅 버블 UI 오브젝트

SubTextObject = checkInject(SubTextObject) -- 발화 자막 오브젝트

---@type GameObject
WaitStateObject = checkInject(WaitStateObject) -- 대기 상태 UI 오브젝트

---@type GameObject
ListenStateObject = checkInject(ListenStateObject) -- 듣기 상태 UI 오브젝트

---@type GameObject
MoveStateObject = checkInject(MoveStateObject) -- 이동 상태 UI 오브젝트

_INJECTED_ORDER = 0
--endregion

local aiStateUi = {
    [Global_AIState.THINK] = ThinkStateObject,
    -- [Global_AIState.SPEAK] = ChatBubbleUiObject, -- 말하기 상태에 대한 ui는 발화 이벤트에서 처리
    [Global_AIState.WAIT] = WaitStateObject,
    [Global_AIState.LISTEN] = ListenStateObject,
    [Global_AIState.MOVE] = MoveStateObject,
}

local languageText 

---@type TMP_Text
local speechTextComp

local isSubActivate

local krText
local enText

---@enum languageMode
local languageMode = {
    EN = 1,
    KR = 2,
}

Global_LanguageMode = languageMode
self.LuaEnv.Global.Global_LanguageMode = languageMode

local currentLanguageMode = languageMode.EN

local currentState = -1

local uiObjects = {} -- UI 오브젝트들을 저장할 테이블

function start()
    speechTextComp = SubTextObject:GetComponent(typeof(TMP_Text))
    isSubActivate = false
    SetSpeechSub("", "")
    
    -- UI 오브젝트들을 테이블에 저장
    table.insert(uiObjects, ThinkStateObject)
    table.insert(uiObjects, ChatBubbleUiObject)
    table.insert(uiObjects, WaitStateObject)
    table.insert(uiObjects, ListenStateObject)
    table.insert(uiObjects, MoveStateObject)
end

function update()
    -- 플레이어 캐릭터가 존재하면 UI가 플레이어를 바라보도록 설정
    if Player.Mine.CharacterController ~= nil then
        local playerTransform = Player.Mine.CharacterController.transform
        for _, uiObject in ipairs(uiObjects) do
            if uiObject.activeSelf then
                -- UI가 플레이어를 바라보도록 회전
                local direction = uiObject.transform.position - playerTransform.position
                direction.y = 0 -- Y축은 고정 (수평으로만 회전)
                if direction.magnitude > 0.01 then
                    uiObject.transform.rotation = Quaternion.LookRotation(direction)
                end
            end
        end
    end
end

function OnAiStateChanged_Host(newState)
    SendRPC_All("OnAiStateChanged", newState)
end

--- AI의 상태가 변경됨
---@param aiState Global_AIState 변경된 AI 상태
function OnAiStateChanged(newState)
    Debug.Log("AvatarUIManager: OnAiStateChanged: " .. tostring(newState))
    if (newState == Global_AIState.MOVE or newState == Global_AIState.LISTEN) then
        -- 이동 또는 듣기 상태일 때는 발화 자막 초기화
        SetSpeechSub("", "")
    end
    currentState = newState
    for state, uiObject in pairs(aiStateUi) do
        if state == newState then
            uiObject:SetActive(true)
        else
            uiObject:SetActive(false)
        end
    end
     
end

--#region Ai Speech

function ChangeSubActivate()
    if isSubActivate == false then
        isSubActivate = true
    else
        isSubActivate = false
    end

    if (isSubActivate and (currentState == Global_AIState.SPEAK)) then
        -- 자막 활성화를 했는데, 현재 AI가 발화 상태이면 자막 보이기
        ChatBubbleUiObject:SetActive(true)
    else
        ChatBubbleUiObject:SetActive(false)
    end

    return isSubActivate
end

function ChangeSubLanguage()
    if currentLanguageMode == languageMode.KR then
        currentLanguageMode = languageMode.EN
        speechTextComp.text = enText
    else
        currentLanguageMode = languageMode.KR
        speechTextComp.text = krText
    end

    return currentLanguageMode
end

function SetSubLanguage(langMode)
    currentLanguageMode = langMode

    if currentLanguageMode == languageMode.KR then
        speechTextComp.text = krText
    else
        speechTextComp.text = enText
    end
    
end

-- 발화 자막 설정 요청
---@param kr string 발화 문장 텍스트 (한국어)
---@param en string 발화 문장 텍스트 (영어)
function SetSpeechSub_Request(kr, en) 
    SendRPC_All("SetSpeechSub", kr, en)
end

-- 발화 자막 설정
---@param kr string 발화 문장 텍스트 (한국어)
---@param en string 발화 문장 텍스트 (영어)
function SetSpeechSub(kr, en)
    Debug.Log("SetSpeechSub: kr=" .. kr .. ", en=" .. en)
    krText = kr
    enText = en

    -- 현재 언어 모드에 따라 텍스트 설정
    if currentLanguageMode == languageMode.KR then
        speechTextComp.text = krText
    else
        speechTextComp.text = enText
    end

    if speechTextComp.text == ""  then
        -- 자막이 비어있으면 비활성화
        ChatBubbleUiObject:SetActive(false)
    elseif isSubActivate == true then
        -- 자막이 있고 자막 활성화 상태이면 활성화
        ChatBubbleUiObject:SetActive(true)
    end
end

--#endregion

function SendRPC_All(funcName, ...)
    local param = { ... }
    SyncView:SendRPC(funcName, RPCSendOption.All, param)
end

function SendRPC_Others(funcName, ...)
    local param = { ... }
    SyncView:SendRPC(funcName, RPCSendOption.Others, param)
end

