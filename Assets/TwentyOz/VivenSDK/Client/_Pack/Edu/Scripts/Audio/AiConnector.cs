using System;
using UnityEngine;

namespace TwentyOz.VivenSDK.EduExtension.Scripts.Audio
{
    public class AiConnector : MonoBehaviour
    {
        /// <summary>
        /// AI 이름
        /// </summary>
        [SerializeField] public string aiName;

        /// <summary>
        /// AI 모델 이름
        /// </summary>
        [SerializeField] public string modelName;

        [SerializeField] public string ttsModelName;
        
        /// <summary>
        /// 멀티 AI 모드 여부.
        /// true이면 해당 AI의 말을 룸에 접속한 모든 사용자가 들을 수 있음. false이면 해당 AI의 말을 오직 나만 들을 수 있음.
        /// </summary>
        [SerializeField] public                  bool   isMultiAi;

        /// <summary>
        /// AI 세션이 초기화되었을 때 호출되는 이벤트. Ai Session Init을 요청한 유저(호스트)에게만 호출됨.
        /// string AI 모델 이름
        /// bool 호스트 여부
        /// </summary>
        [NonSerialized] public Action<object, object>                                         onAiSessionInit;

        /// <summary>
        /// AI 호스트가 변경되었을 때 호출되는 이벤트. 호스트 변경을 요청한 유저(호스트)에게만 호출됨.
        /// string AI 모델 이름
        /// bool 호스트 변경 성공 여부 
        /// </summary>
        [NonSerialized] public Action<object, object> onAiHostChanged;
        
        /// <summary>
        /// AI가 문장 재생을 시작할 때 호출되는 이벤트
        /// string AI의 id
        /// string 문단 고유 uuid
        /// int 문장 인덱스 (몇 번째 문장인지)
        /// </summary>
        [NonSerialized] public Action<object, object, object>                                 onUtteranceStarted;
        
        /// <summary>
        /// AI가 문장 재생을 완료했을 때 호출되는 이벤트
        /// string AI의 id
        /// string 문단 고유 uuid
        /// int 문장 인덱스 (몇 번째 문장인지)
        /// </summary>
        [NonSerialized] public Action<object, object, object>                                 onUtteranceCompleted;
        
        /// <summary>
        /// AI 음성 데이터 수신시 호출되는 이벤트
        /// string 문단 고유 uuid
        /// int 문장 인덱스 (몇 번째 문장인지)
        /// string 전사 문장 (한국어)
        /// string 전사 문장 (영어)
        /// string 감정 태그
        /// string 행동 태그
        /// </summary>
        [NonSerialized] public Action<object, object, object, object, object, object> onAiSpeakDetected;
        
        /// <summary>
        /// AI가 클라이언트의 유효한 음성을 감지했을 때 호출되는 이벤트
        /// string 문단 고유 uuid 해당 시점에 재생되고 있었던 문단의 고유 ID. 없으면 빈 문자열
        /// </summary>
        [NonSerialized] public Action<string>                                         onAiDetectClientAudio;

        /// <summary>
        /// AI 음성 데이터 인덱스와 행동 태그가 업데이트 되었을 때 호출되는 이벤트
        /// string 문단 고유 uuid
        /// int 문장 인덱스 (몇 번째 문장인지)
        /// string 행동 태그
        /// </summary>
        [NonSerialized] public Action<object, object, object> onAiAudioDataIndexUpdated;

        
        /// <summary>
        /// AI 에러가 수신되었을 때 호출되는 이벤트
        /// string Ai의 id
        /// string 에러가 발생한 문단 고유 uuid 
        /// int 에러가 발생한 문장 인덱스 (몇 번째 문장인지)
        /// string 에러 타입
        /// string 에러 메시지
        /// </summary>
        [NonSerialized] public Action<object, object, object, object> onAiErrorReceived;

        /// <summary>
        /// AI 토큰 초과 알림이 수신되었을 때 호출되는 이벤트
        /// string Ai의 id
        /// </summary>
        [NonSerialized] public Action<object> onAiTokenExceededReceived;
    }
}