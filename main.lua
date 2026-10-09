local Audio = require("src.audio")

local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 600
local WINNING_SCORE = 5

function love.load()
    love.window.setTitle("Pong Game")
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT, { vsync = true })

    -- 폰트
    fontLarge = love.graphics.newFont(32)
    fontNormal = love.graphics.newFont(16)

    -- 오디오 모듈 초기화 및 BGM 시작
    Audio.init()
    Audio.playBGM('main')

    -- 색상 팔레트
    colors = {
        background = { 0.08, 0.09, 0.13 },
        centerLine = { 0.25, 0.30, 0.42, 0.4 },
        paddle1    = { 0.20, 0.78, 0.95 },
        paddle2    = { 1.00, 0.32, 0.46 },
        ball       = { 1.00, 0.88, 0.35 },
        textWhite  = { 0.95, 0.96, 0.98 },
        textSub    = { 0.55, 0.60, 0.70 }
    }

    -- 상태 머신 변수 ('start' | 'play' | 'done')
    gameState = 'start'

    -- 점수 및 승자
    score1 = 0
    score2 = 0
    winningPlayer = 0

    -- 게임오버 사운드 딜레이 연출 변수
    gameOverDelay = 0.35
    gameOverTimer = 0
    hasPlayedEndSound = false

    -- 패들 객체
    paddle1 = { x = 30, y = 250, width = 15, height = 80, speed = 400 }
    paddle2 = { x = WINDOW_WIDTH - 45, y = 250, width = 15, height = 80, speed = 350 }

    -- AI 설정 변수
    aiReactionDelay = 0.15
    aiTimer = 0
    aiCanReact = false
    aiMaxOffset = 25
    aiTargetOffset = 0

    resetBall()
end

function generateAIOffset()
    aiTargetOffset = math.random(-aiMaxOffset, aiMaxOffset)
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

    aiTimer = 0
    aiCanReact = false
    aiTargetOffset = 0
end

function checkWinner()
    if score1 >= WINNING_SCORE then
        winningPlayer = 1
        gameState = 'done'
        Audio.pauseBGM('main')
        gameOverTimer = 0
        hasPlayedEndSound = false
    elseif score2 >= WINNING_SCORE then
        winningPlayer = 2
        gameState = 'done'
        Audio.pauseBGM('main')
        gameOverTimer = 0
        hasPlayedEndSound = false
    else
        resetBall()
    end
end

function checkCollision(a, b)
    return a.x < b.x + b.width and
           a.x + a.width > b.x and
           a.y < b.y + b.height and
           a.y + a.height > b.y
end

