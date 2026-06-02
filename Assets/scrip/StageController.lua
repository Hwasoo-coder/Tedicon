---@type GameObject
Stage1Portal = checkInject(Stage1Portal)
---@type GameObject
Stage2Portal = checkInject(Stage2Portal)
---@type GameObject
Stage3Portal = checkInject(Stage3Portal)
---@type GameObject
Stage4Portal = checkInject(Stage4Portal)

function start()
    -- 다른 스크립트(아이템 등)에서 호출할 수 있도록 Global에 등록
    Global.CheckStage1Clear = CheckStage1Clear
    Global.CheckStage2Clear = CheckStage2Clear
    Global.CheckStage3Clear = CheckStage3Clear
    Global.CheckStage4Clear = CheckStage4Clear
    Global.SetStageInfo = SetStageInfo

    -- 시작 시 포탈을 로컬에서 비활성화
    if Stage1Portal ~= nil then Stage1Portal:SetActive(false) end
    if Stage2Portal ~= nil then Stage2Portal:SetActive(false) end

    -- Stage 3와 4는 클리어 조건 없이 상시 활성화
    if Stage3Portal ~= nil then Stage3Portal:SetActive(true) end
    if Stage4Portal ~= nil then Stage4Portal:SetActive(true) end

    if Global.GameState ~= nil then
        Global.GameState.SetClear(3)
        Global.GameState.SetClear(4)
    end

    -- 게임 시작 시 첫 번째 스테이지 정보 표시
    SetStageInfo("Welcome to the Spring Stage. Pay close attention to the beautiful scenery around you and learn the value of Observation. When you are ready, here is a quiz for you: What is the total number of boats, tomatoes, and deer? If you know the answer, press the E key near the cube to enter your answer!")
    
    -- 시작 시 1스테이지 음악 재생 (SoundManager를 통해)
    if Global.SoundManager ~= nil then
        Global.SoundManager.PlayBGM(1)
    end
end

-- 상단 HUD 텍스트를 변경하는 전역 함수
function SetStageInfo(msg)
    local hud = GameObject.Find("StageHUD")
    if hud ~= nil then
        local txt = hud:GetComponentInChildren(typeof(CS.TMPro.TMP_Text))
        if txt ~= nil then
            txt.text = msg
        end
    end
end

-- stage1 클리어 체크함수
function CheckStage1Clear()
    Debug.Log("[StageController] CheckStage1Clear 호출됨 (AI 이벤트)")

    if Global.GameState ~= nil then
        Global.GameState.SetClear(1)
        Debug.Log("[Stage1 클리어 처리 완료]")
    end

    if Stage1Portal ~= nil then
        Stage1Portal:SetActive(true)
        Debug.Log("[Stage1 포탈 생성 완료]")
    else
        Debug.LogError("[StageController] Stage1Portal이 Inspector에서 할당되지 않았습니다!")
    end
end

-- stage2 클리어 체크함수
function CheckStage2Clear()
    Debug.Log("[StageController] CheckStage2Clear 호출됨")

    if Global.GameState ~= nil and Global.GameState.GetItem(2) >= 3 then
        Global.GameState.SetClear(2)
        Debug.Log("[Stage2 클리어 처리 완료]")
        if Stage2Portal ~= nil then
            Stage2Portal:SetActive(true)
            Debug.Log("[Stage2 포탈 생성 완료]")
            UI.ToastMessage("사과를 다 모아 마을쪽에 포탈이 활성화 되었습니다!", 3.0)
        else
            Debug.LogError("[StageController] Stage2Portal이 Inspector에서 할당되지 않았습니다!")
        end
    else
        if Global.GameState == nil then
            Debug.LogError("[StageController] GameState가 Global에 없습니다!")
        else
            Debug.Log("[StageController] 조건 미달 - 현재 아이템 개수: " .. tostring(Global.GameState.GetItem(2)))
        end
    end
end


-- stage3 클리어 체크함수
function CheckStage3Clear()
    -- 상시 활성화 상태이므로 별도의 체크 로직이 필요하지 않습니다.
end

-- stage4 클리어 체크함수
function CheckStage4Clear()
    -- 상시 활성화 상태이므로 별도의 체크 로직이 필요하지 않습니다.
end