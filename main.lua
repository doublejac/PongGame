-- 창 크기 상수
local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 600

-- 목표 점수
local WINNING_SCORE = 5

function love.load()
    love.window.setTitle("Pong Game")
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, { vsync = true })

    -- 감성적인 네온/다크 테마 팔레트 (RGB 0~1 정규화)
    colors = {
        background = { 0.08, 0.09, 0.13 },  -- 깊은 미드나이트 네이비
        centerLine = { 0.25, 0.30, 0.42, 0.4 }, -- 은은한 그리드 라인 (알파값 0.4)
        paddle1    = { 0.20, 0.78, 0.95 },  -- P1(플레이어): 청량한 시안/하늘색
        paddle2    = { 1.00, 0.32, 0.46 },  -- P2(AI): 세련된 네온 코랄 핑크
        ball       = { 1.00, 0.88, 0.35 },  -- 공: 밝은 레몬 옐로우
        textWhite  = { 0.95, 0.96, 0.98 },  -- 기본 메인 텍스트
        textSub    = { 0.55, 0.60, 0.70 }   -- 보조 안내 텍스트
    }

    -- 오디오 소스 로드 ("static"은 메모리에 상주시켜 지연 없이 재생)
    sounds = {
        hit = love.audio.newSource('hit.wav', 'static'),
        miss = love.audio.newSource('miss.wav', 'static'),
        win = love.audio.newSource('win.wav', 'static'),   -- 승리 팡파르/효과음
        lose = love.audio.newSource('lose.wav', 'static')  -- 패배 효과음
    }

    -- 배경음악 로드 ("stream" 모드는 디스크에서 실시간 스트리밍)
    music = love.audio.newSource('bgm.mp3', 'stream')
    music:setLooping(true)   -- 무한 반복 재생
    music:setVolume(0.5)     -- BGM 기본 볼륨 (0.0 ~ 1.0)
    music:play()             -- 게임 시작 시 자동 재생

    -- 마스터 볼륨 및 음소거 토글 상태
    isMuted = false
    masterVolume = 1.0
    love.audio.setVolume(masterVolume)

    -- 기본 폰트 설정
    fontLarge = love.graphics.newFont(32)
    fontNormal = love.graphics.newFont(16)

    -- 상태 머신 변수: 'start' | 'play' | 'done'
    gameState = 'start'

    -- 점수 및 승자
    score1 = 0
    score2 = 0
    winningPlayer = 0

    -- 패들 (P1: 좌측, P2/AI: 우측)
    paddle1 = { x = 30, y = 250, width = 15, height = 80, speed = 400 }
    paddle2 = { x = WINDOW_WIDTH - 45, y = 250, width = 15, height = 80, speed = 350 }
    
    -- AI 반응 지연 관련 변수
    aiReactionDelay = 0.15  -- 중앙선 통과 후 반응하기까지 걸리는 시간 (초 단위, 0.1 ~ 0.25 추천)
    aiTimer = 0             -- 지연 시간 카운팅 타이머
    aiCanReact = false      -- 현재 AI가 공에 반응할 수 있는 상태인지 여부
    
    -- AI 타점 오차(Offset) 변수
    -- 패들 절반 높이(paddle2.height / 2 = 40)를 고려하여 ±25픽셀 내외 오차 설정
    aiMaxOffset = 25
    aiTargetOffset = 0
    
    -- 승패 사운드 지연 관련 변수
    gameOverDelay = 0.4        -- BGM 정지 후 사운드 재생까지의 대기 시간(초)
    gameOverTimer = 0          -- 딜레이 카운팅 타이머
    hasPlayedEndSound = false  -- 사운드가 1회만 재생되도록 막는 플래그

    -- 공 초기화 함수 호출
    resetBall()
end

function resetBall()
    ball = {
        x = WINDOW_WIDTH / 2 - 5,
        y = WINDOW_HEIGHT / 2 - 5,
        width = 10,
        height = 10,
        dx = (math.random(2) == 1 and 1 or -1) * 300,
        dy = math.random(-150, 150)
    }

    -- 라운드 리셋 시 AI 반응 상태 초기화
    aiTimer = 0
    aiCanReact = false
    aiTargetOffset = 0
end

