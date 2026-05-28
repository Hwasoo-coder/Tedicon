--stage2 portal
local IsTeleporting = false

function onPlayerEnter(userID)
    -- 1. 현재 트리거에 들어온 사람이 '나(로컬 플레이어)'인지 확인
    if Player.Mine == nil or userID ~= Player.Mine.UserID then return end
    
    if IsTeleporting then return end

    Debug.Log("[Stage2Portal] 로컬 플레이어 감지 - 텔레포트 시작")
    IsTeleporting = true

    -- 캐릭터 이동 실행
    Player.Mine.TeleportPlayer(Vector3(91.91, 0.73, 4068.64), Quaternion.identity)
    Debug.Log("[Stage2Portal] TeleportPlayer 실행 완료")

    -- 포탈 밖으로 나갔을 때 다시 활성화되도록 IsTeleporting을 즉시 해제하거나, 
    -- 이동 거리가 멀다면 아래와 같이 바로 초기화해도 무방합니다.
    IsTeleporting = false
end