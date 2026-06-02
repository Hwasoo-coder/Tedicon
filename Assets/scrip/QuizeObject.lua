-- QuizObject.lua
-- 플레이어의 텍스트 입력을 받아 정답 확인 후 포탈을 활성화하는 스크립트

local util = require 'xlua.util'

-- 하드코딩 설정값
correctAnswer = "27"         -- 정답 숫자
interactionDistance = 3.0    -- 상호작용 가능한 거리

-- 전역 변수로 선언 (내부에서 이름으로 찾아서 할당할 예정)
quizCanvasObj = nil
quizInputField = nil
quizSubmitButton = nil
quizCloseButton = nil

function start()
    -- 1. 이름으로 오브젝트 자동 찾기
    local canvasObj = GameObject.Find("QuizCanvas")
    if canvasObj ~= nil then
        quizCanvasObj = canvasObj
        -- 찾자마자 바로 비활성화 (에러가 나더라도 일단 숨김)
        quizCanvasObj:SetActive(false)
        
        -- Canvas 하위에서 컴포넌트들 찾기
        quizInputField = quizCanvasObj:GetComponentInChildren(typeof(CS.TMPro.TMP_InputField))
        
        -- 하위 자식을 찾을 때 .gameObject 접근 전 반드시 nil 체크
        local submitBtnTrans = quizCanvasObj.transform:Find("SubmitButton")
        if submitBtnTrans ~= nil then 
            quizSubmitButton = submitBtnTrans:GetComponent(typeof(CS.UnityEngine.UI.Button)) 
        end
        
        local closeBtnTrans = quizCanvasObj.transform:Find("CloseButton")
        if closeBtnTrans ~= nil then 
            quizCloseButton = closeBtnTrans:GetComponent(typeof(CS.UnityEngine.UI.Button)) 
        end
    else
        Debug.LogError("[QuizObject] 하이어라키에서 'QuizCanvas'를 찾을 수 없습니다.")
        return
    end

    -- 버튼 리스너 연결 (정상적으로 찾아졌을 경우에만)
    if quizSubmitButton ~= nil then
        quizSubmitButton.onClick:AddListener(OnSubmitAnswer)
    end
    if quizCloseButton ~= nil then
        quizCloseButton.onClick:AddListener(HideQuizUI)
    end
    
    Debug.Log("[QuizObject] 시작. 주변에서 E 키를 누르세요.")
end

function update()
    -- 1. 내 플레이어 유효성 확인
    if Player.Mine == nil or Player.Mine.CharacterController == nil then return end

    -- 2. 거리 계산
    local playerPos = Player.Mine.CharacterController.transform.position
    local selfPos = transform.position
    local distance = (playerPos - selfPos).magnitude

    -- 3. 일정 거리 이내에서 E 키 입력 감지
    if distance <= interactionDistance then
        -- 키보드 유효성 및 입력 확인
        if Keyboard.current ~= nil and Keyboard.current.eKey ~= nil and Keyboard.current.eKey.wasPressedThisFrame then
            ShowQuizUI()
        end
    end

    -- UI가 켜져있는 동안 마우스 커서가 사라지는 것을 방지 (Viven 플레이어 컨트롤러 대응)
    if quizCanvasObj ~= nil and quizCanvasObj.activeSelf then
        CS.UnityEngine.Cursor.visible = true
        CS.UnityEngine.Cursor.lockState = CS.UnityEngine.CursorLockMode.None
    end
end

function ShowQuizUI()
    if quizCanvasObj == nil or quizInputField == nil then 
        Debug.LogWarning("[QuizObject] UI 참조가 없어서 창을 열 수 없습니다.")
        return 
    end
    
    quizCanvasObj:SetActive(true)
    
    -- TMP_InputField의 텍스트 초기화
    quizInputField.text = ""

    -- 1프레임 대기 후 포커스를 잡아야 InputField가 정상적으로 활성화됩니다.
    self:StartCoroutine(util.cs_generator(function()
        coroutine.yield(nil) -- 1프레임 대기
        quizInputField:Select()
        quizInputField:ActivateInputField()
    end))
end

function HideQuizUI()
    if quizCanvasObj ~= nil then 
        quizCanvasObj:SetActive(false) 

        -- 마우스 커서 다시 숨기기 및 플레이어 조작 복구
        CS.UnityEngine.Cursor.visible = false
        CS.UnityEngine.Cursor.lockState = CS.UnityEngine.CursorLockMode.Locked
    end
end

function OnSubmitAnswer()
    if quizInputField == nil then return end
    
    local userInput = quizInputField.text
    
    if userInput == correctAnswer then
        -- Viven UI API 안전 확인
        if UI ~= nil then
            UI.ToastMessage("정답입니다! 포탈이 활성화됩니다.", 3.0)
        end
        
        -- StageController의 전역 함수 호출
        if Global.CheckStage1Clear ~= nil then
            Global.CheckStage1Clear()
        end
        
        HideQuizUI()
        
        -- 정답을 맞혔으므로 이 오브젝트를 제거 (더 이상 상호작용 불가)
        GameObject.Destroy(self.gameObject)
    else
        if UI ~= nil then
            UI.ToastMessage("틀렸습니다. 다시 확인해보세요.", 2.0)
        end
        
        quizInputField.text = "" -- 오답 시 텍스트 비우기
        quizInputField:ActivateInputField()
    end
end