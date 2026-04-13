-- 전역 단축키를 처리하는 컨트롤러
-- 씬에 하나만 존재해야 합니다.

local Keyboard = CS.UnityEngine.InputSystem.Keyboard

function update()
    -- Ctrl + Shift + M: 마이크 음소거 토글
    if Keyboard.current.leftCtrlKey.isPressed and Keyboard.current.leftShiftKey.isPressed and Keyboard.current.mKey.wasPressedThisFrame
    then
        local currentMicMuteState = Room.VoiceChat.GetVoiceData().IsMicMuted
        if currentMicMuteState then
            Room.VoiceChat.MicMute(false)
            Debug.Log("마이크 음소거 해제")
        else
            Room.VoiceChat.MicMute(true)
            Debug.Log("마이크 음소거")
        end
    end
end