function love.update(dt)
    -- 게임오버 연출 상태 처리
    if gameState == 'done' then
        if not hasPlayedEndSound then
            gameOverTimer = gameOverTimer + dt
            if gameOverTimer >= gameOverDelay then
                hasPlayedEndSound = true
                if winningPlayer == 1 then
                    Audio.play('win', { overlap = true })
                else
                    Audio.play('lose', { overlap = true })
                end
            end
        end
        return
    end

    if gameState ~= 'play' then
        return
    end

    -- 1. 플레이어 입력 (W/S 또는 방향키)
    if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
        paddle1.y = math.max(0, paddle1.y - paddle1.speed * dt)
    elseif love.keyboard.isDown('s') or love.keyboard.isDown('down') then
        paddle1.y = math.min(WINDOW_HEIGHT - paddle1.height, paddle1.y + paddle1.speed * dt)
    end

    -- 2. AI 패들 지연 반응 및 타점 오차 추적
    local deadzone = 10
    local ballCenterY = ball.y + ball.height / 2
    local targetPaddleY = (paddle2.y + paddle2.height / 2) + aiTargetOffset

    if ball.dx > 0 and ball.x > (WINDOW_WIDTH / 2) then
        if not aiCanReact then
            aiTimer = aiTimer + dt
            if aiTimer >= aiReactionDelay then
                aiCanReact = true
                generateAIOffset()
            end
        end
    else
        aiTimer = 0
        aiCanReact = false
    end

    if aiCanReact then
        if ballCenterY < targetPaddleY - deadzone then
            paddle2.y = math.max(0, paddle2.y - paddle2.speed * dt)
        elseif ballCenterY > targetPaddleY + deadzone then
            paddle2.y = math.min(WINDOW_HEIGHT - paddle2.height, paddle2.y + paddle2.speed * dt)
        end
    else
        local paddleCenterY = paddle2.y + paddle2.height / 2
        local screenCenterY = WINDOW_HEIGHT / 2
        if paddleCenterY < screenCenterY - deadzone then
            paddle2.y = paddle2.y + (paddle2.speed * 0.3) * dt
        elseif paddleCenterY > screenCenterY + deadzone then
            paddle2.y = paddle2.y - (paddle2.speed * 0.3) * dt
        end
    end

    -- 3. 공 이동
    ball.x = ball.x + ball.dx * dt
    ball.y = ball.y + ball.dy * dt

    -- 상하단 벽 반사
    if ball.y <= 0 then
        ball.y = 0
        ball.dy = -ball.dy
    elseif ball.y >= WINDOW_HEIGHT - ball.height then
        ball.y = WINDOW_HEIGHT - ball.height
        ball.dy = -ball.dy
    end

    -- 4. 패들 충돌 및 각도 계산
    local maxDy = 350

    if checkCollision(ball, paddle1) then
        ball.x = paddle1.x + paddle1.width
        ball.dx = -ball.dx * 1.05
        local hitFactor = (ball.y + ball.height / 2 - (paddle1.y + paddle1.height / 2)) / (paddle1.height / 2)
        ball.dy = math.max(-1, math.min(1, hitFactor)) * maxDy

        -- 타격음 (약간의 피치 변화 부여)
        Audio.play('hit', { overlap = true, pitch = math.random(95, 105) / 100 })
    end

    if checkCollision(ball, paddle2) then
        ball.x = paddle2.x - ball.width
        ball.dx = -ball.dx * 1.05
        local hitFactor = (ball.y + ball.height / 2 - (paddle2.y + paddle2.height / 2)) / (paddle2.height / 2)
        ball.dy = math.max(-1, math.min(1, hitFactor)) * maxDy

        Audio.play('hit', { overlap = true, pitch = math.random(95, 105) / 100 })
    end

    -- 5. 득점 판정
    if ball.x < 0 then
        Audio.play('miss')
        score2 = score2 + 1
        checkWinner()
    elseif ball.x > WINDOW_WIDTH then
        Audio.play('miss')
        score1 = score1 + 1
        checkWinner()
    end
end

function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    end

    if key == 'm' then
        Audio.toggleMute()
    end

    if gameState == 'start' then
        if key == 'space' or key == 'return' then
            gameState = 'play'
        end
    elseif gameState == 'done' then
        if key == 'space' or key == 'return' then
            Audio.stop('win')
            Audio.stop('lose')
            Audio.playBGM('main')

            score1 = 0
            score2 = 0
            winningPlayer = 0
            gameOverTimer = 0
            hasPlayedEndSound = false
            resetBall()
            gameState = 'play'
        end
    end
end

function love.draw()
    love.graphics.clear(colors.background)

    -- 중앙 구분선
    love.graphics.setColor(colors.centerLine)
    for y = 0, WINDOW_HEIGHT, 30 do
        love.graphics.rectangle('fill', WINDOW_WIDTH / 2 - 1, y, 2, 16, 2, 2)
    end

    -- 점수판
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(colors.paddle1)
    love.graphics.printf(score1, 0, 40, WINDOW_WIDTH / 2, "center")

    love.graphics.setColor(colors.paddle2)
    love.graphics.printf(score2, WINDOW_WIDTH / 2, 40, WINDOW_WIDTH / 2, "center")

    -- 패들과 공
    love.graphics.setColor(colors.paddle1)
    love.graphics.rectangle('fill', paddle1.x, paddle1.y, paddle1.width, paddle1.height, 4, 4)

    love.graphics.setColor(colors.paddle2)
    love.graphics.rectangle('fill', paddle2.x, paddle2.y, paddle2.width, paddle2.height, 4, 4)

    love.graphics.setColor(colors.ball)
    love.graphics.rectangle('fill', ball.x, ball.y, ball.width, ball.height, 3, 3)

    -- UI 오버레이
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

    -- 우측 상단 음소거 표시
    love.graphics.setFont(fontNormal)
    love.graphics.setColor(colors.textSub)
    if Audio.isMuted then
        love.graphics.printf("[BGM Muted] Press M", 0, 15, WINDOW_WIDTH - 20, "right")
    else
        love.graphics.printf("[BGM ON] Press M", 0, 15, WINDOW_WIDTH - 20, "right")
    end

    love.graphics.setColor(1, 1, 1, 1)
end