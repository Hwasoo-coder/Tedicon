# AI NPC 시스템 가이드

## 목차
1. [AvatarVivenBridge](#avatarvivenbridge)
2. [Controllers 개요](#controllers-개요)
3. [BasicAvatarManager](#basicavatarmanager)
4. [AvatarSpeechController](#avatarspeechcontroller)
5. [AvatarMoveController](#avatarmovecontroller)
6. [AvatarAnimationController](#avataranimationcontroller)
7. [AvatarBlendShapeController](#avatarblendshapecontroller)

---

## AvatarVivenBridge

### 역할
Viven(C# 서버 연결 모듈)과 Lua 이벤트 시스템 사이의 브릿지 역할을 수행합니다. 서버로부터 받은 이벤트를 Lua로 전파하고, Lua에서 서버로 명령을 전달합니다.

### 주요 함수

#### 음성 채팅 제어
- **`SetSpeakState(isCanSpeak: boolean)`**
  - 사용자의 말하기 상태를 설정합니다.
  - AI 모드와 함께 조합하여 실제 발화 가능 여부를 결정합니다.

#### 서버 이벤트 전송 함수

##### 1. SendNotyEvent (알림 이벤트)
```lua
SendNotyEvent(notyInfo: string, inferenceMode: number, interruptMode: number)
```
- **목적**: 비벤에서 발생하는 일들을 AI에게 알리는 역할
- **특징**: 주로 상황을 알리는 용도로 사용 (inferenceMode로 LLM 트리거 여부 조절 가능)
- **파라미터**:
  - `notyInfo`: 알림 내용 (예: "사용자가 오브젝트를 집었습니다")
  - `inferenceMode`: LLM 트리거 여부 (1: 트리거, -1: 트리거 안함)
  - `interruptMode`: 인터럽트 모드
    - `-1`: interrupt 모드 off (사용자 음성 입력 수신 및 AI 반응 정상 동작)
    - `1`: 사용자 음성 입력은 중단하되 내부 처리(소화)와 LLM 추론은 허용. inferenceMode가 1이면 추론 신호를 전송하며, 현재 소화 중이거나 LLM 추론 중인 경우 진행 중인 발화와 추론을 중단 및 초기화한 후 새로운 입력을 반영하여 즉시 재추론

##### 2. SendRequestEvent (요청 이벤트)
```lua
SendRequestEvent(behaviour: string, instruction: string, inferenceMode: number, interruptMode: number)
```
- **목적**: AI에게 특정 행동을 요청
- **특징**: 단일 행동을 지시하며, 마지막 요청을 추적하여 완료 시까지 보관
- **파라미터**:
  - `behaviour`: 요청할 동작 (예: "인사하기", "설명하기")
  - `instruction`: 세부 지시문 (예: "한국 전통 예절에 대해 설명해주세요")
  - `inferenceMode`: LLM 트리거 여부 (1: 트리거, -1: 트리거 안함)
  - `interruptMode`: 인터럽트 모드
    - `-1`: interrupt 모드 off (사용자 음성 입력 수신 정상 동작)
    - `1`: 사용자 음성 입력은 중단하되 내부 처리(소화)와 LLM 추론은 허용. inferenceMode가 1이면 현재 소화 중이거나 LLM 추론 중인 경우 진행 중인 발화와 추론을 중단 및 초기화한 후 새로운 입력을 반영하여 즉시 재추론

##### 3. SendChoiceEvent (선택 이벤트)
```lua
SendChoiceEvent(behaviours: string, instruction: string, inferenceMode: number, interruptMode: number)
```
- **목적**: AI에게 행동 선택지를 제공하여 AI가 상황에 맞는 행동을 선택하게 함
- **파라미터**:
  - `behaviours`: 쉼표(,)로 구분된 행동 선택지 (예: "인사하기,설명하기,질문하기")
  - `instruction`: 선택 상황에 대한 세부 지시문
  - `inferenceMode`: LLM 트리거 여부 (1: 트리거, -1: 트리거 안함)
  - `interruptMode`: 인터럽트 모드 (-1: off, 1: 사용자 음성 입력 중단하되 소화/추론 허용, inference=1이면 현재 작업 중단 후 재추론)

##### 4. SendApplyConversationEvent (대화 반영 이벤트)
```lua
SendApplyConversationEvent(speakerType: string, speakerName: string, text: string, inferenceMode: number, interruptMode: number)
```
- **목적**: 사전 제작된 음성이 LLM과 무관하게 재생되었을 때 대화 히스토리에 반영.
- **사용 예시**: 스크립트로 만들어진 인사말이나 튜토리얼 대사를 재생한 후 대화 맥락에 추가
- **파라미터**:
  - `speakerType`: 화자 유형 ('ai' 또는 'user')
  - `speakerName`: 화자 이름
  - `text`: 대화 텍스트
  - `inferenceMode`: LLM 트리거 여부 (1: 트리거, -1: 트리거 안함)
  - `interruptMode`: 인터럽트 모드 (-1: off, 1: 사용자 음성 입력 중단하되 소화/추론 허용, inference=1이면 현재 작업 중단 후 재추론)

##### 5. SendInterruptModeChangeEvent (인터럽트 모드 변경)
```lua
SendInterruptModeChangeEvent(interruptMode: number)
```
- **목적**: 다른 파라미터 변경 없이 인터럽트 모드만 변경
- **파라미터**:
  - `interruptMode`: 인터럽트 모드
    - `-1`: interrupt 모드 off (사용자 음성 입력 수신 및 AI 반응 정상 동작)
    - `1`: 사용자 음성 입력은 중단하되 내부 처리(소화)와 LLM 추론은 허용

#### 기타 제어 함수
- **`ForceStopAllAudio_Host()`**
  - 현재 재생 중인 모든 AI 오디오를 강제 중단합니다.
  - 특정 이벤트 발생 시 AI의 발화를 즉시 멈추고 싶을 때 사용합니다.

#### 연결 제어 함수
- **`ReconnectServer()`**
  - AI 서버에 재연결합니다. 기존 연결을 해제하고 처음부터 다시 연결을 시도합니다.
  - 재연결 성공 시, 현재 클라이언트가 VObject 소유자(IsMine)이면 자동으로 AI Host 복구(`RequestSessionHostChange`) 및 플레이어 영역 재감지(`Avatar_CheckPlayerInArea`)를 수행합니다.
  - 방에 혼자 있는 경우, Multi AI 세션이 삭제되었을 수 있으므로 자동으로 AI 세션을 재초기화합니다.

#### 서버 설정 함수
- **`SetAiName(name: string)`**: AI 이름 설정
- **`SetModelName(name: string)`**: 모델 이름 설정
- **`GetModelName(): string`**: 모델 이름 반환
- **`GetAiName(): string`**: AI 이름 반환
- **`GetAiId(): string`**: AI ID 반환

#### 동기화 관련 함수
- **`GetIsMine(): boolean`**: 소유권이 자신인지 여부 반환
- **`GetControlUser(): string`**: 소유자 사용자 ID 반환

### 이벤트 발생 (EventBus Invoke)

AvatarVivenBridge는 다음 이벤트를 발생시켜 다른 컴포넌트에 알립니다:

#### AI 발화 관련 이벤트
- **`Avatar_AiSpeakDetected`**
  - 파라미터: `(aiId, uuid, index, textKr, textEn, emotion, eventName)`
  - AI의 발화 문장이 감지되었을 때 발생

- **`Avatar_AiAudioDataIndexUpdated`**
  - 파라미터: `(aiId, uuid, index, eventName)`
  - AI 오디오 데이터 인덱스가 업데이트되었을 때 발생. 

- **`Avatar_UtteranceStarted`**
  - 파라미터: `(id, uuid, index)`
  - AI의 발화 문장이 시작되었을 때 발생

- **`Avatar_UtteranceCompleted`**
  - 파라미터: `(id, uuid, index)`
  - AI의 발화 문장이 완료되었을 때 발생

- **`Avatar_AiErrorReceived`**
  - 파라미터: `(id, uuid, index, errorMessage, detail)`
  - AI 에러가 발생했을 때 발생

#### 사용자 발화 관련 이벤트
- **`Avatar_AiDetectClientAudio`**
  - 파라미터: `(aiId, uuid)`
  - 사용자의 유효한 발화가 감지되었을 때 발생 (호스트만)

- **`Avatar_PlayerSpeakDetected`**
  - 파라미터: `(isSpeaking)`
  - 사용자의 발화 시작/종료가 감지되었을 때 발생

- **`Avatar_ClientTranscriptReceived`**
  - 파라미터: `(textKr, textEn)`
  - 음성 전사 결과가 도착했을 때 발생

#### 연결 상태 이벤트
- **`Avatar_ClientInitialized`**
  - 파라미터: `(isInitialized)`
  - 클라이언트 초기화 상태가 변경되었을 때 발생

- **`Avatar_Disconnected`**
  - 서버 연결이 끊어졌을 때 발생

- **`Avatar_Reconnect`**
  - 서버 재연결 요청 시 발생 (ConnectUI 버튼 클릭 등)
  - AvatarVivenBridge의 `ReconnectServer()` 함수를 트리거합니다

---

## Controllers 개요

AI NPC 시스템은 다음과 같은 컨트롤러로 구성됩니다:

1. **BasicAvatarManager** - 전체 AI 기능 총괄 관리
2. **AvatarSpeechController** - 발화 관련 처리
3. **AvatarMoveController** - 이동 및 회전 제어
4. **AvatarAnimationController** - 애니메이션 제어
5. **AvatarBlendShapeController** - 표정(블렌드쉐입) 제어
6. **ShortcutController** - 전역 단축키 처리 (Ctrl+Shift+M: 마이크 음소거 토글). 씬에 1개만 존재해야 합니다.

---

## BasicAvatarManager

### 역할
AI의 모든 기능을 통합 관리하는 중앙 매니저입니다. 각 컨트롤러를 조율하고, AI 상태를 관리하며, 이벤트를 처리합니다.

### AI 상태 (Global_AIState)
```lua
{
    DEFAULT = 0,  -- 기본 상태
    LISTEN = 1,   -- 듣기 상태 (귀 기울임)
    THINK = 2,    -- 생각 상태 (생각하는 UI)
    MOVE = 3,     -- 이동 상태 (걷는 UI)
    SPEAK = 4,    -- 말하기 상태 (말하는 UI)
    WAIT = 5,     -- 대기 상태
}
```

### 주요 함수

#### 영역 관련
- **`OnAvatarPlayerEnter(userId: string)`**
  - 플레이어가 아바타 영역에 들어왔을 때 호출

- **`OnAvatarPlayerExit(userId: string)`**
  - 플레이어가 아바타 영역에서 나갔을 때 호출

- **`OnAvatarAreaHasPlayerEnter()`**
  - 아바타 영역에 첫 번째 플레이어가 들어왔을 때 호출

- **`OnAreaHasNoPlayer()`**
  - 아바타 영역에 플레이어가 아무도 없을 때 호출

#### 발화 관련
- **`OnPlayerSpeakDetected(isSpeaking: boolean)`**
  - 사용자의 발화가 감지되었을 때 호출

- **`OnPlayerStopSpeak_Host()`**
  - 플레이어가 말하기를 멈췄을 때 호출 (호스트만)
  - AI 상태를 THINK로 변경

- **`OnAiClientAudioDetected_Host(id: string, uuid: string)`**
  - 사용자의 유효한 발화가 감지되었을 때 호출 (호스트만)
  - AI 상태를 LISTEN으로 변경

- **`OnAiSpeakDetected(id, uuid, index, textKr, textEn, emotion, eventName)`**
  - AI의 발화가 감지되었을 때 호출
  - 발화 정보를 등록하고 애니메이션 인덱스 설정

- **`OnAiSpeakUtteranceStarted(id, uuid, index)`**
  - AI의 발화 문장이 시작되었을 때 호출
  - 입 모양 애니메이션 시작, 발화 애니메이션 크로스페이드

- **`OnAiSpeakUtteranceCompleted(id, uuid, index)`**
  - AI의 발화 문장이 완료되었을 때 호출
  - 입 모양 정지

#### 상태 관리
- **`RequestAiStateChange_Host(newState: number)`**
  - AI 상태 변경 요청 (호스트만)

- **`SetThinkState_Host(isThinking: boolean)`**
  - 생각 상태 설정 (호스트만)

#### 입 모양 제어
- **`PlayMouthByWeight()`**
  - 입 모양을 볼륨에 따라 자동으로 설정
  - viseme 모드를 랜덤하게 전환하며 자연스러운 입 움직임 구현

- **`StopMouth()`**
  - 입 모양 애니메이션 정지

- **`SetMouthSensitivity(val: number)`**
  - 입 모양 민감도 설정

#### 발화 정보 관리
- **`RegisterSpeechInformation(uuid, index, textKr, textEn, emotion, eventName, speakIndex)`**
  - AI의 발화 정보를 내부 테이블에 등록

- **`ResetSpeechInformation()`**
  - 발화 정보 초기화

#### 기타
- **`ResetAvatarTransform()`**
  - 아바타의 위치와 회전을 시작 지점으로 초기화

---

## AvatarSpeechController

### 역할
플레이어의 발화를 추적하고, 유효한 청취 상태를 관리합니다.

### 주요 변수
- **`IsValidListening: boolean`**
  - AI가 유효한 플레이어의 음성을 듣고 있는지 여부

### 주요 함수

- **`PlayerSpeakDetected(userID: string, isSpeaking: boolean)`**
  - 플레이어의 말하기 감지 함수
  - 호스트에게 RPC 전송

- **`PlayerSpeakDetected_Host(userID: string, isSpeaking: boolean)`**
  - 호스트에서 실행되는 발화 감지 함수
  - 각 사용자의 발화 시작/종료 시간을 추적
  - 모든 플레이어가 말을 멈추면 `Avatar_PlayerStopSpeak` 이벤트 발생

- **`GetRecentSpeakStartPlayer(): string`**
  - 가장 최근에 말하기 시작한 플레이어의 사용자 ID 반환

- **`GetRecentSpeakEndPlayer(): string`**
  - 가장 최근에 말하기를 끝낸 플레이어의 사용자 ID 반환

---

## AvatarMoveController

### 역할
NavMeshAgent를 사용하여 아바타의 이동과 회전을 제어합니다.

### 주요 함수

#### 위치 이동
- **`MoveToTargetPos(targetPosition: Vector3)`**
  - 타겟 위치로 이동 (호스트에서 호출)

- **`MoveToTargetObject(targetObjectName: string)`**
  - 타겟 오브젝트로 이동 (호스트에서 호출)

- **`MoveToTargetObjectContinuous(targetObjectName: string, maxDistance: number)`**
  - 타겟 오브젝트를 계속 추적하며 이동
  - StopMove 호출 전까지 지속
  - maxDistance 범위 내에 도달하면 타겟을 바라봄

- **`MoveByOffset(offset: Vector3)`**
  - 아바타 기준 상대 좌표로 이동

#### 이동 제어
- **`StopMove_Request()`**
  - 이동 중지 요청 (호스트에서 호출)

- **`StopMove_Host()`**
  - 이동 중지 실행

- **`SetNavAgentEnabled(enabled: boolean)`**
  - NavMeshAgent 활성화/비활성화

### 특징
- 이동 중에는 자동으로 이동 방향을 바라봄
- Slerp를 사용하여 부드러운 회전 구현

---

## AvatarAnimationController

### 역할
아바타의 애니메이션과 IK (Inverse Kinematics)를 제어합니다.

### 애니메이터 파라미터
```lua
AnimatorHash = {
    IsWalkingHash,      -- 걷기 상태
    IsTurningHash,      -- 회전 상태
    TurnValueHash,      -- 회전 각도
    IsThinkingHash,     -- 생각 중 상태
    IsSpeakingHash,     -- 말하기 상태
    IsPlayerEnterHash,  -- 플레이어 입장 상태
    EventIndexHash,     -- 이벤트 인덱스
}
```

### 발화 애니메이션 해시
```lua
SpeakAnimationHash = {
    [1] = "Speak_Happy",
    [2] = "Speak_Sad",
    [3] = "Speak_Angry",
    [4] = "Speak_Fearful",
    [5] = "Speak_Disgusted",
    [6] = "Speak_Surprised",
    [7-11] = "Speak_Neutral_1~5"
}
```

### 주요 함수

#### 타겟 바라보기 (IK)
- **`StartLookAtTargetObject_Request(targetObjectName: string, limitAngle: number)`**
  - 타겟 오브젝트를 바라봄 (모든 클라이언트)
  - limitAngle을 넘으면 몸체도 회전

- **`StartLookAtTarget(targetTransform: Transform, limitAngle: number)`**
  - Transform을 바라봄

- **`StartLookAtPlayer_Request(playerId: string, limitAngle: number)`**
  - 플레이어의 머리를 바라봄 (모든 클라이언트)

- **`StopLookAtTarget_Request()`**
  - 타겟 바라보기 중지

#### 애니메이션 제어
- **`SetEmotionSpeakIndex(emotion: string)`**
  - 감정에 따른 발화 애니메이션 인덱스 설정

- **`CrossFade_Request(key: number, fadeTime: number)`**
  - 애니메이터 크로스페이드

- **`SetAnimatorTrigger_Request(key: number)`**
  - 애니메이터 트리거 설정

- **`SetAnimatorFloat_Request(key: number, value: number)`**
  - Float 파라미터 설정

- **`SetAnimatorInteger_Request(key: number, value: number)`**
  - Integer 파라미터 설정

- **`SetAnimatorBool_Request(key: number, value: boolean)`**
  - Bool 파라미터 설정

#### 기타
- **`SetDefaultRotation(targetRotation: Quaternion)`**
  - 아바타의 기본 회전값 설정

### 특징
- 자동으로 이동/회전 상태를 감지하여 애니메이터 파라미터 업데이트
- IK를 사용하여 타겟을 자연스럽게 바라봄
- limitAngle을 초과하면 몸체 회전 코루틴 실행

---

## AvatarBlendShapeController

### 역할
VRM 블렌드쉐입을 제어하여 아바타의 표정을 변경합니다.

### 블렌드쉐입 타입
```lua
BlendShapeType = {
    -- 기본 표정
    "Neutral", "Angry", "Joy", "Sorrow", "Fun", "Surprised",
    
    -- 입 모양 (viseme)
    "A", "I", "U", "E", "O",
    
    -- 눈 깜빡임
    "Blink", "Blink_L", "Blink_R",
    
    -- 시선
    "LookUp", "LookDown", "LookLeft", "LookRight",
    
    -- 커스텀 표정
    "Happy", "Fearful", "Disgusted", "Think",
    
    -- 얼굴 세부 (눈썹, 볼, 입 등)
    "BrowInnerUp", "CheekPuff", "MouthSmileLeft", ...
}
```

### 감정 매핑
```lua
emotionBlendType = {
    ["happy"] = "Happy",
    ["sad"] = "Sorrow",
    ["angry"] = "Angry",
    ["fearful"] = "Fearful",
    ["disgusted"] = "Disgusted",
    ["surprised"] = "Surprised",
    ["calm"] = "Neutral",
    ["fluent"] = "Neutral",
    ["neutral"] = "Neutral"
}
```

### 주요 함수

- **`PlayBlendShape_Request(key: string, targetValue: number)`**
  - 블렌드쉐입 즉시 재생 (모든 클라이언트)
  - targetValue: 0.0 ~ 1.0

- **`PlayBlendShape(key: string, targetValue: number)`**
  - 블렌드쉐입 즉시 재생

- **`PlayBlendShapeRoutine_Request(key, targetValue, fadeInTime, fadeOutTime, duration, isEnableBlink)`**
  - 블렌드쉐입 애니메이션 재생 (페이드 인/아웃 포함)
  - 모든 클라이언트에서 호출
  
- **`PlayBlendShapeRoutine(key, targetValue, fadeInTime, fadeOutTime, duration, isEnableBlink)`**
  - 블렌드쉐입 애니메이션 실행
  - fadeInTime: 페이드 인 시간 (초)
  - fadeOutTime: 페이드 아웃 시간 (초)
  - duration: 유지 시간 (초)
  - isEnableBlink: false면 깜빡임 비활성화

- **`SetEmotion_Request(emotion: string)`**
  - 감정 설정 (모든 클라이언트)

- **`SetEmotion(emotion: string)`**
  - 감정 표정 적용
  - 기존 감정 표정을 모두 초기화하고 새 감정 적용

### 특징
- VRMBlendShapeProxy를 사용하여 실시간 블렌드쉐입 제어
- Blinker 컴포넌트와 연동하여 자연스러운 눈 깜빡임
- 코루틴을 사용하여 부드러운 표정 전환

---

## 사용 예시

### 1. 단순 행동 요청 (Request)
```lua
-- 기본적인 인사 요청
avatarVivenBridge.SendRequestEvent(
    "greet",                           -- behaviour
    "Greet visitors warmly in traditional Korean etiquette style. Keep it brief and friendly.", -- instruction
    1,                                  -- inferenceMode (LLM 트리거)
    1                                   -- interruptMode (현재 작업 중단)
)

-- 질의응답 종료 요청 (복잡한 instruction 예시)
local requestSubInstruction = "You have been answering questions about the exhibited artifacts for a sufficient amount of time. " ..
    "Now, kindly inform the visitors that the Q&A session is ending and guide them to the next section. " ..
    "Keep your response concise and encouraging."
avatarVivenBridge.SendRequestEvent(
    "End Q&A",                          -- behaviour
    requestSubInstruction,              -- instruction
    1,                                  -- inferenceMode (LLM 트리거)
    1                                   -- interruptMode (현재 작업 중단)
)
```

### 2. 행동 선택지 제공 (Choice) - 복잡한 시나리오
```lua
-- 토의 장소 선택 시나리오
local availableBehaviours = "Ask where to move, Move to Panmunjom, Move to Outdoor Plaza"
local subInstruction = "Guide visitors to select a discussion location between Panmunjom (Topic: Division of North and South Korea) and the Outdoor Plaza (Topic: Museum Artifacts). " ..
    "First, you must select 'Ask where to move' and ask in English by default. " ..
    "If a valid response is received, select the movement behavior to that location. " ..
    "If an interruption (e.g., greeting, unrelated question) occurs before a decision is made, briefly acknowledge or answer it, " ..
    "but immediately guide them back to the selection process and select 'Ask where to move' again. " ..
    "If an invalid response is received, kindly explain that only those two options exist and select 'Ask where to move' again. " ..
    "The initial language is English, but answer in Korean if asked in Korean, and in English if asked in English. " ..
    "If mixed, please answer in English."
    
avatarVivenBridge.SendChoiceEvent(
    availableBehaviours,                -- behaviours
    subInstruction,                     -- instruction
    -1,                                 -- inferenceMode (트리거 안함)
    -1                                  -- interruptMode (중단 없음)
)

-- 토의 진행 시나리오 (동적 선택지)
local topicNames = {"first", "second", "third", "fourth"}
local currentTopicNumber = 2
local topicName = topicNames[currentTopicNumber] or "fourth"

local discussionBehaviours = "Ask if users have a prepared " .. topicName .. " topic, " ..
    "Propose " .. topicName .. " topic and ask for opinions, " ..
    "Accept user's " .. topicName .. " topic and summarize and ask for opinions, " ..
    "Briefly summarize opinions and ask for others thoughts, " ..
    "Summarize and finish discussion"

-- 참여자별 질문 선택지 동적 추가
local validPlayers = {"Alice", "Bob", "Charlie"}
for _, userName in ipairs(validPlayers) do
    discussionBehaviours = discussionBehaviours .. ", Ask " .. userName .. " for opinion"
end

avatarVivenBridge.SendChoiceEvent(
    discussionBehaviours,
    "As a moderator, proceed strictly according to the '[5] Moderator Rule (Content Flow Layer)' defined in the INSTRUCTION. You must absolutely follow this.",
    -1,                                 -- inferenceMode
    -1                                  -- interruptMode
)
```

### 3. 사전 제작된 대사를 대화에 반영 (ApplyConversation)
```lua
-- 사전 녹음된 음성 재생 후 대화 맥락에 추가
avatarVivenBridge.SendApplyConversationEvent(
    "ai",                              -- speakerType
    "Museum Curator",                  -- speakerName
    "Welcome to the Korean Culture Experience Center. Today, I will guide you through three exhibition halls.", -- text
    -1,                                 -- inferenceMode (트리거 안함)
    -1                                  -- interruptMode
)

-- 사용자 대사를 대화 히스토리에 추가
avatarVivenBridge.SendApplyConversationEvent(
    "user",                            -- speakerType
    "Visitor",                         -- speakerName
    "I'm interested in traditional Korean instruments.", -- text
    -1,                                 -- inferenceMode (트리거 안함)
    -1                                  -- interruptMode
)
```

### 4. 알림 이벤트 (Noty) - 상황 전달
```lua
-- 시간 경과 알림
avatarVivenBridge.SendNotyEvent(
    "15 seconds passed without any user opinion suggestions.",
    1,                                  -- inferenceMode (LLM 트리거)
    -1                                  -- interruptMode
)

-- 타임아웃 알림 및 강제 종료
avatarVivenBridge.SendNotyEvent(
    "60 minutes have passed since the discussion started.",
    -1,                                 -- inferenceMode (트리거 안함)
    -1                                  -- interruptMode
)
avatarVivenBridge.SendRequestEvent(
    "Summarize and finish discussion",
    "Since 60 minutes have passed since the discussion started, now conclude the discussion.",
    1,                                  -- inferenceMode (LLM 트리거)
    -1                                  -- interruptMode
)
```

### 5. AI 이동 및 인터랙션 제어
```lua
local avatarMoveController = GetComponent("AvatarMoveController")
local avatarAnimationController = GetComponent("AvatarAnimationController")

-- 특정 위치로 이동
local targetPosition = Vector3(10, 0, 5)
avatarMoveController.MoveToTargetPos(targetPosition)

-- 오브젝트 지속 추적
avatarMoveController.MoveToTargetObjectContinuous("PlayerObject", 2.0)

-- 플레이어 바라보기
avatarAnimationController.StartLookAtPlayer_Request(Player.Mine.UserID, 60)
```

### 6. 감정 표현 제어
```lua
local avatarBlendShapeController = GetComponent("AvatarBlendShapeController")

-- 행복한 표정
avatarBlendShapeController.SetEmotion_Request("happy")

-- 미소 블렌드쉐입 애니메이션
avatarBlendShapeController.PlayBlendShapeRoutine_Request(
    "Joy",      -- key
    1.0,        -- targetValue
    0.3,        -- fadeInTime
    0.3,        -- fadeOutTime
    2.0,        -- duration
    true        -- isEnableBlink
)
```

---

## 주의사항

1. **호스트 권한**: 일부 함수는 호스트에서만 실행됩니다 (_Host 접미사)
2. **RPC 통신**: _Request 접미사가 있는 함수는 모든 클라이언트에 동기화됩니다
3. **이벤트 등록**: EventBus를 통한 이벤트는 반드시 start()에서 등록해야 합니다
4. **코루틴 관리**: 코루틴 실행 시 이전 코루틴을 적절히 정리해야 메모리 누수를 방지할 수 있습니다
5. **inferenceMode와 interruptMode**: 
   - **inferenceMode**: LLM 트리거 여부
     - `1`: LLM 추론 트리거 (새로운 응답 생성)
     - `-1`: LLM 트리거 안함 (이벤트만 기록)
   - **interruptMode**: AI 입력 및 처리 제어
     - `-1`: interrupt 모드 off (사용자 음성 입력 수신 및 AI 반응 정상 동작)
     - `1`: 사용자 음성 입력은 중단하되 내부 처리(소화)와 LLM 추론은 허용. inferenceMode=1과 함께 사용 시 현재 소화 중이거나 LLM 추론 중인 경우 진행 중인 발화와 추론을 중단 및 초기화한 후 새로운 입력을 반영하여 즉시 재추론
   - **⚠️ 중요**: inferenceMode=1, interruptMode=1로 설정 후 계속 이벤트를 보낼 경우, interruptMode를 -1로 변경하기 전까지 AI NPC가 사용자의 음성을 수신하지 않는 상태가 유지됩니다. 일련의 명령 실행 후에는 반드시 `SendInterruptModeChangeEvent(-1)`을 호출하여 정상 상태로 복구해야 합니다.

---

## 문의

추가 문의사항이나 버그 리포트는 개발팀에 문의하세요.
