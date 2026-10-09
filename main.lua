-- 변수들을 함수 밖에서 미리 선언해 둡니다.
local baseBallSpeed = 300 -- 🔴 공의 초기 속도 (이 값을 기준으로 리셋)
local speedMultiplier = 1.06 -- 🔴 부딪힐 때마다 증가할 비율 (1.06 = 6% 증가)

-- 게임이 시작될 때 한 번만 실행되는 초기화 함수
function love.load()
    love.window.setMode(800, 600)
    love.window.setTitle("Lua Pong Game")

    -- 플레이어(패들) 속성
    player = {
        x = 50,
        y = 250,
        width = 20,
        height = 100,
        speed = 400
    }

    -- 공 속성
    ball = {
        x = 400,
        y = 300,
        size = 15,
        -- 처음에는 baseBallSpeed로 설정
        dx = baseBallSpeed, 
        dy = baseBallSpeed 
    }

    -- 🔴 [여기에 추가] AI(적) 패들 속성
    ai = {
        x = 730,      -- 화면 오른쪽에 배치 (800 끝에서 조금 안쪽)
        y = 250,
        width = 20,
        height = 100,
        speed = 280   -- 플레이어나 공보다 살짝 느리게 해야 이길 수 있습니다!
    }

    -- 🔴 [여기에 추가] 사운드 파일 로드하기
    -- "static"은 효과음처럼 짧은 소리를 한 번에 메모리에 올릴 때 씁니다.
    hitSound = love.audio.newSource("hit.wav", "static")
    missSound = love.audio.newSource("miss.wav", "static")

    -- 🔴 [여기에 추가] 점수 변수 초기화
    playerScore = 0
    aiScore = 0

    -- 🔴 [여기에 추가] 40픽셀 크기의 기본 폰트 생성
    largeFont = love.graphics.setNewFont(40)
    
    -- 🔴 [여기에 추가] 배경색을 어두운 남색(Dark Navy)으로 설정 (R, G, B)
    -- 각각 빨강 8%, 초록 8%, 파랑 20% 정도 섞은 색입니다.
    love.graphics.setBackgroundColor(0.08, 0.08, 0.2)
end

-- 🔴 공을 중앙으로 리셋하고 속도를 초기화하는 새로운 함수
function resetBall()
    ball.x = 400
    ball.y = 300
    -- 속도를 다시 초기 속도로 리셋 (방향은 랜덤으로 설정하는 것이 좋습니다.)
    if love.math.random() > 0.5 then
        ball.dx = baseBallSpeed
    else
        ball.dx = -baseBallSpeed
    end
    
    if love.math.random() > 0.5 then
        ball.dy = baseBallSpeed
    else
        ball.dy = -baseBallSpeed
    end
end

-- 매 프레임마다 화면을 갱신하는 함수 (dt는 프레임 간의 시간 차이)
function love.update(dt)
    -- 위/아래 방향키로 플레이어 조작
    if love.keyboard.isDown("up") then
        player.y = player.y - player.speed * dt
    elseif love.keyboard.isDown("down") then
        player.y = player.y + player.speed * dt
    end

    -- 플레이어가 화면 밖으로 나가지 않도록 고정
    if player.y < 0 then player.y = 0 end
    if player.y + player.height > 600 then player.y = 600 - player.height end

    -- 공 이동
    ball.x = ball.x + ball.dx * dt
    ball.y = ball.y + ball.dy * dt

-- 🔴 [여기에 추가] 공과 플레이어 패들의 충돌 판정 (AABB 충돌)
    -- 공의 왼쪽/오른쪽이 패들의 오른쪽/왼쪽과 겹치는지, 
    -- 공의 위/아래가 패들의 아래/위와 겹치는지 동시에 확인합니다.
    if ball.x < player.x + player.width and
       ball.x + ball.size > player.x and
       ball.y < player.y + player.height and
       ball.y + ball.size > player.y then
        
        hitSound:clone():play()
        -- 부딪히면 공의 x축 이동 방향을 반대로(오른쪽으로) 바꿉니다.
        ball.dx = -ball.dx
        
        -- 공이 패들 안으로 파고들어 버그가 생기는 것을 막기 위해 공을 패들 바로 바깥으로 밀어냅니다.
        ball.x = player.x + player.width

        -- 🔴 여기에 추가: 속도를 곱해줍니다!
        ball.dx = ball.dx * speedMultiplier
        ball.dy = ball.dy * speedMultiplier
    end

