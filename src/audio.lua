local Audio = {}

Audio.sounds = {}
Audio.music = {}

Audio.volume = {
    master = 1.0,
    sfx = 0.7,
    winLose = 1.0,
    bgm = 0.35
}

Audio.isMuted = false

function Audio.init()
    -- SFX 로드 (static 메모리 상주)
    Audio.sounds['hit']  = love.audio.newSource('assets/sounds/sfx/hit.wav', 'static')
    Audio.sounds['miss'] = love.audio.newSource('assets/sounds/sfx/miss.wav', 'static')
    Audio.sounds['win']  = love.audio.newSource('assets/sounds/ui/win.wav', 'static')
    Audio.sounds['lose'] = love.audio.newSource('assets/sounds/ui/lose.wav', 'static')
    Audio.sounds['dash'] = love.audio.newSource('assets/sounds/sfx/dash.ogg', 'static')

    Audio.sounds['hit']:setVolume(Audio.volume.sfx)
    Audio.sounds['miss']:setVolume(Audio.volume.sfx)
    Audio.sounds['win']:setVolume(Audio.volume.winLose)
    Audio.sounds['lose']:setVolume(Audio.volume.winLose)
    Audio.sounds['dash']:setVolume(Audio.volume.sfx)
    
    -- BGM 로드 (stream 디스크 스트리밍)
    -- 확장자가 mp3라면 'assets/sounds/bgm/bgm.mp3'로 변경
    local bgmPath = 'assets/sounds/bgm/bgm.ogg'
    if love.filesystem.getInfo(bgmPath) then
        Audio.music['main'] = love.audio.newSource(bgmPath, 'stream')
    elseif love.filesystem.getInfo('assets/sounds/bgm/bgm.mp3') then
        Audio.music['main'] = love.audio.newSource('assets/sounds/bgm/bgm.mp3', 'stream')
    end

    if Audio.music['main'] then
        Audio.music['main']:setLooping(true)
        Audio.music['main']:setVolume(Audio.volume.bgm)
    end

    love.audio.setVolume(Audio.volume.master)
end

-- 효과음 재생 함수 (overlap: 소리 끊김 방지 클론 재생 여부, pitch: 음높이 조절)
function Audio.play(name, options)
    local sound = Audio.sounds[name]
    if not sound then return end

    options = options or {}
    local instance = options.overlap and sound:clone() or sound

    if options.pitch then
        instance:setPitch(options.pitch)
    end

    if not options.overlap then
        instance:stop()
    end
    instance:play()
end

function Audio.stop(name)
    if Audio.sounds[name] then
        Audio.sounds[name]:stop()
    end
end

function Audio.playBGM(name)
    local bgm = Audio.music[name or 'main']
    if bgm then
        bgm:play()
    end
end

function Audio.pauseBGM(name)
    local bgm = Audio.music[name or 'main']
    if bgm then
        bgm:pause()
    end
end

function Audio.stopBGM(name)
    local bgm = Audio.music[name or 'main']
    if bgm then
        bgm:stop()
    end
end

function Audio.toggleMute()
    Audio.isMuted = not Audio.isMuted
    love.audio.setVolume(Audio.isMuted and 0 or Audio.volume.master)
end

return Audio