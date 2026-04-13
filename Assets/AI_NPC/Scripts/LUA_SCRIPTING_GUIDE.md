# Viven SDK Lua 스크립팅 가이드

## 목차
1. [기본 구조](#기본-구조)
2. [XLua 코루틴](#xlua-코루틴)
3. [Unity API 호출](#unity-api-호출)
4. [이벤트 시스템](#이벤트-시스템)
5. [동기화 패턴](#동기화-패턴)
6. [성능 최적화](#성능-최적화)
7. [실전 예제](#실전-예제)

---

## 기본 구조

### 스크립트 템플릿
```lua
-- 스크립트 설명

--region Injection list
local _INJECTED_ORDER = 0
local function checkInject(OBJECT) 
    _INJECTED_ORDER = _INJECTED_ORDER+1 
    assert(OBJECT, _INJECTED_ORDER .. "th object is missing") 
    return OBJECT 
end

-- Injection 변수들
MyObject = checkInject(MyObject) -- {오브젝트 설명}

_INJECTED_ORDER = 0
--endregion

-- XLua 유틸리티 (코루틴 사용 시 필수)
local util = require 'xlua.util'

-- 지역 변수 선언
local myVariable = nil
local timer = 0

-- 생명주기 함수
function awake()
    -- 초기화 (컴포넌트 가져오기 등)
end

function start()
    -- 시작 로직
end

function update()
    -- 매 프레임 실행
end

function onDestroy()
    -- 정리 작업
end

-- 커스텀 함수들
function MyCustomFunction()
    -- 사용자 정의 로직
end
```

---

## XLua 코루틴

### 기본 코루틴 사용법

#### 1. 코루틴 시작하기
```lua
local util = require 'xlua.util'

function start()
    -- 코루틴 시작
    self:StartCoroutine(util.cs_generator(MyCoroutine))
end

function MyCoroutine()
    Debug.Log("코루틴 시작")
    
    -- 1초 대기
    coroutine.yield(WaitForSeconds(1))
    
    Debug.Log("1초 후 실행")
    
    -- 다음 프레임까지 대기
    coroutine.yield()
    
    Debug.Log("다음 프레임에 실행")
end
```

#### 2. 조건부 대기 (WaitUntil)
```lua
function WaitForInitialization()
    -- 특정 조건이 충족될 때까지 대기
    coroutine.yield(WaitUntil(function() 
        return isInitialized == true 
    end))
    
    Debug.Log("초기화 완료!")
    
    -- 복잡한 조건
    coroutine.yield(WaitUntil(function()
        return playerCount > 0 and isServerConnected
    end))
    
    Debug.Log("모든 조건 충족")
end
```

#### 3. 조건부 대기 (WaitWhile)
```lua
function WaitForPlayerStop()
    -- 특정 조건이 거짓이 될 때까지 대기
    coroutine.yield(WaitWhile(function() 
        return isPlayerMoving == true 
    end))
    
    Debug.Log("플레이어가 멈췄습니다")
end
```

#### 4. 코루틴 체이닝
```lua
function start()
    self:StartCoroutine(util.cs_generator(SequentialTasks))
end

function SequentialTasks()
    Debug.Log("작업 1 시작")
    coroutine.yield(WaitForSeconds(1))
    
    Debug.Log("작업 2 시작")
    coroutine.yield(WaitForSeconds(2))
    
    Debug.Log("작업 3 시작")
    coroutine.yield(WaitUntil(function()
        return someCondition == true
    end))
    
    Debug.Log("모든 작업 완료")
end
```

#### 5. 코루틴 저장 및 중단
```lua
local myCoroutine = nil

function StartMyCoroutine()
    -- 기존 코루틴이 있으면 중단
    if myCoroutine ~= nil then
        self:StopCoroutine(myCoroutine)
        myCoroutine = nil
    end
    
    -- 새 코루틴 시작 및 참조 저장
    myCoroutine = self:StartCoroutine(util.cs_generator(MyTask))
end

function MyTask()
    while true do
        Debug.Log("반복 작업 실행")
        coroutine.yield(WaitForSeconds(1))
    end
end

function onDestroy()
    -- 정리 시 코루틴 중단
    if myCoroutine ~= nil then
        self:StopCoroutine(myCoroutine)
        myCoroutine = nil
    end
end
```

### 실전 코루틴 패턴

#### 1. 시간 대기하기 (가장 기본)
```lua
-- 용도: N초 후에 무언가를 실행하고 싶을 때
function SimpleDelay()
    Debug.Log("시작!")
    
    -- 3초 대기
    coroutine.yield(WaitForSeconds(3))
    
    Debug.Log("3초 후 실행됨")
end

-- 실사용 예시: 3초 후 문 열기
function OpenDoorAfterDelay()
    Debug.Log("문이 3초 후 열립니다...")
    coroutine.yield(WaitForSeconds(3))
    
    door:SetActive(false)  -- 문 오브젝트 비활성화
    Debug.Log("문이 열렸습니다!")
end
```

#### 2. 조건이 충족될 때까지 대기하기
```lua
-- 용도: 특정 상황이 될 때까지 기다리고 싶을 때
function WaitForPlayer()
    Debug.Log("플레이어를 기다리는 중...")
    
    -- playerReady가 true가 될 때까지 계속 대기
    coroutine.yield(WaitUntil(function()
        return playerReady == true
    end))
    
    Debug.Log("플레이어 준비 완료! 게임 시작")
end

-- 실사용 예시: 플레이어가 가까이 올 때까지 대기
function WaitForPlayerNearby()
    Debug.Log("플레이어가 다가오길 기다림...")
    
    coroutine.yield(WaitUntil(function()
        -- 플레이어와의 거리가 5보다 작아지면 true
        local distance = Vector3.Distance(self.transform.position, player.transform.position)
        return distance < 5
    end))
    
    Debug.Log("플레이어가 가까이 왔어요!")
    SayHello()  -- 인사하기
end
```

#### 3. 순서대로 여러 동작 실행하기
```lua
-- 용도: A 하고 → B 하고 → C 하고... 순서대로 실행하고 싶을 때
function DoThingsInOrder()
    -- 1단계: 인사
    Debug.Log("안녕하세요!")
    coroutine.yield(WaitForSeconds(2))
    
    -- 2단계: 이동
    Debug.Log("목적지로 이동합니다")
    MoveToPosition(Vector3(10, 0, 0))
    
    -- 도착할 때까지 대기
    coroutine.yield(WaitUntil(function()
        return arrivedAtDestination == true
    end))
    
    -- 3단계: 동작 완료
    Debug.Log("도착했습니다!")
    PlayAnimation("Wave")
end

-- 실사용 예시: NPC가 순서대로 여러 지점 방문
function VisitLocations()
    local locations = {
        Vector3(10, 0, 0),
        Vector3(20, 0, 5),
        Vector3(30, 0, 10)
    }
    
    for i, position in ipairs(locations) do
        Debug.Log("지점 " .. i .. "로 이동 시작")
        
        -- 해당 위치로 이동
        avatarMoveController.MoveToTargetPos_Host(position.x, position.y, position.z)
        
        -- 도착할 때까지 대기
        coroutine.yield(WaitUntil(function()
            local distance = Vector3.Distance(self.transform.position, position)
            return distance < 0.5  -- 0.5 거리 이내면 도착으로 간주
        end))
        
        Debug.Log("지점 " .. i .. " 도착!")
        coroutine.yield(WaitForSeconds(1))  -- 1초 대기 후 다음 지점으로
    end
    
    Debug.Log("모든 지점 방문 완료!")
end
```

#### 4. 타임아웃 처리하기 (너무 오래 기다리면 포기)
```lua
-- 용도: 조건을 기다리되, 너무 오래 걸리면 포기하고 싶을 때
function WaitWithGiveUp()
    local waitTime = 0
    local maxWaitTime = 10  -- 최대 10초만 기다림
    
    while waitTime < maxWaitTime do
        -- 원하는 조건이 충족되었는지 확인
        if playerCount >= 2 then
            Debug.Log("플레이어가 충분해요! 시작합니다")
            StartGame()
            return  -- 함수 종료
        end
        
        -- 아직 조건 불충족, 계속 대기
        waitTime = waitTime + 0.5
        coroutine.yield(WaitForSeconds(0.5))
    end
    
    -- 10초가 지났는데도 조건이 안 되면 여기로 옴
    Debug.Log("시간 초과! 혼자 시작합니다")
    StartGameAlone()
end

-- 좀 더 간단한 버전
function SimpleTimeout()
    local waited = 0
    
    -- 최대 5초 동안만 기다림
    while waited < 5 do
        if isReady then
            Debug.Log("준비 완료!")
            return
        end
        waited = waited + 1
        coroutine.yield(WaitForSeconds(1))
    end
    
    Debug.Log("5초 지났어요, 그냥 진행할게요")
end
```

---

## Unity API 호출

### GameObject 및 컴포넌트 접근

```lua
function start()
    -- GameObject 찾기
    local myObject = GameObject.Find("ObjectName")
    
    -- 컴포넌트 가져오기 (반드시 typeof() 사용)
    local rigidbody = self:GetComponent(typeof(Rigidbody))
    local animator = self:GetComponent(typeof(Animator))
    local audioSource = self:GetComponent(typeof(AudioSource))
    
    -- 자식 오브젝트에서 컴포넌트 찾기
    local childComponent = self:GetComponentInChildren(typeof(Renderer))
    
    -- 부모 오브젝트에서 컴포넌트 찾기
    local parentComponent = self:GetComponentInParent(typeof(NavMeshAgent))
    
    -- Lua 컴포넌트 가져오기
    local luaComponent = self:GetLuaComponent("MyLuaScript")
    local luaChildComponent = self:GetLuaComponentInChildren("ChildLuaScript")
end
```

### Transform 조작

```lua
function update()
    -- 위치 설정
    self.transform.position = Vector3(10, 0, 5)
    
    -- 위치 이동
    local newPos = self.transform.position + Vector3(0, 0, -0.1)
    self.transform.position = newPos
    
    -- 회전
    self.transform.rotation = Quaternion.Euler(0, 90, 0)
    
    -- 로컬 위치/회전
    self.transform.localPosition = Vector3(1, 2, 3)
    self.transform.localRotation = Quaternion.identity
    
    -- 스케일
    self.transform.localScale = Vector3(2, 2, 2)
end
```

### 오브젝트 생성 및 삭제

```lua
function CreateObject()
    -- 프리팹 인스턴스 생성
    local newObject = GameObject.Instantiate(prefab)
    
    -- 위치 설정
    newObject.transform.position = spawnPoint.transform.position
    
    -- 부모 설정
    newObject.transform.parent = self.transform
    
    -- 이름 설정
    newObject.name = "NewObject"
    
    return newObject
end

function DestroyObject(obj)
    -- 오브젝트 삭제
    GameObject.Destroy(obj)
    
    -- 딜레이 후 삭제
    GameObject.Destroy(obj, 2.0)
end

function onDestroy()
    -- 참조 해제
    myObject = nil
end
```

---

## 이벤트 시스템

### EventBus 사용법

```lua
local event = Util.EventBus

function start()
    -- 이벤트 등록
    event:registerEvent("MyEvent", OnMyEvent)
    event:registerEvent("PlayerJoined", OnPlayerJoined)
end

function OnMyEvent(data1, data2)
    Debug.Log("이벤트 수신: " .. tostring(data1) .. ", " .. tostring(data2))
end

function OnPlayerJoined(playerId)
    Debug.Log("플레이어 입장: " .. playerId)
end

-- 이벤트 발생
function TriggerEvent()
    event:invoke("MyEvent", "Hello", "World")
    event:invoke("PlayerJoined", Player.Mine.UserID)
end

function onDestroy()
    -- 이벤트 등록 해제
    event:unregisterEvent("MyEvent", OnMyEvent)
    event:unregisterEvent("PlayerJoined", OnPlayerJoined)
end
```

### Unity 이벤트

```lua
function start()
    -- UI 버튼 클릭 이벤트
    local button = ButtonObject:GetComponent(typeof(Button))
    button.onClick:AddListener(OnButtonClick)
    
    -- 익명 함수로 등록
    button.onClick:AddListener(function()
        Debug.Log("버튼 클릭됨")
        DoSomething()
    end)
end

function OnButtonClick()
    Debug.Log("버튼 클릭 이벤트 처리")
end
```

### Collision 및 Trigger 이벤트

```lua
function onCollisionEnter(collision)
    local otherObject = collision.gameObject
    Debug.Log("충돌: " .. otherObject.name)
    
    -- 컴포넌트 확인
    local player = collision.gameObject:GetComponent(typeof(CharacterController))
    if player ~= nil then
        Debug.Log("플레이어와 충돌")
    end
end

function onTriggerEnter(collider)
    local triggerObject = collider.gameObject
    Debug.Log("트리거 진입: " .. triggerObject.name)
    
    -- 태그 확인
    if collider.gameObject.tag == "Player" then
        Debug.Log("플레이어가 트리거 영역에 진입")
    end
end

function onTriggerExit(collider)
    Debug.Log("트리거 퇴장: " .. collider.gameObject.name)
end
```

---

## 동기화 패턴

### SyncView를 사용한 RPC

```lua
-- VObject 컴포넌트 (awake나 start에서 한 번만 가져오기)
local vObject

function awake()
    vObject = self:GetComponent(typeof(VObject))
end

-- 오브젝트 소유자(호스트)에게만 RPC 전송
function SendRPC_Owner(funcName, ...)
    local param = { ... }
    -- VObject의 소유자 ID를 타겟으로 지정
    SyncView:SendTargetRPC(funcName, { vObject.ControlUserId }, param)
end

-- 모든 클라이언트에 RPC 전송
function SendRPC_All(funcName, ...)
    local param = { ... }
    SyncView:SendRPC(funcName, RPCSendOption.All, param)
end

-- 다른 클라이언트들에게만 RPC 전송 (자신 제외)
function SendRPC_Others(funcName, ...)
    local param = { ... }
    SyncView:SendRPC(funcName, RPCSendOption.Others, param)
end

-- 특정 플레이어에게만 RPC 전송
function SendRPC_ToPlayer(userId, funcName, ...)
    local param = { ... }
    SyncView:SendTargetRPC(funcName, { userId }, param)
end

-- RPC로 호출될 함수
function MyRPCFunction(param1, param2)
    Debug.Log("RPC 수신: " .. tostring(param1) .. ", " .. tostring(param2))
end

-- 사용 예시
function DoSomething()
    -- 내가 소유자인지 확인
    if vObject.IsMine then
        -- 소유자만 실행
        SendRPC_All("MyRPCFunction", "Hello", 123)
    end
end

-- 소유권 요청 예시
function RequestOwnership()
    if not vObject.IsMine then
        vObject:RequestControlUserIsMine()
    end
end
```

### 상태 동기화

```lua
function sendSyncUpdate()
    local syncTable = {}
    syncTable[1] = currentStep
    syncTable[2] = isActive
    syncTable[3] = timer
    syncTable[4] = playerCount
    
    return syncTable
end

function receiveSyncUpdate(syncTable)
    if syncTable == nil then return end
    
    currentStep = syncTable[1]
    isActive = syncTable[2]
    timer = syncTable[3]
    playerCount = syncTable[4]
end

function onSyncViewInitialized()
    -- 동기화 초기화 시 호출
    if avatarVivenBridge.GetIsMine() then
        -- 호스트인 경우
        InitializeAsHost()
    else
        -- 클라이언트인 경우
        InitializeAsClient()
    end
end

function onOwnershipChanged(isMine)
    -- 소유권 변경 시 호출
    if isMine then
        Debug.Log("소유권 획득")
    else
        Debug.Log("소유권 상실")
    end
end
```

---

## 성능 최적화

### Update 함수 최적화

```lua
-- ❌ 나쁜 예: 매 프레임마다 무거운 연산
function update()
    local nearbyObjects = FindAllNearbyObjects()  -- 무거운 연산
    ProcessObjects(nearbyObjects)
end

-- ✅ 좋은 예: 타이머 기반 실행
local updateTimer = 0
local updateInterval = 0.5  -- 0.5초마다 실행

function update()
    updateTimer = updateTimer + Time.deltaTime
    
    if updateTimer >= updateInterval then
        local nearbyObjects = FindAllNearbyObjects()
        ProcessObjects(nearbyObjects)
        updateTimer = updateTimer - updateInterval
    end
end

-- ✅ 더 좋은 예: 조건부 실행
function update()
    -- 비활성 상태면 아예 실행하지 않음
    if not isActive then return end
    
    updateTimer = updateTimer + Time.deltaTime
    
    if updateTimer >= updateInterval then
        PerformHeavyOperation()
        updateTimer = 0
    end
end
```

### 메모리 관리

```lua
-- 참조 해제 패턴
function onDestroy()
    -- 오브젝트 참조 해제
    myObject = nil
    targetObject = nil
    
    -- 코루틴 중단
    if myCoroutine ~= nil then
        self:StopCoroutine(myCoroutine)
        myCoroutine = nil
    end
    
    -- 트윈 정리
    if moveTween ~= nil then
        self:KillTween(moveTween, true)
        moveTween = nil
    end
    
    -- 이벤트 등록 해제
    event:unregisterEvent("MyEvent", OnMyEvent)
end

-- 테이블 초기화
function ClearTable()
    myTable = {}  -- 기존 테이블 참조 해제
end
```

### 조건부 실행

```lua
function update()
    -- 여러 조건 체크를 초반에 배치
    if not isGameActive then return end
    if playerCount == 0 then return end
    if isPaused then return end
    
    -- 실제 로직은 조건을 통과한 경우에만 실행
    UpdateGameLogic()
end
```

---

## 실전 예제

### 예제 1: 순차 작업 시스템

```lua
local util = require 'xlua.util'
local currentStep = 0
local tasks = {}

function start()
    -- 작업 목록 정의
    table.insert(tasks, Task1)
    table.insert(tasks, Task2)
    table.insert(tasks, Task3)
    
    -- 작업 시작
    self:StartCoroutine(util.cs_generator(ExecuteTasks))
end

function ExecuteTasks()
    for i, task in ipairs(tasks) do
        currentStep = i
        Debug.Log("작업 " .. i .. " 시작")
        
        -- 작업 실행 (yield 반환 가능)
        coroutine.yield(task())
        
        Debug.Log("작업 " .. i .. " 완료")
    end
    
    Debug.Log("모든 작업 완료")
end

function Task1()
    Debug.Log("Task1 실행 중...")
    coroutine.yield(WaitForSeconds(2))
end

function Task2()
    Debug.Log("Task2 실행 중...")
    coroutine.yield(WaitUntil(function()
        return someCondition == true
    end))
end

function Task3()
    Debug.Log("Task3 실행 중...")
    coroutine.yield(WaitForSeconds(1))
end
```

### 예제 2: 타이머 시스템

```lua
local timers = {}

function CreateTimer(name, duration, callback)
    timers[name] = {
        duration = duration,
        elapsed = 0,
        callback = callback,
        isActive = true
    }
end

function update()
    for name, timer in pairs(timers) do
        if timer.isActive then
            timer.elapsed = timer.elapsed + Time.deltaTime
            
            if timer.elapsed >= timer.duration then
                -- 타이머 완료
                timer.callback()
                timers[name] = nil  -- 타이머 제거
            end
        end
    end
end

-- 사용 예시
function start()
    CreateTimer("Spawn", 5.0, function()
        Debug.Log("5초 후 스폰")
        SpawnObject()
    end)
    
    CreateTimer("GameEnd", 60.0, function()
        Debug.Log("게임 종료")
        EndGame()
    end)
end
```

### 예제 3: 상태 머신

```lua
local State = {
    IDLE = "idle",
    MOVING = "moving",
    ATTACKING = "attacking",
    DEAD = "dead"
}

local currentState = State.IDLE
local stateHandlers = {}

function start()
    -- 상태별 핸들러 등록
    stateHandlers[State.IDLE] = HandleIdleState
    stateHandlers[State.MOVING] = HandleMovingState
    stateHandlers[State.ATTACKING] = HandleAttackingState
    stateHandlers[State.DEAD] = HandleDeadState
end

function update()
    local handler = stateHandlers[currentState]
    if handler then
        handler()
    end
end

function ChangeState(newState)
    if currentState ~= newState then
        Debug.Log("상태 변경: " .. currentState .. " -> " .. newState)
        OnStateExit(currentState)
        currentState = newState
        OnStateEnter(currentState)
    end
end

function OnStateEnter(state)
    if state == State.MOVING then
        Debug.Log("이동 시작")
    elseif state == State.ATTACKING then
        Debug.Log("공격 시작")
    end
end

function OnStateExit(state)
    if state == State.MOVING then
        Debug.Log("이동 종료")
    end
end

function HandleIdleState()
    -- IDLE 상태 로직
end

function HandleMovingState()
    -- MOVING 상태 로직
end

function HandleAttackingState()
    -- ATTACKING 상태 로직
end

function HandleDeadState()
    -- DEAD 상태 로직
end
```

### 예제 4: 오브젝트 풀링

```lua
local objectPool = {}
local poolSize = 10

function start()
    InitializePool()
end

function InitializePool()
    for i = 1, poolSize do
        local obj = GameObject.Instantiate(prefab)
        obj:SetActive(false)
        obj.transform.parent = self.transform
        table.insert(objectPool, obj)
    end
    
    Debug.Log("오브젝트 풀 초기화 완료: " .. poolSize .. "개")
end

function GetPooledObject()
    for i, obj in ipairs(objectPool) do
        if not obj.activeSelf then
            return obj
        end
    end
    
    -- 풀에 사용 가능한 오브젝트가 없으면 새로 생성
    Debug.Log("풀 확장")
    local newObj = GameObject.Instantiate(prefab)
    newObj.transform.parent = self.transform
    table.insert(objectPool, newObj)
    return newObj
end

function ReturnToPool(obj)
    obj:SetActive(false)
    obj.transform.position = Vector3(0, -100, 0)  -- 화면 밖으로 이동
end

-- 사용 예시
function SpawnObject()
    local obj = GetPooledObject()
    obj:SetActive(true)
    obj.transform.position = spawnPoint.transform.position
end
```

---

## 디버깅 팁

### 로그 출력

```lua
function DebugLog()
    -- 기본 로그
    Debug.Log("일반 메시지")
    
    -- 변수 출력
    Debug.Log("변수 값: " .. tostring(myVariable))
    
    -- 조건부 로그
    if isDebugMode then
        Debug.Log("디버그 모드: " .. Time.time)
    end
end
```

### Nil 체크

```lua
function SafeAccess()
    -- nil 체크 패턴
    if myObject ~= nil then
        myObject:DoSomething()
    else
        Debug.Log("myObject가 nil입니다")
    end
    
    -- 컴포넌트 안전 접근
    local component = self:GetComponent(typeof(Rigidbody))
    if component == nil then
        Debug.Log("Rigidbody 컴포넌트를 찾을 수 없습니다")
        return
    end
    
    component.velocity = Vector3.zero
end
```

---

## 추가 자료

이 가이드와 함께 다음 문서들을 참고하세요:
- [AI NPC GUIDE](AI%20NPC%20GUIDE.md) - AI NPC 특화 기능
- [VIVEN SDK API 문서](https://wiki.viven.app/api) - VIVEN의 SDK API 사용 가이드

---

**참고**: 이 가이드는 실제 프로젝트 경험을 바탕으로 작성되었습니다. 프로젝트 요구사항에 맞게 패턴을 변형하여 사용하세요.
