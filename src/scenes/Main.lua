local Class = require "lib.Class"
local Main = Class:extend_as("Main")

local lg = love.graphics

local background = lg.newImage("res/background.png")

Prompt = require "scenes.Prompt"
local vk = require("lib.VirtualKeyboard")()
local PianoRoll = require "scenes.PianoRoll"
local TrackBar = require "scenes.TrackBar"
local TrackSettings = require "scenes.TrackSettings"

function Main:new(...)
	self.curr_preset = 1
	self.piano_roll = PianoRoll()
	self.track_bar = TrackBar()
	self.track_settings = TrackSettings()
	self.option_return_to_last_pos = true
	muse:get_piano_roll(self.piano_roll, vk)
end

function Main:update(dt)
end

function Main:draw()
	lg.setColor(1, 1, 1)
	lg.draw(background, 0, 0)
	lg.print(muse.last_event[1] .. ", " .. muse.last_event[2], 940, 34)

	self.track_bar:draw()
	self.track_settings:draw()
	self.piano_roll:draw()

	Prompt.draw()
end

function Main:keypressed(key)
	if Prompt.visible then
		Prompt.keypressed(key)
		return
	end

	if love.keyboard.isDown("lctrl") then
		if key == "return" then
			muse:add_track()

		elseif key == "right" then
			muse:next_preset(muse.current_track)

		elseif key == "left" then
			muse:prev_preset(muse.current_track)

		elseif key == "e" then
			Prompt.init("Export project as: ", function(text)
				if text and #text > 0 then
					muse:export_wav(text .. ".wav")
				end
			end)
		elseif key == "b" then
			Prompt.init("Enter song BPM (Beats Per Minute): ", function(text)
				local num = tonumber(text)
				if num then
					muse.bpm = num
				end
			end)

		elseif key == "s" then
			--muse:save("test")
			Prompt.init("Save project as: ", function(text)
				if text and #text > 0 then
					print("Saved project => " .. text .. ".muse")
					muse:save(text)
				end
			end, muse.loaded_song or nil)

		elseif key == "l" then
			Prompt.init("Load project: ", function(text)
				if text and #text > 0 then
					muse:load(text)
				end
			end)
			
		-- selection stuff
		-- deselect, copy + paste
		elseif key == "d" then
			 self.piano_roll:deselect_all()
		elseif key == "c" then
            -- copy selected notes
            self.piano_roll:copy_selected_notes()
        elseif key == "v" then
            self.piano_roll:paste_notes_at_mouse()
        end
    elseif love.keyboard.isDown("lalt") then
    	if key == "s" then
    		muse:toggle_solo(muse.current_track)
    	end
    elseif key == "escape" then
    	 self.piano_roll:deselect_all()
    	 Prompt.hide()
    elseif key == "delete" then
    	self.piano_roll:delete_selected_notes()
	elseif key == "space" then
		if muse.is_playing then
			muse:stop_playback()
			if self.option_return_to_last_pos and self.last_playhead_x then
				self.piano_roll.playhead_x = self.last_playhead_x
				self.piano_roll:ensure_playhead_visible()
			end
		else
			self.last_playhead_x = self.piano_roll.playhead_x
			muse:start_playback_from_playhead()
			--muse:start_playback(muse.current_track)
		end
	elseif key == "backspace" then
		muse:stop_playback()
		self.piano_roll.playhead_x = 0
		self.piano_roll:ensure_playhead_visible()
	else
		vk:keypressed(key)
	end
end

function Main:textinput(text)
	if Prompt.visible then Prompt.textinput(text) end
end

function Main:keyreleased(key)
	vk:keyreleased(key)
end

function Main:mousepressed(x, y, btn)
	if muse.is_playing then muse:stop_playback() end
	self.track_settings:mousepressed(x, y, btn)
	self.piano_roll:mousepressed(x, y, btn)
	self.track_bar:mousepressed(x, y, btn)
end

function Main:mousereleased(x, y, btn)
	self.piano_roll:mousereleased(x, y, btn)
end

function Main:mousemoved(x, y, dx, dy)
	self.piano_roll:mousemoved(x, y, dx, dy)
end

return Main
