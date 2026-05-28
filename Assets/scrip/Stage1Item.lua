--  아이템 스크립트

-- Viven SDK 권장: 플레이어 전용 트리거 이벤트 사용
function onPlayerEnter(userID)
    -- 1. 현재 이 트리거에 들어온 사람이 '나(로컬 플레이어)'인지 확인
    if userID ~= Player.Mine.UserID then return end

    Debug.Log(" 로컬 플레이어 아이템 획득!")
    -- 2. 데이터 업데이트 (Global 테이블을 통해 GameState 접근)
    if Global.GameState ~= nil then
        Global.GameState.AddItem(1)
        -- 현재 아이템 개수를 가져와서 메시지에 포함
        local currentCount = Global.GameState.GetItem(1)
        UI.ToastMessage("사과를 획득했습니다! 현재 갯수: " .. tostring(currentCount), 5.0)
        Debug.Log("데이터 업데이트 완료")
    else
        Debug.LogError("GameState가 Global 테이블에 등록되지 않았습니다!")
        return
    end

    -- 3. 스테이지 클리어 조건 체크 (StageController에서 등록한 함수 호출)
    if Global.CheckStage1Clear ~= nil then
        Global.CheckStage1Clear()
        Debug.Log("[Stage1Item] 스테이지 클리어함수실행완료")
    end

    -- 4. 아이템 제거 (보이지 않는 곳으로 이동)
    -- 단순히 SetActive(false)가 동작하지 않는 경우, VObject의 위치를 옮기는 것이 가장 확실합니다.
    local vObject = VObject.Get(self.gameObject)
    if vObject ~= nil then
        -- 아이템을 바닥 밑으로 순간이동 (위치, 회전, 강제이동 여부)
        vObject:TeleportObject(Vector3(0, -100, 0), Quaternion.identity, true)
        Debug.Log("[Stage1Item] VObject 이동완료")
    else
        -- VObject가 아닌 일반 오브젝트인 경우 로컬 비활성화
        self.gameObject:SetActive(false)
        Debug.Log("[Stage1Item] 일반오브젝트 비활성화완료")
    end
end