require "run"

function hex_to_color(hex, alpha)
    return { tonumber("0x" .. hex:sub(1,2)) / 255,
           tonumber("0x" .. hex:sub(3,4)) / 255,
           tonumber("0x" .. hex:sub(5,6)) / 255,
           alpha or 1 }
end

Core = {
	screen = { x = 1024, y = 768 },
	col = {
		[1] = { 0, 0, 0, 1 },
		[2] = hex_to_color("404a52"), -- row color (white notes)
		[3] = hex_to_color("5e6e7d"), -- bar (vertical line)
		[4] = hex_to_color("2baaec"), -- measure (vertical line)
		[5] = hex_to_color("303a42"), -- row color (black notes)
		[6] = hex_to_color("394449"), -- horizontal lines
		[7] = hex_to_color("4dcaca"), -- outline (selected)
		[8] = hex_to_color("b4bac3"), -- white text
		[9] = hex_to_color("4b4753"), -- black text
		[10] = hex_to_color("ff2e60"),-- playhead
		[11] = hex_to_color("1b232c"),-- outlines
		[12] = hex_to_color("4bc6fa"),-- color settings label
	},
	font = love.graphics.newFont("res/UbuntuMono-R.ttf", 18),
	font_large = love.graphics.newFont("res/UbuntuMono-R.ttf", 24)
}

love.graphics.setFont(Core.font)
Core.font_width = Core.font:getWidth("A")
Core.font_height = Core.font:getHeight("A")

local Res = require "lib.Tlfres"

function mousepos()
	return Res.getMousePosition(Core.screen.x, Core.screen.y)
end

-- set up the save directory
love.filesystem.createDirectory("soundfonts")
love.filesystem.createDirectory("saves")
love.filesystem.createDirectory("exports")

local function file_exists(file)
	return love.filesystem.getInfo(file)
end

local platform = love.system.getOS()

if platform ~= "Linux" and platform ~= "Windows" and platform ~= "OS X" then
	error("Lovebase will not run on " .. platform)
end

-- the default soundfont to load
local default_sf = "Zelda.sf2"

-- if the soundfont doesn't exist in the save directory we copy it from
-- files and store it there
if not file_exists("soundfonts/" .. default_sf) then
	local data = love.filesystem.read("files/" .. default_sf)
	love.filesystem.write("soundfonts/" .. default_sf, data)
	data = nil
end

-- do the same with the library itself since love
-- can't read libraries from the project folder

local libfile

if platform == "Linux" then
	libfile = "libfluidsynth.so"
elseif platform == "Windows" then
	libfile = "libfluidsynth-3.dll"
elseif platform == "OS X" then
	libfile = "libfluidsynth-3.dylib"
end

if not file_exists(libfile) then
	print(libfile .. " doesn't exist in save directory. Copying...")

	if platform == "Windows" then
		local files = love.filesystem.getDirectoryItems("files")
		for _, file in ipairs(files) do
			local ext = file:match("^.+%.(.+)$")
			if ext == "dll" then
				print("=> Copying " .. file)
				local libdata = love.filesystem.read("files/" .. file)
				love.filesystem.write(file, libdata)
				libdata = nil
			end
		end
	else
		local libdata = love.filesystem.read("files/" .. libfile)
		love.filesystem.write(libfile, libdata)
		libdata = nil
	end
end

-- it's global and I don't give a shit
-- muse gets used throughout the entire project and I ain't
-- passing contexts around all over the place
-- if it still bothers you, speak to my lawyer
muse = require("lib.Muse")(default_sf)

local windows = {
	[1] = require("scenes.Main")()
}

local current_window = 1

function love.update(dt)
	muse:update(dt)
	windows[current_window]:update(dt)
end

function love.draw()
	Res.beginRendering(Core.screen.x, Core.screen.y)
	windows[current_window]:draw()
	Res.endRendering()
end

function love.keypressed(key, sc)
	windows[current_window]:keypressed(key, sc)
end

function love.keyreleased(key, sc)
	windows[current_window]:keyreleased(key, sc)
end

function love.mousepressed(x, y, btn)
	local mx, my = mousepos()
	windows[current_window]:mousepressed(mx, my, btn)
end

function love.mousereleased(x, y, btn)
	local mx, my = mousepos()
	windows[current_window]:mousereleased(mx, my, btn)
end

function love.mousemoved(x, y, dx, dy)
	local mx, my = mousepos()
	windows[current_window]:mousemoved(mx, my, dx, dy)
end

function love.textinput(text)
	windows[current_window]:textinput(text)
end

function love.quit()
	muse:cleanup()
end
