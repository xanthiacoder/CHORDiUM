local Class = require "lib.Class"
local TS = Class:extend_as("TrackSettings")

local opts = {
	[1] = {
		name = "Reverb Send",
		default = 0,
		cc = 91
	},

	[2] = {
		name = "Volume",
		cc = 7
	},

	[3] = {
		name = "Pan",
		cc = 10
	},

	[4] = {
		name = "Portamento",
		toggle = true,
		param = "glide",
		value = false
	}
}

function TS:new()
	self.start_x = 215
	self.start_y = 149
	self.val_x = 345
	self.val_width = 70
	self.line_height = 32
	self.font_width = Core.font:getWidth("A")
	self.font_height = Core.font:getHeight("A")
end

function TS:draw()
	for i, opt in ipairs(opts) do
		local y = self.start_y + ((i-1) * self.line_height)
		love.graphics.setColor(Core.col[12])
		love.graphics.print(opt.name, self.start_x, y)
		love.graphics.setColor(1, 1, 1)
		if opt.toggle then
			love.graphics.print(muse.tracks[muse.current_track][opt.param] and "ON" or "OFF", self.val_x, y)
		else
			love.graphics.print(muse.tracks[muse.current_track].cc[opt.cc], self.val_x, y)
		end
	end
end

function TS:mousepressed(mx, my, btn)
    if btn == 1 then
        for i, opt in ipairs(opts) do
            local line_y = (self.start_y-6) + (i - 1) * self.line_height
            
            local x1 = self.val_x
            local x2 = self.val_x + self.val_width
            
            if mx >= x1 and mx <= x2
               and my >= line_y
               and my <= (line_y + self.line_height) then
               
               if opt.toggle then
               		muse.tracks[muse.current_track][opt.param] = not muse.tracks[muse.current_track][opt.param]
               		return
               	end
               	
               local cc_num = opt.cc
               
               Prompt.init("Set value for " .. opt.name .. ":", function(text)
					local num = tonumber(text)
					if num then
						num = math.min(num, 127)
						num = math.max(num, 0)

						muse:cc(muse.current_track, cc_num, num)
					end
				end)
               
               break
            end
        end
    end
end

return TS