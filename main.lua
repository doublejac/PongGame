-- 창 크기 상수
local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 600

-- 목표 점수
local WINNING_SCORE = 5

function love.load()
    love.window.setTitle("Pong Game")
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, { vsync = true })

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
end

function love.update(dt)
    -- 1. 타이틀 화면 또는 게임오버 화면에서는 물리/이동 연산을 중지
    if gameState ~= 'play' then
        return
    end

    -- 2. 플레이어(P1) 조작 (W / S)
    if love.keyboard.isDown('w') then
        paddle1.y = math.max(0, paddle1.y - paddle1.speed * dt)
    elseif love.keyboard.isDown('s') then
        paddle1.y = math.min(WINDOW_HEIGHT - paddle1.height, paddle1.y + paddle1.speed * dt)
    end

    -- 3. 간단한 AI 패들(P2) 추적
    if ball.y < paddle2.y + paddle2.height / 2 then
        paddle2.y = math.max(0, paddle2.y - paddle2.speed * dt)
    elseif ball.y > paddle2.y + paddle2.height / 2 then
        paddle2.y = math.min(WINDOW_HEIGHT - paddle2.height, paddle2.y + paddle2.speed * dt)
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

    -- 패들 충돌 판정 (AABB 충돌)
    if checkCollision(ball, paddle1) then
        ball.x = paddle1.x + paddle1.width
        ball.dx = -ball.dx * 1.05 -- 속도 가속
    elseif checkCollision(ball, paddle2) then
        ball.x = paddle2.x - ball.width
        ball.dx = -ball.dx * 1.05
    end

    -- 5. 득점 판정 및 승리 조건 체크
    if ball.x < 0 then
        score2 = score2 + 1
        checkWinner()
    elseif ball.x > WINDOW_WIDTH then
        score1 = score1 + 1
        checkWinner()
    end
end

function checkWinner()
    if score1 >= WINNING_SCORE then
        winningPlayer = 1
        gameState = 'done'
    elseif score2 >= WINNING_SCORE then
        winningPlayer = 2
        gameState = 'done'
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

function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    end

    -- 상태 전이 키 입력 처리
    if gameState == 'start' then
        if key == 'space' or key == 'return' then
            gameState = 'play'
        end
    elseif gameState == 'done' then
        if key == 'space' or key == 'return' then
            -- 점수 및 공 리셋 후 다시 게임 시작
            score1 = 0
            score2 = 0
            winningPlayer = 0
            resetBall()
            gameState = 'play'
        end
    end
end

function love.draw()
    -- 점수판 표시 (모든 상태 공통)
    love.graphics.setFont(fontLarge)
    love.graphics.printf(score1, 0, 50, WINDOW_WIDTH / 2, "center")
    love.graphics.printf(score2, WINDOW_WIDTH / 2, 50, WINDOW_WIDTH / 2, "center")

    -- 패들과 공 렌더링
    love.graphics.rectangle('fill', paddle1.x, paddle1.y, paddle1.width, paddle1.height)
    love.graphics.rectangle('fill', paddle2.x, paddle2.y, paddle2.width, paddle2.height)
    love.graphics.rectangle('fill', ball.x, ball.y, ball.width, ball.height)

    -- 중앙 점선 그리기
    love.graphics.setColor(1, 1, 1, 0.2)
    for y = 0, WINDOW_HEIGHT, 30 do
        love.graphics.rectangle('fill', WINDOW_WIDTH / 2 - 1, y, 2, 15)
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- 상태별 UI 오버레이
    if gameState == 'start' then
        love.graphics.setFont(fontLarge)
        love.graphics.printf("PONG GAME", 0, WINDOW_HEIGHT / 2 - 60, WINDOW_WIDTH, "center")
        love.graphics.setFont(fontNormal)
        love.graphics.printf("Press SPACE to Start", 0, WINDOW_HEIGHT / 2, WINDOW_WIDTH, "center")
        love.graphics.printf("Controls: W / S", 0, WINDOW_HEIGHT / 2 + 30, WINDOW_WIDTH, "center")

    elseif gameState == 'done' then
        love.graphics.setFont(fontLarge)
        local winnerText = (winningPlayer == 1) and "Player 1 Wins!" or "AI Wins!"
        love.graphics.printf(winnerText, 0, WINDOW_HEIGHT / 2 - 50, WINDOW_WIDTH, "center")
        love.graphics.setFont(fontNormal)
        love.graphics.printf("Press SPACE to Restart", 0, WINDOW_HEIGHT / 2 + 10, WINDOW_WIDTH, "center")
    end
end