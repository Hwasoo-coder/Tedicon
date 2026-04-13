-- 서버 연결 UI 스크립트

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

local util = require 'xlua.util'

DeactivateImage = checkInject(DeactivateImage) -- {연결 해제 이미지}
ActivateImage = checkInject(ActivateImage) -- {연결 이미지}

BackgroundImageObject = checkInject(BackgroundImageObject) -- {배경 이미지 오브젝트}

_INJECTED_ORDER = 0
--endregion

local image

---@type EventBus
local event

local isClientInit
local isAiSessionInit

local button

function awake()
    event = Util.EventBus
    image = BackgroundImageObject:GetComponent(typeof(Image))
    button = self:GetComponent(typeof(Button))
    button.onClick:AddListener(Reconnect)
end

function onEnable()
    event:registerEvent("Avatar_ClientInitialized", OnClientInitialized)
    event:registerEvent("AiSessionInitialized_All", OnAiSessionInit_Host)
    event:registerEvent("Avatar_Disconnected", OnDisconnect)
end

function OnClientInitialized(isInitialized)
    isClientInit = isInitialized
    if (not isClientInit) then
        OnDisconnect()
    end
end

function OnAiSessionInit_Host(modelName, isHost)
    if (isClientInit) then
        OnConnect()
    end
end

function OnConnect()
    image.sprite = ActivateImage
end

function Reconnect()
    Debug.Log("Reconnect button clicked")
    event:invoke("Avatar_Reconnect")
end

function ScaleAnimation()
    local transform = BackgroundImageObject.transform
    local originalScale = transform.localScale
    local targetScale = originalScale * 1.2
    local duration = 0.3
    
    -- 3번 반복
    for i = 1, 3 do
        -- 확대
        local elapsed = 0
        while elapsed < duration do
            elapsed = elapsed + Time.deltaTime
            local t = elapsed / duration
            transform.localScale = Vector3.Lerp(originalScale, targetScale, t)
            coroutine.yield()
        end
        
        -- 축소
        elapsed = 0
        while elapsed < duration do
            elapsed = elapsed + Time.deltaTime
            local t = elapsed / duration
            transform.localScale = Vector3.Lerp(targetScale, originalScale, t)
            coroutine.yield()
        end
    end
    
    transform.localScale = originalScale
end

function OnDisconnect()
    isAiSessionInit = false
    isClientInit = false
    image.sprite = DeactivateImage
    self:StartCoroutine(util.cs_generator(ScaleAnimation))
end
