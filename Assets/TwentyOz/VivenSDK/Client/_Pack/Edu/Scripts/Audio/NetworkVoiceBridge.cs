using UnityEngine;
using System;

namespace TwentyOz.VivenSDK.EduExtension.Scripts.Audio
{
    public class NetworkVoiceBridge : MonoBehaviour
    {
        /// <summary>
        /// 플레이어의 음성이 감지되었을 때 호출되는 이벤트.
        /// 첫 번째 매개변수는 사용자 ID
        /// 두 번째 매개변수는 음성 감지 상태  true면 음성 감지 시작, false면 음성 감지 종료
        /// 서버에 연결되지 않았거나, 음소거 상태이거나, 대화할 수 있는 AI가 없을 때는 호출되지 않음
        /// </summary>
        [NonSerialized] public Action<bool> onPlayerSpeakDetected;

        /// <summary>
        /// 클라이언트 음성의 전사 결과가 도착했을 때 호출되는 이벤트.
        /// 첫 번째 매개변수는 한국어 전사 텍스트
        /// 두 번째 매개변수는 영어 전사 텍스트
        /// </summary>
        [NonSerialized] public Action<string, string> onClientTranscriptReceived;


        /// <summary>
        /// 1:1 어시스턴트의 남은 토큰 수가 업데이트 되었을 때 호출되는 이벤트.
        /// int 남은 토큰 수    
        /// </summary>
        [NonSerialized] public Action<int> on1on1AssistantCountUpdated;

        /// <summary>
        /// 클라이언트 초기화 및 인증 완료시 호출되는 이벤트.
        /// bool 초기화 성공 여부
        /// </summary>
        [NonSerialized] public Action<bool> onClientInitialized;

        /// <summary>
        /// 서버와의 연결이 끊어졌을 때 호출되는 이벤트.
        /// </summary>
        [NonSerialized] public Action onDisconnected;
    }
}