function love.update(dt)
    -- 승패 결정('done') 상태일 때 사운드 딜레이 처리
    if gameState == 'done' then
        if not hasPlayedEndSound then
            gameOverTimer = gameOverTimer + dt
            if gameOverTimer >= gameOverDelay then
                hasPlayedEndSound = true
                if winningPlayer == 1 then
                    sounds.win:stop()
                    sounds.win:play()
                elseif winningPlayer == 2 then
                    sounds.lose:stop()
                    sounds.lose:play()
                end
            end
        end
        return -- 공과 패들 이동 연산은 건너뜀
    end

    -- 타이틀 화면('start')일 때도 물리 연산 중단
    if gameState == 'start' then
        return
    end

    -- 2. 플레이어(P1) 조작 (W / S)
    if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
        paddle1.y = math.max(0, paddle1.y - paddle1.speed * dt)
    elseif love.keyboard.isDown('s') or love.keyboard.isDown('down') then
        paddle1.y = math.min(WINDOW_HEIGHT - paddle1.height, paddle1.y + paddle1.speed * dt)
    end

    -- ==========================================
    -- 3. AI 패들(P2) 지연 반응 및 타점 오차 로직
    -- ==========================================
    local deadzone = 10
    local ballCenterY = ball.y + ball.height / 2
    
    -- AI가 노리는 패들의 실제 타점 높이 (정중앙 + 랜덤 오차)
    local targetPaddleY = (paddle2.y + paddle2.height / 2) + aiTargetOffset

    -- 공이 AI 진영(중앙선 오른쪽)으로 넘어오고 있는 경우
    if ball.dx > 0 and ball.x > (WINDOW_WIDTH / 2) then
        if not aiCanReact then
            aiTimer = aiTimer + dt
            if aiTimer >= aiReactionDelay then
                aiCanReact = true
                -- 반응 시작 시 이번 랠리에서 노릴 타점 오프셋을 결정
                generateAIOffset()
            end
        end
    else
        aiTimer = 0
        aiCanReact = false
    end

    -- 추적 로직 (targetPaddleY를 기준으로 판단)
    if aiCanReact then
        if ballCenterY < targetPaddleY - deadzone then
            paddle2.y = math.max(0, paddle2.y - paddle2.speed * dt)
        elseif ballCenterY > targetPaddleY + deadzone then
            paddle2.y = math.min(WINDOW_HEIGHT - paddle2.height, paddle2.y + paddle2.speed * dt)
        end
    else
        -- 대기 상태: 천천히 화면 중앙 복귀 (복귀 시에는 오프셋 미적용)
        local paddleCenterY = paddle2.y + paddle2.height / 2
        local screenCenterY = WINDOW_HEIGHT / 2
        if paddleCenterY < screenCenterY - deadzone then
            paddle2.y = paddle2.y + (paddle2.speed * 0.3) * dt
        elseif paddleCenterY > screenCenterY + deadzone then
            paddle2.y = paddle2.y - (paddle2.speed * 0.3) * dt
        end
    end

    -- 4. 공 이동
    ball.x = ball.x + ball.dx * dt
    ball.y = ball.y + ball.dy * dt

    -- 상하단 벽 충돌
    if ball.y <= 0 then
        ball.y = 0
        ball.dy = -ball.dy
    elseif ball.y >= WINDOW_HEIGHT - ball.height then
        ball.y = WINDOW_HEIGHT - ball.height
        ball.dy = -ball.dy
    end

    -- ==========================================
    -- 패들 충돌 및 상대 타점 기반 반사 물리
    -- ==========================================
    local maxDy = 350 -- 모서리에 맞았을 때 꺾이는 최대 수직 속도

    -- 1. 플레이어 패들(paddle1) 충돌
    if checkCollision(ball, paddle1) then
        ball.x = paddle1.x + paddle1.width
        
        -- 수평 속도 반전 및 가속 (5%)
        ball.dx = -ball.dx * 1.05

        -- 충돌 지점 정규화 (-1.0 ~ 1.0)
        local ballCenterY = ball.y + ball.height / 2
        local paddle1CenterY = paddle1.y + paddle1.height / 2
        local hitFactor = (ballCenterY - paddle1CenterY) / (paddle1.height / 2)

        -- 패들 범위를 살짝 넘겨 닿은 경우를 대비해 -1 ~ 1 범위로 제한
        hitFactor = math.max(-1, math.min(1, hitFactor))

        -- 타격음 재생
        sounds.hit:stop()
        sounds.hit:play()

        -- hitFactor에 따라 dy 재계산
        ball.dy = hitFactor * maxDy
    end

    -- 2. AI 패들(paddle2) 충돌
    if checkCollision(ball, paddle2) then
        ball.x = paddle2.x - ball.width
        
        -- 수평 속도 반전 및 가속 (5%)
        ball.dx = -ball.dx * 1.05

        -- 충돌 지점 정규화 (-1.0 ~ 1.0)
        local ballCenterY = ball.y + ball.height / 2
        local paddle2CenterY = paddle2.y + paddle2.height / 2
        local hitFactor = (ballCenterY - paddle2CenterY) / (paddle2.height / 2)

        hitFactor = math.max(-1, math.min(1, hitFactor))

        -- 타격음 재생
        sounds.hit:stop()
        sounds.hit:play()

        -- hitFactor에 따라 dy 재계산
        ball.dy = hitFactor * maxDy
    end

    -- 5. 득점 판정 및 승리 조건 체크
    if ball.x < 0 then
        sounds.miss:stop()
        sounds.miss:play()
        
        score2 = score2 + 1
        checkWinner()
    elseif ball.x > WINDOW_WIDTH then
        sounds.miss:stop()
        sounds.miss:play()
        
        score1 = score1 + 1
        checkWinner()
    end
end

