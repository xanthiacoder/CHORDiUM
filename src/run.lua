local rate = 1 / 60
local accumulator = 0

function love.run()
    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    if love.timer then love.timer.step() end

    local dt = 0
    return function()
        if love.event then
            love.event.pump()
            for name, a, b, c, d, e, f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        return a or 0
                    end
                end
                love.handlers[name](a, b, c, d, e, f)
            end
        end

        if love.timer then dt = love.timer.step() end
        accumulator = accumulator + dt

        while accumulator >= rate do
            if love.update then love.update(rate) end
            accumulator = accumulator - rate
        end

        if love.graphics and love.graphics.isActive() then
            love.graphics.origin()
            love.graphics.clear(love.graphics.getBackgroundColor())
            if love.draw then love.draw() end
            love.graphics.present()
        end

        -- Sleep for remaining frame time
        if love.timer then
            local sleep_time = rate - love.timer.getDelta()
            if sleep_time > 0 then
                love.timer.sleep(sleep_time)
            end
        end
    end
end
