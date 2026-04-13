-- vr 모드와 pc 모드 간의 UI 전환을 처리하는 스크립트

local canvas

local currentMode

local forwardVar = 1
local upVar = -0.1

-- PC 모드 원본 앵커/피벗 저장용
local originalPivot
local originalAnchorMin
local originalAnchorMax
local originalAnchoredPos

-- Panel 및 자식들의 원본 레이아웃 저장용
local panel
local panelOriginal
local childOriginals = {}

-- Canvas 직접 자식(Panel - Connect 등)의 원본 레이아웃 저장용
local canvasChildOriginals = {}

function awake()
    canvas = self:GetComponent(typeof(Canvas))
    rect = canvas:GetComponent(typeof(CS.UnityEngine.RectTransform))

    -- PC 모드 원본 값 백업 (명시적 값 복사)
    originalPivot = Vector2(rect.pivot.x, rect.pivot.y)
    originalAnchorMin = Vector2(rect.anchorMin.x, rect.anchorMin.y)
    originalAnchorMax = Vector2(rect.anchorMax.x, rect.anchorMax.y)
    originalAnchoredPos = Vector2(rect.anchoredPosition.x, rect.anchoredPosition.y)

    -- Panel (첫 번째 자식) 참조
    panel = rect:GetChild(0):GetComponent(typeof(CS.UnityEngine.RectTransform))

    -- Panel 원본 백업
    panelOriginal = {
        anchoredPosition = Vector2(panel.anchoredPosition.x, panel.anchoredPosition.y)
    }

    -- Panel 자식들의 원본 레이아웃 백업
    for i = 0, panel.childCount - 1 do
        local child = panel:GetChild(i):GetComponent(typeof(CS.UnityEngine.RectTransform))
        childOriginals[i] = {
            anchorMin = Vector2(child.anchorMin.x, child.anchorMin.y),
            anchorMax = Vector2(child.anchorMax.x, child.anchorMax.y),
            anchoredPosition = Vector2(child.anchoredPosition.x, child.anchoredPosition.y),
            pivot = Vector2(child.pivot.x, child.pivot.y)
        }
    end

    -- Canvas 직접 자식들(Panel 제외)의 원본 레이아웃 백업 (Panel - Connect, Panel - Timer 등)
    for i = 1, rect.childCount - 1 do
        local child = rect:GetChild(i):GetComponent(typeof(CS.UnityEngine.RectTransform))
        canvasChildOriginals[i] = {
            anchorMin = Vector2(child.anchorMin.x, child.anchorMin.y),
            anchorMax = Vector2(child.anchorMax.x, child.anchorMax.y),
            anchoredPosition = Vector2(child.anchoredPosition.x, child.anchoredPosition.y),
            pivot = Vector2(child.pivot.x, child.pivot.y)
        }
    end
end

function start()
    currentMode = Player.Mine.PlayMode
    OnPlayModeChanged(currentMode)
end

function update()
    if (currentMode == "XR") then
        rect.position = Vector3(Player.Mine.CharacterController.transform.position.x, Player.Mine.CharacterHead.transform.position.y, Player.Mine.CharacterController.transform.position.z)
         + Player.Mine.CharacterController.transform.forward * forwardVar + Player.Mine.CharacterController.transform.up * upVar

        -- UI가 수평을 유지하며 플레이어 정면을 바라보도록 설정 (Y축 회전만)
        rect.rotation = Quaternion.LookRotation(Player.Mine.CharacterController.transform.forward, Vector3.up)
    end

    if Player.Mine.PlayMode == currentMode then return end

    currentMode = Player.Mine.PlayMode
    OnPlayModeChanged(currentMode)
end

-- VR 모드에서 Panel 자식들을 중앙 정렬로 재배치
-- VR 배치 계산 (PC 간격 유지):
-- Setting 상단 = -200 + 39.6 = -160.4
-- Detail Setting 하단 = -160.4 + 77.7(간격) = -82.7 → 중심 = -82.7 + 82.4 = -0.3
local vrChildPositions = {
    Vector2(0, -200),   -- Panel - Setting (1:1 Learning 등)
    Vector2(0, -0.3),   -- Panel - Detail Setting (Setting 위 78px 간격)
}

function OnPlayModeChanged(playMode)
    if (playMode == "PC") then
        canvas.renderMode = CS.UnityEngine.RenderMode.ScreenSpaceOverlay
        canvas.worldCamera = Camera.main
        -- PC 모드: 원본 레이아웃 복원
        rect.pivot = originalPivot
        rect.anchorMin = originalAnchorMin
        rect.anchorMax = originalAnchorMax
        rect.anchoredPosition = originalAnchoredPos

        -- Panel 원본 복원
        panel.anchoredPosition = panelOriginal.anchoredPosition

        -- Panel 자식들 원본 복원
        for i = 0, panel.childCount - 1 do
            local child = panel:GetChild(i):GetComponent(typeof(CS.UnityEngine.RectTransform))
            local orig = childOriginals[i]
            child.pivot = orig.pivot
            child.anchorMin = orig.anchorMin
            child.anchorMax = orig.anchorMax
            child.anchoredPosition = orig.anchoredPosition
        end

        -- Canvas 직접 자식들 원본 복원 (Panel - Connect 등)
        for i = 1, rect.childCount - 1 do
            local child = rect:GetChild(i):GetComponent(typeof(CS.UnityEngine.RectTransform))
            local orig = canvasChildOriginals[i]
            child.pivot = orig.pivot
            child.anchorMin = orig.anchorMin
            child.anchorMax = orig.anchorMax
            child.anchoredPosition = orig.anchoredPosition
        end
    else
        canvas.renderMode = CS.UnityEngine.RenderMode.WorldSpace
        rect.localScale = Vector3(0.0015, 0.0015, 0.0015)
        -- VR 모드: Canvas 피벗/앵커를 중앙으로
        rect.pivot = Vector2(0.5, 0.5)
        rect.anchorMin = Vector2(0.5, 0.5)
        rect.anchorMax = Vector2(0.5, 0.5)
        rect.anchoredPosition = Vector2(0, 0)

        -- Panel을 중앙으로
        panel.anchoredPosition = Vector2(0, 0)

        -- 자식들을 중앙 앵커 기준으로 재배치
        for i = 0, panel.childCount - 1 do
            local child = panel:GetChild(i):GetComponent(typeof(CS.UnityEngine.RectTransform))
            child.pivot = Vector2(0.5, 0.5)
            child.anchorMin = Vector2(0.5, 0.5)
            child.anchorMax = Vector2(0.5, 0.5)
            if vrChildPositions[i + 1] then
                child.anchoredPosition = vrChildPositions[i + 1]
            end
        end

        -- Canvas 직접 자식들도 중앙 앵커로 변경
        for i = 1, rect.childCount - 1 do
            local child = rect:GetChild(i):GetComponent(typeof(CS.UnityEngine.RectTransform))
            child.pivot = Vector2(0.5, 0.5)
            child.anchorMin = Vector2(0.5, 0.5)
            child.anchorMax = Vector2(0.5, 0.5)
        end
        -- Panel - Connect: 왼쪽으로 배치
        rect:GetChild(1):GetComponent(typeof(CS.UnityEngine.RectTransform)).anchoredPosition = Vector2(-350, -200)
    end
end