function checkWinner()
    if score1 >= WINNING_SCORE then
        winningPlayer = 1
        gameState = 'done'
        music:pause()               -- BGM 일시정지
        gameOverTimer = 0           -- 타이머 초기화
        hasPlayedEndSound = false   -- 재생 플래그 초기화

    elseif score2 >= WINNING_SCORE then
        winningPlayer = 2
        gameState = 'done'
        music:pause()               -- BGM 일시정지
        gameOverTimer = 0           -- 타이머 초기화
        hasPlayedEndSound = false   -- 재생 플래그 초기화

    else
        resetBall()
    end
end

-- AABB 충돌 체크 함수
function checkCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

-- AI 타점 오프셋을 새로 결정하는 함수
function generateAIOffset()
    -- -aiMaxOffset ~ +aiMaxOffset 범위의 난수 생성
    aiTargetOffset = math.random(-aiMaxOffset, aiMaxOffset)
end

function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    end

    -- 'm' 키로 전체 사운드 음소거/해제 토글
    if key == 'm' then
        isMuted = not isMuted
        if isMuted then
            love.audio.setVolume(0)
        else
            love.audio.setVolume(masterVolume)
        end
    end

    -- 상태 전이 키 입력 처리
    if gameState == 'start' then
        if key == 'space' or key == 'return' then
            gameState = 'play'
        end
    elseif gameState == 'done' then
        if key == 'space' or key == 'return' then
            sounds.win:stop()
            sounds.lose:stop()

            -- 타이머 및 플래그 초기화
            gameOverTimer = 0
            hasPlayedEndSound = false

            -- BGM 재개 (처음부터 재생하려면 music:seek(0) 추가)
            music:play()

            score1 = 0
            score2 = 0
            winningPlayer = 0
            resetBall()
            gameState = 'play'
        end
    end
end

function love.draw()
    -- 1. 배경 색상 채우기
    love.graphics.clear(colors.background)

    -- 2. 중앙 점선 (부드러운 구분선)
    love.graphics.setColor(colors.centerLine)
    for y = 0, WINDOW_HEIGHT, 30 do
        love.graphics.rectangle('fill', WINDOW_WIDTH / 2 - 1, y, 2, 16, 2, 2) -- 모서리 둥글게
    end

    -- 3. 점수판 표시 (각 진영 색상에 맞춰 렌더링)
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(colors.paddle1)
    love.graphics.printf(score1, 0, 40, WINDOW_WIDTH / 2, "center")

    love.graphics.setColor(colors.paddle2)
    love.graphics.printf(score2, WINDOW_WIDTH / 2, 40, WINDOW_WIDTH / 2, "center")

    -- 4. 패들 렌더링 (살짝 둥근 모서리 적용: rx=3, ry=3)
    love.graphics.setColor(colors.paddle1)
    love.graphics.rectangle('fill', paddle1.x, paddle1.y, paddle1.width, paddle1.height, 4, 4)

    love.graphics.setColor(colors.paddle2)
    love.graphics.rectangle('fill', paddle2.x, paddle2.y, paddle2.width, paddle2.height, 4, 4)

    -- 5. 공 렌더링 (둥근 사각형 또는 원형)
    love.graphics.setColor(colors.ball)
    love.graphics.rectangle('fill', ball.x, ball.y, ball.width, ball.height, 3, 3)

    -- 6. 상태별 UI 오버레이
    if gameState == 'start' then
        love.graphics.setFont(fontLarge)
        love.graphics.setColor(colors.ball)
        love.graphics.printf("PONG GAME", 0, WINDOW_HEIGHT / 2 - 70, WINDOW_WIDTH, "center")

        love.graphics.setFont(fontNormal)
        love.graphics.setColor(colors.textWhite)
        love.graphics.printf("Press SPACE to Start", 0, WINDOW_HEIGHT / 2 - 10, WINDOW_WIDTH, "center")
        
        love.graphics.setColor(colors.textSub)
        love.graphics.printf("Controls: W / S or UP / DOWN", 0, WINDOW_HEIGHT / 2 + 25, WINDOW_WIDTH, "center")

    elseif gameState == 'done' then
        love.graphics.setFont(fontLarge)
        if winningPlayer == 1 then
            love.graphics.setColor(colors.paddle1)
            love.graphics.printf("Player 1 Wins!", 0, WINDOW_HEIGHT / 2 - 50, WINDOW_WIDTH, "center")
        else
            love.graphics.setColor(colors.paddle2)
            love.graphics.printf("AI Wins!", 0, WINDOW_HEIGHT / 2 - 50, WINDOW_WIDTH, "center")
        end

        love.graphics.setFont(fontNormal)
        love.graphics.setColor(colors.textWhite)
        love.graphics.printf("Press SPACE to Restart", 0, WINDOW_HEIGHT / 2 + 15, WINDOW_WIDTH, "center")
    end

    -- 7. 우측 상단 음소거 상태
    love.graphics.setFont(fontNormal)
    love.graphics.setColor(colors.textSub)
    if isMuted then
        love.graphics.printf("[Muted] Press M", 0, 15, WINDOW_WIDTH - 20, "right")
    else
        love.graphics.printf("[Sound ON] Press M", 0, 15, WINDOW_WIDTH - 20, "right")
    end

    -- 다음 그리기를 위해 기본 흰색(불투명)으로 리셋
    love.graphics.setColor(1, 1, 1, 1)
end