-- 🔴 [여기에 추가] AI 패들의 움직임 (공을 따라가기)
    -- 패들의 중심과 공의 중심 높이를 비교해서 위아래로 움직입니다.
    local aiCenter = ai.y + ai.height / 2
    local ballCenter = ball.y + ball.size / 2

    if aiCenter < ballCenter then
        ai.y = ai.y + ai.speed * dt -- 공이 아래에 있으면 아래로 이동
    elseif aiCenter > ballCenter then
        ai.y = ai.y - ai.speed * dt -- 공이 위에 있으면 위로 이동
    end

    -- AI 패들도 화면 밖으로 나가지 않도록 고정
    if ai.y < 0 then ai.y = 0 end
    if ai.y + ai.height > 600 then ai.y = 600 - ai.height end

    -- 🔴 [여기에 추가] 공과 AI 패들의 충돌 판정 (플레이어 충돌과 원리 동일)
    if ball.x < ai.x + ai.width and
       ball.x + ball.size > ai.x and
       ball.y < ai.y + ai.height and
       ball.y + ball.size > ai.y then
        
        hitSound:clone():play()
        -- 부딪히면 공을 왼쪽으로 튕겨냅니다.
        ball.dx = -ball.dx
        -- 이번엔 공이 AI 패들의 왼쪽 바깥으로 튕겨 나가야 하므로 위치를 조정합니다.
        ball.x = ai.x - ball.size

        -- 🔴 여기에 추가: 속도를 곱해줍니다!
        ball.dx = ball.dx * speedMultiplier
        ball.dy = ball.dy * speedMultiplier
    end

-- 공이 위/아래 벽에 부딪히면 튕기기 (y축 방향 반전)
    if ball.y < 0 or ball.y + ball.size > 600 then
        ball.dy = -ball.dy
    end
    
    -- 공이 좌/우 벽에 부딪히면 튕기기 (임시)
    if ball.x < 0 or ball.x + ball.size > 800 then
        ball.dx = -ball.dx
    end

    -- 🔴 [추가/수정] 공이 좌우 벽을 넘어갔을 때 (점수 발생 및 리셋)
    -- 왼쪽 벽을 넘어감 (AI 득점)
    if ball.x < 0 then
        aiScore = aiScore + 1
        missSound:clone():play()
        resetBall() -- 공 위치와 속도 초기화
    end
    
    -- 오른쪽 벽을 넘어감 (플레이어 득점)
    if ball.x + ball.size > 800 then
        playerScore = playerScore + 1
        missSound:clone():play()
        resetBall() -- 공 위치와 속도 초기화
    end
end

function love.draw()
    -- 1. 점수판 그리기 (흰색 물감)
    love.graphics.setColor(1, 1, 1) 
    love.graphics.setFont(largeFont)
    love.graphics.printf(playerScore .. " : " .. aiScore, 0, 30, 800, "center")

    -- 2. 플레이어 패들 그리기 (네온 시안/민트색 물감)
    love.graphics.setColor(0, 1, 1) -- Red 0, Green 1, Blue 1
    love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
    
    -- 3. AI 패들 그리기 (네온 핑크/핫핑크 물감)
    love.graphics.setColor(1, 0.2, 0.6) -- Red 1, Green 0.2, Blue 0.6
    love.graphics.rectangle("fill", ai.x, ai.y, ai.width, ai.height)
    
    -- 4. 공 그리기 (네온 옐로우 물감)
    love.graphics.setColor(1, 1, 0) -- Red 1, Green 1, Blue 0
    love.graphics.rectangle("fill", ball.x, ball.y, ball.size, ball.size)
end