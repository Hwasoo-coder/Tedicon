-- QuizObject.lua
-- 플레이어의 텍스트 입력을 받아 정답 확인 후 포탈을 활성화하는 스크립트

-- 하드코딩 설정값
correctAnswer = "15"         -- 정답 숫자
interactionDistance = 3.0    -- 상호작용 가능한 거리

function start()
    Debug.Log("[QuizObject] 스크립트 시작. 주변에서 E 키를 누르세요.")
end

function update()
    -- 1. 내 플레이어 유효성 확인
    if Player.Mine == nil or Player.Mine.CharacterController == nil then return end

    -- 2. 거리 계산
    local playerPos = Player.Mine.CharacterController.transform.position
    local selfPos = self.transform.position
    local distance = (playerPos - selfPos).magnitude

    -- 3. 일정 거리 이내에서 E 키 입력 감지
    if distance <= interactionDistance then
        if Keyboard.current.eKey.wasPressedThisFrame then
            ShowQuizInputWindow()
        end
    end
end

function ShowQuizInputWindow()
    -- UI.ShowTextInput(제목, 설명, 기본텍스트, 콜백함수)
    -- 시스템 입력창은 우측 상단에 X(닫기) 버튼이 기본적으로 포함되어 있습니다.
    UI.ShowTextInput("보안 코드 입력", "맵에 설치된 오브젝트는 총 몇 개입니까?", "", function(input)
        -- X 버튼을 누르거나 취소한 경우 input은 nil입니다.
        if input == nil then 
            return 
        end

        if input == correctAnswer then
            UI.ToastMessage("정답이야! 포탈이 활성화됐어!", 3.0)
            
            -- StageController의 전역 함수 호출
            if Global.CheckStage1Clear ~= nil then
                Global.CheckStage1Clear()
            end
            
            -- 정답을 맞혔으므로 이 오브젝트를 제거 (더 이상 상호작용 불가)
            GameObject.Destroy(self.gameObject)
        else
            UI.ToastMessage("틀렸습니다. 다시 확인해보세요.", 2.0)
            -- 오답일 경우 다시 입력창을 띄움
            ShowQuizInputWindow()
        end
    end)
end