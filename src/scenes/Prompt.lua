local Prompt = {}

local prompt_img = love.graphics.newImage("res/prompt.png")

function Prompt.init(str, cb, add_text, x, y)
	Prompt.x = x or 372
	Prompt.y = y or 291
	Prompt.w = 841
	Prompt.h = 238
	Prompt.str = str
	Prompt.visible = false
	Prompt.cb = cb
	Prompt.text = add_text or ""
	Prompt.show()
end

function Prompt.show()
	Prompt.visible = true
end

function Prompt.hide()
	Prompt.visible = false
end

function Prompt.draw()
	if Prompt.visible then
		love.graphics.setFont(Core.font_large)
		love.graphics.draw(prompt_img, Prompt.x, Prompt.y)

		love.graphics.setColor(1, 1, 1)
		love.graphics.print(Prompt.str, 468, 326)
		love.graphics.setColor(Core.col[11])
		love.graphics.print(Prompt.text, 478, 436)
		love.graphics.setColor(1, 1, 1)
		love.graphics.setFont(Core.font)
	end
end

function Prompt.textinput(text)
	Prompt.text = Prompt.text .. text
end

function Prompt.keypressed(key)
	if key == "escape" then
		Prompt.hide()

	elseif key == "return" then
		local text = Prompt.text
		-- convert to number if it's a number
		if tonumber(text) then
			text = tonumber(text)
		end
		Prompt.cb(text)
		Prompt.hide()

	elseif key == "backspace" then
		if #Prompt.text > 0 then Prompt.text = Prompt.text:sub(1, -2) end
	end
end

return Prompt