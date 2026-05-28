local _data = {
    StageItem = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0
    },
    StageCleared = {
        [1] = false,
        [2] = false,
        [3] = false,
        [4] = false
    }
}

GameState = {}

-- 아이템 추가 함수 
function GameState.AddItem(stage) 
    _data.StageItem[stage] = _data.StageItem[stage] + 1
end

-- 아이템 개수 반환 함수
function GameState.GetItem(stage) 
    return _data.StageItem[stage]
end

--스테이지 클리어상태 설정 함수
function GameState.SetClear(stage)
    _data.StageCleared[stage] = true
end

-- 다른 스크립트에서 접근할 수 있도록 Global 테이블에 등록
Global.GameState = GameState
Debug.Log("[GameState] Global.GameState 등록 완료")
