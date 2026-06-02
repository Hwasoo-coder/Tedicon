--stage3 portal
local IsTeleporting = false

function onPlayerEnter(userID)
    -- 1. 현재 트리거에 들어온 사람이 '나(로컬 플레이어)'인지 확인
    if Player.Mine == nil or userID ~= Player.Mine.UserID then return end
    
    if IsTeleporting then return end

    Debug.Log("[Stage3Portal] 로컬 플레이어 감지 - 텔레포트 시작")
    IsTeleporting = true

    -- 캐릭터 이동 실행
    Player.Mine.TeleportPlayer(Vector3(55.67, 0.74, -3940.63), Quaternion.identity)
    Debug.Log("[Stage3Portal] TeleportPlayer 실행 완료")

    -- Stage 4 진입 메시지를 상단 HUD에 고정
    if Global.SetStageInfo ~= nil then
        Global.SetStageInfo("Welcome to the Winter Stage. You have traveled a long way to get here. There are no complex quests or tests in this peaceful place. Take a moment to rest and reflect on your year-long journey. Please approach the cozy campfire and share your story with the guide. The guide will follow you to listen to your story.")
    end

    -- Stage 4 음악 재생
    if Global.SoundManager ~= nil then
        Global.SoundManager.PlayBGM(4)
    end

    -- 포탈 밖으로 나갔을 때 다시 활성화되도록 IsTeleporting을 즉시 해제하거나, 
    -- 이동 거리가 멀다면 아래와 같이 바로 초기화해도 무방합니다.
    IsTeleporting = false
end