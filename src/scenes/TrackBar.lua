local Class = require "lib.Class"
local TrackBar = Class:extend_as("TrackBar")

local track_spr = love.graphics.newImage("res/tracks.png")
local track_q = {
	[1]	= love.graphics.newQuad(0, 0, 206, 40, track_spr:getDimensions()), -- white
	[2] = love.graphics.newQuad(0, 40, 206, 40, track_spr:getDimensions()), -- blue
	[3] = love.graphics.newQuad(0, 80, 206, 40, track_spr:getDimensions()), -- active
}

function TrackBar:new()
	self.start_x = 1
	self.start_y = 139
	self.start_text = 24
	-- width and height of each track item
	self.w = 207
	self.h = 39
	self.limit = 138
end

function TrackBar:mousepressed(x, y, btn)
    if btn == 1 then
        if x >= self.start_x and x <= (self.start_x + self.w) then
            if y >= self.start_y then
                local index = math.floor((y - self.start_y) / self.h) + 1

                if index >= 1 and index <= #muse.tracks then
                    muse.current_track = muse.tracks[index].channel
                end
            end
        end
    end
end

function TrackBar:draw()
	for i,track in ipairs(muse.tracks) do
		local y = self.start_y+((i-1)*self.h)
		if muse.current_track == track.channel then
			love.graphics.draw(track_spr, track_q[3], self.start_x, y)
			love.graphics.setColor(Core.col[9])
			love.graphics.printf(track.name, self.start_text, y+8, self.limit, "center")
		else
			--love.graphics.draw(track_spr, track_q[i % 2 == 0 and 2 or 1], self.start_x, y)
			love.graphics.draw(track_spr, track_q[1], self.start_x, y)
			love.graphics.setColor(Core.col[8])
			love.graphics.printf(track.name, self.start_text, y+8, self.limit, "center")
			love.graphics.setColor(1, 1, 1)
		end

		if muse.solo_track and track.channel == muse.solo_track then
			love.graphics.print("S", 184, y+8)
		end

		love.graphics.setColor(track.color)
		love.graphics.rectangle("fill", self.start_x, y, 16, 38)
		love.graphics.setColor(1, 1, 1)
	end
end

return TrackBar