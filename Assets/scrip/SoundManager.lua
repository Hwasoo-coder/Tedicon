-- SoundManager.lua
-- 이 스크립트는 빈 GameObject에 VivenLuaBehaviour와 함께 부착됩니다.
-- 인스펙터(Injection Field)를 전혀 사용하지 않고 코드로만 오브젝트를 찾아 사운드를 관리합니다.

local SoundManager = {}
local mainAudioSource = nil
local bgmClips = {} -- 찾은 사운드 파일들을 담아둘 테이블

function start()
    -- 1. 자기 자신에게 붙어있는 AudioSource를 코드로 가져옵니다.
    mainAudioSource = self:GetComponent(typeof(AudioSource))
    
    if mainAudioSource == nil then
        Debug.LogError("[SoundManager] 이 오브젝트에 AudioSource 컴포넌트가 없습니다! Inspector에서 'Add Component'로 추가해주세요.")
    end

    -- 2. 하이어라키에서 이름으로 사운드 오브젝트들을 찾아 클립을 가져옵니다.
    -- 인스펙터에서 드래그할 필요 없이, 오브젝트 이름만 일치하면 됩니다.
    for i = 1, 4 do
        local objName = "BGM_Stage" .. i
        local bgmObj = GameObject.Find(objName)
        
        if bgmObj ~= nil then
            local source = bgmObj:GetComponent(typeof(AudioSource))
            if source ~= nil and source.clip ~= nil then
                bgmClips[i] = source.clip
                Debug.Log("[SoundManager] " .. objName .. "로부터 사운드 파일을 성공적으로 가져왔습니다.")
            else
                Debug.LogWarning("[SoundManager] " .. objName .. "에 AudioSource나 Clip이 없습니다.")
            end
        else
            Debug.LogWarning("[SoundManager] " .. objName .. " 오브젝트를 찾을 수 없습니다.")
        end
    end

    -- 다른 스크립트에서 접근할 수 있도록 Global 테이블에 등록
    Global.SoundManager = SoundManager
    Debug.Log("[SoundManager] Global.SoundManager 등록 완료")
end

-- 스테이지별로 클립(사운드 파일)을 교체하며 재생하는 함수
function SoundManager.PlayBGM(stageNum)
    if mainAudioSource == nil then return end
    local nextClip = bgmClips[stageNum]
    
    if nextClip ~= nil and mainAudioSource.clip ~= nextClip then
        mainAudioSource:Stop()
        mainAudioSource.clip = nextClip
        mainAudioSource.loop = true

        -- 스테이지 4(겨울 스테이지) 배경음악만 볼륨을 0.1로 설정
        if stageNum == 4 then
            mainAudioSource.volume = 0.1
        else
            mainAudioSource.volume =  0.3 -- 다른 스테이지는 기본 볼륨(0.5)으로 복구
        end

        mainAudioSource:Play()
        Debug.Log("[SoundManager] Stage " .. stageNum .. " 배경음악 재생 시작.")
    end
end

-- 스크립트가 파괴될 때 Global에서 등록 해제 (선택 사항이지만 좋은 습관)
function onDestroy()
    if Global.SoundManager == SoundManager then
        Global.SoundManager = nil
        Debug.Log("[SoundManager] Global.SoundManager 등록 해제")
    end
end