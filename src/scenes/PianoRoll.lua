local Class = require "lib.Class"
local PianoRoll = Class:extend_as("PianoRoll")

local piano_img = love.graphics.newImage("res/piano.png")

local BLACK_KEY_INDICES = { [1]=true, [3]=true, [5]=true, [8]=true, [10]=true }

function PianoRoll:new()
    -- positions and sizes
    self.start_x     = 517
    self.start_y     = 139
    self.piano_x     = 417
    self.bar_width   = 96
    self.note_height = 16
    self.num_measures  = 12
    self.measure_width = self.bar_width * 4
    self.snap_divisions_per_beat = 4  -- 16th note
    self.num_octaves   = 8
    local scrollbar_height = 16

    self.max_y_draw = Core.screen.y - scrollbar_height
    self.clipboard_notes = {}
    
    self.playhead_x = 0

    self.playhead_dragging = false
    self.playhead_drag_offset = 0

    self.screen_width  = Core.screen.x
    self.screen_height = Core.screen.y
    
    self.visible_width  = self.screen_width - self.start_x
    self.visible_height = self.max_y_draw - self.start_y
    
    -- scrolling
    self.scroll_x = 0
    self.scroll_y = 0
    
    -- total content size
    self.total_width  = self.num_measures * self.measure_width
    self.total_height = (self.num_octaves * 12) * self.note_height
    
    -- scrollbars
    self.scrollbar_h = {
        x = self.start_x,
        y = self.max_y_draw + 2,
        w = self.visible_width,
        h = 16,
        thumb_x = 0, thumb_w = 0,
        is_dragging = false,
        drag_offset = 0,
    }

    self.scrollbar_v = {
        x = self.start_x + self.visible_width - 16, -- place near the right edge
        y = self.start_y,
        w = 16,
        h = self.visible_height,
        thumb_y = 0, thumb_h = 0,
        is_dragging = false,
        drag_offset = 0,
    }
    
    -- for note editing
    self.drag_mode = nil
    self.drag_note = nil
    self.drag_offset_x = 0
    self.drag_original_x = 0
    self.drag_original_w = 0
    self.drag_start_mouse_x = 0

    -- for selection
    self.selecting = false
	self.select_start_x = 0
	self.select_start_y = 0
	self.select_end_x   = 0
	self.select_end_y   = 0

    -- random shit I tacked on later
    self.nav_y = 80

    self.selected_notes = {}

    
    self:set_scroll_y_from_thumb(280) -- move it down a bit so you don't start at a high frequency
    self:update_thumb_positions()
end

function PianoRoll:is_alt_down()
    return love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")
end

function PianoRoll:snap_x(raw_x)
    local snap_size = self.bar_width / self.snap_divisions_per_beat
    local snapped = math.floor(raw_x / snap_size + 0.5) * snap_size
    return snapped
end

------------------------------------------------------------------------------
--                          NOTE STUFF
------------------------------------------------------------------------------

function PianoRoll:screen_to_roll(x, y)
    local roll_x = x - self.start_x + self.scroll_x
    local roll_y = y - self.start_y + self.scroll_y
    return roll_x, roll_y
end

function PianoRoll:screen_to_row(y)
    local _, roll_y = self:screen_to_roll(0, y)
    local row = math.floor(roll_y / self.note_height)
    return row
end

function PianoRoll:get_default_note_length()
    return self.bar_width / 2
end

function PianoRoll:get_note_rect(note)
    local nx = note.x
    local ny = note.row * self.note_height
    local nw = note.width
    local nh = self.note_height
    return nx, ny, nw, nh
end

function PianoRoll:point_in_note(note, px, py)
    local nx, ny, nw, nh = self:get_note_rect(note)
    return px >= nx and px <= (nx + nw) and py >= ny and py <= (ny + nh)
end

function PianoRoll:edge_hit_test(note, px, threshold)
    threshold = threshold or 5
    local nx, ny, nw, nh = self:get_note_rect(note)
    if math.abs(px - nx) <= threshold then
        return "left"
    elseif math.abs(px - (nx + nw)) <= threshold then
        return "right"
    end
    return nil
end

function PianoRoll:check_playhead_click(mx, my)
    local handle_size = 10
    local knob_screen_x = (self.start_x - self.scroll_x) + self.playhead_x
    local handle_x = knob_screen_x - (handle_size / 2)
    local handle_y = self.start_y - (handle_size + 4)
    
    if self:point_in_rect(mx, my, handle_x, handle_y, handle_size, handle_size) then
        self.playhead_dragging = true
        self.playhead_drag_offset = mx - knob_screen_x
        return true
    end

    return false
end

function PianoRoll:copy_selected_notes()
    self.clipboard_notes = {}
    for _, note in ipairs(self.selected_notes) do
        table.insert(self.clipboard_notes, {
            x      = note.x,
            row    = note.row,
            width  = note.width,
            pitch  = note.pitch,
        })
    end
end

function PianoRoll:paste_notes_at_mouse()
    if not self.clipboard_notes or #self.clipboard_notes == 0 then
        return
    end
    local mx, my = mousepos()
    local rx, ry = self:screen_to_roll(mx, my)

    local min_x = math.huge
    local min_row = math.huge
    for _, cn in ipairs(self.clipboard_notes) do
        if cn.x < min_x then min_x = cn.x end
        if cn.row < min_row then min_row = cn.row end
    end

    local dx = rx - min_x
    local dy_rows = math.floor((ry / self.note_height)) - min_row
    if dy_rows < 0 then dy_rows = 0 end

    local track = muse.tracks[muse.current_track]
    if not track.notes then track.notes = {} end

    self.selected_notes = {}

    for _, cn in ipairs(self.clipboard_notes) do
        local new_note = {
            x = cn.x + dx,
            row = cn.row,--cn.row + dy_rows,
            width = cn.width,
            pitch = cn.pitch,
        }
        table.insert(track.notes, new_note)
        table.insert(self.selected_notes, new_note)
    end
end

function PianoRoll:delete_selected_notes()
    local track = muse.tracks[muse.current_track]
    if not track.notes then return end

    local lookup = {}
    for _, sn in ipairs(self.selected_notes) do
        lookup[sn] = true
    end

    local new_notes = {}
    for _, note in ipairs(track.notes) do
        if not lookup[note] then
            table.insert(new_notes, note)
        end
    end
    track.notes = new_notes

    self.selected_notes = {}
end

function PianoRoll:is_note_selected(note)
    for _, sel_note in ipairs(self.selected_notes) do
        if sel_note == note then
            return true
        end
    end
    return false
end

------------------------------------------------------------------------------
--                      MOUSE HANDLING STUFF
------------------------------------------------------------------------------

function PianoRoll:mousepressed(mx, my, btn)
    if self:check_scrollbar_click(mx, my) then
        return
    end

    if self:check_playhead_click(mx, my) then
        return
    end
    
    if btn == 1 then
        if mx >= self.start_x and mx <= (self.start_x + self.total_width)
           and my >= self.start_y and my <= (self.start_y + self.total_height) then

            if love.keyboard.isDown("lctrl") then
                self.selecting = true

                local rx, ry = self:screen_to_roll(mx, my)
                self.select_start_x = rx
                self.select_start_y = ry
                self.select_end_x   = rx
                self.select_end_y   = ry

                self.selected_notes = {}
                return
            end

            local roll_x, roll_y = self:screen_to_roll(mx, my)
            local track = muse.tracks[muse.current_track]
            if not track.notes then
                track.notes = {}
            end
            
            local clicked_note = nil
            for _, note in ipairs(track.notes) do
                if self:point_in_note(note, roll_x, roll_y) then
                    clicked_note = note
                    break
                end
            end
            
            if clicked_note then
                if self:is_note_selected(clicked_note) then
                    self.drag_mode = "move_multiple"
                    self.drag_start_mouse_x = roll_x
                    self.drag_start_mouse_y = roll_y

                    self.multiple_drag_data = {}
                    for _, sel_note in ipairs(self.selected_notes) do
                        table.insert(self.multiple_drag_data, {
                            note   = sel_note,
                            orig_x = sel_note.x,
                            orig_r = sel_note.row
                        })
                    end

                else
                    local edge = self:edge_hit_test(clicked_note, roll_x, 5)
                    if edge == "left" or edge == "right" then
                        self.drag_mode = (edge == "left") and "resize_left" or "resize_right"
                        self.drag_note = clicked_note
                        self.drag_original_x = clicked_note.x
                        self.drag_original_w = clicked_note.width
                        self.drag_start_mouse_x = roll_x
                    else
                        self.drag_mode  = "move"
                        self.drag_note  = clicked_note
                        self.drag_start_mouse_x = roll_x
                        self.drag_start_mouse_y = roll_y
                        self.drag_original_x = clicked_note.x
                        self.drag_original_row = clicked_note.row
                    end
                end

            else
                local row = math.floor(roll_y / self.note_height)
                if row < 0 or row >= (self.num_octaves * 12) then
                    return
                end
                
                local new_x = self:snap_x(roll_x)
                local new_note = {
                    x = new_x,
                    width = self:snap_x(self:get_default_note_length()),
                    row = row
                }

                -- lol here's that hinky shit again
                muse:preview_note(95 - row)
                table.insert(track.notes, new_note)
            end
        end

    elseif btn == 2 then
        local roll_x, roll_y = self:screen_to_roll(mx, my)
        local track = muse.tracks[muse.current_track]
        if track.notes then
            for i, note in ipairs(track.notes) do
                if self:point_in_note(note, roll_x, roll_y) then
                    table.remove(track.notes, i)
                    break
                end
            end
        end
    end
end

function PianoRoll:mousereleased(mx, my, btn)
    if btn == 1 then
        self.drag_mode = nil
        self.drag_note = nil

        self.playhead_dragging = false

        if self.selecting then
            self.selecting = false
            
            local x1 = math.min(self.select_start_x, self.select_end_x)
            local x2 = math.max(self.select_start_x, self.select_end_x)
            local y1 = math.min(self.select_start_y, self.select_end_y)
            local y2 = math.max(self.select_start_y, self.select_end_y)

            local track = muse.tracks[muse.current_track]
            if track and track.notes then
                self.selected_notes = {}
                for _, note in ipairs(track.notes) do
                    local nx, ny, nw, nh = self:get_note_rect(note)
                    if (nx + nw >= x1) and (nx <= x2) and
                       (ny + nh >= y1) and (ny <= y2) then
                        table.insert(self.selected_notes, note)
                    end
                end
            end
        end
    end
    
    self.scrollbar_h.is_dragging = false
    self.scrollbar_v.is_dragging = false
end

function PianoRoll:mousemoved(mx, my, dx, dy)
	if self.drag_mode ~= nil or self.selecting then
        self:auto_scroll_if_needed(mx, my)
    end

    if self.playhead_dragging then
        local knob_screen_x = mx - self.playhead_drag_offset
        local new_playhead_x = knob_screen_x - (self.start_x - self.scroll_x)
        
        if new_playhead_x < 0 then
            new_playhead_x = 0
        elseif new_playhead_x > self.total_width then
            new_playhead_x = self.total_width
        end

        self.playhead_x = new_playhead_x
        self:ensure_playhead_visible()
        return
    end

    if self.selecting then
	    local rx, ry = self:screen_to_roll(mx, my)
	    self.select_end_x = rx
	    self.select_end_y = ry
	    return
	end

    if self.selecting then
        local rx, ry = self:screen_to_roll(mx, my)
        self.select_end_x = rx
        self.select_end_y = ry
        return
    end

    -- multi-note dragging
    if self.drag_mode == "move_multiple" and self.multiple_drag_data then
        local rx, ry = self:screen_to_roll(mx, my)
        local delta_x = rx - self.drag_start_mouse_x
        local delta_y = ry - self.drag_start_mouse_y

        for _, data in ipairs(self.multiple_drag_data) do
            local new_x = data.orig_x + delta_x
            if not self:is_alt_down() then
            	new_x = self:snap_x(new_x)
            end
            if new_x < 0 then new_x = 0 end
            data.note.x = new_x

            local row_offset = math.floor(delta_y / self.note_height + 0.5)
            local new_row = data.orig_r + row_offset

            if new_row < 0 then new_row = 0 end
            local max_row = (self.num_octaves * 12) - 1
            if new_row > max_row then
                new_row = max_row
            end
            data.note.row = new_row
        end
        return
    end

    -- single note dragging
    if self.drag_note and self.drag_mode then
        local rx, ry = self:screen_to_roll(mx, my)
        local delta = rx - self.drag_start_mouse_x

        if self.drag_mode == "resize_left" then
            local raw_new_x = self.drag_original_x + delta
            local raw_new_w = self.drag_original_w - delta
            if not self:is_alt_down() then
                raw_new_x = self:snap_x(raw_new_x)
            end
            local snapped_right = self.drag_original_x + self.drag_original_w
            local new_w = snapped_right - raw_new_x
            if not self:is_alt_down() then
                new_w = self:snap_x(new_w)
            end
            if new_w < 4 then new_w = 4 end
            self.drag_note.x = raw_new_x
            self.drag_note.width = new_w
        
        elseif self.drag_mode == "resize_right" then
            local raw_new_w = self.drag_original_w + delta
            if not self:is_alt_down() then
                raw_new_w = self:snap_x(raw_new_w)
            end
            if raw_new_w < 4 then raw_new_w = 4 end
            self.drag_note.width = raw_new_w
        
        elseif self.drag_mode == "move" then
            local delta_y = ry - self.drag_start_mouse_y
            local new_x = self.drag_original_x + delta
            if not self:is_alt_down() then
                new_x = self:snap_x(new_x)
            end
            if new_x < 0 then new_x = 0 end
            self.drag_note.x = new_x

            local row_offset = math.floor(delta_y / self.note_height + 0.5)
            local new_row = self.drag_original_row + row_offset
            if new_row < 0 then new_row = 0 end
            local max_row = (self.num_octaves * 12) - 1
            if new_row > max_row then
                new_row = max_row
            end
            self.drag_note.row = new_row
        end
    end
    
    self:handle_scrollbar_drag(mx, my, dx, dy)
end

function PianoRoll:ensure_playhead_visible()
    local margin = 400

    local knob_screen_x = (self.start_x - self.scroll_x) + self.playhead_x

    local left_bound  = self.start_x
    local right_bound = self.start_x + self.visible_width

    if knob_screen_x < (left_bound + margin) then
        local shift_amount = (left_bound + margin) - knob_screen_x
        self.scroll_x = self.scroll_x - shift_amount
        if self.scroll_x < 0 then
            self.scroll_x = 0
        end

    elseif knob_screen_x > (right_bound - margin) then
        local shift_amount = knob_screen_x - (right_bound - margin)
        self.scroll_x = self.scroll_x + shift_amount
        local max_scroll = self.total_width - self.visible_width
        if self.scroll_x > max_scroll then
            self.scroll_x = max_scroll
        end
    end

    self:update_thumb_positions()
end

function PianoRoll:draw_measure_labels()
    love.graphics.setScissor(self.start_x, self.start_y - 20, 
                             self.visible_width, 20)  
    
    love.graphics.push()
    love.graphics.translate(self.start_x - self.scroll_x, self.start_y)
    
    love.graphics.setColor(1, 1, 1)
    
    for measure_index = 1, self.num_measures do
        local measure_x = (measure_index - 1) * self.measure_width
        
        local label_x = measure_x + (self.measure_width / 2) - 10
        local label_y = -22
        
        love.graphics.print(measure_index, label_x, label_y)
    end
    
    love.graphics.pop()
    love.graphics.setScissor()
end

function PianoRoll:get_pitch_from_row(row)
    return 71 - row -- i don't understand why this is different from the last two times i've done this
                    -- but whatever
end


local function get_octave_for_pitch(pitch)
    return math.floor(pitch / 12) - 1
end


function PianoRoll:draw_octave_labels()
    love.graphics.setScissor(
        self.piano_x,
        self.start_y,
        self.start_x - self.piano_x,
        self.visible_height
    )
    love.graphics.push()
    love.graphics.translate(0, -self.scroll_y)

    local total_rows = self.num_octaves * 12
    for row = 0, total_rows - 1 do
        local pitch = self:get_pitch_from_row(row)
        if pitch >= 0 and pitch <= 127 then
            if (pitch % 12) == 0 then
                local octave = get_octave_for_pitch(pitch)
                local label_str = "C" .. tostring(octave)

                local row_y = row * self.note_height
                local text_x = self.piano_x + 20
                local text_y = self.start_y + row_y + (self.note_height / 2) - 6

                love.graphics.setColor(Core.col[11])
                love.graphics.print(label_str, text_x, text_y)
            end
        end
    end

    love.graphics.pop()
    love.graphics.setScissor()
end

function PianoRoll:draw_playhead()
    local knob_screen_x = (self.start_x - self.scroll_x) + self.playhead_x
    
    local line_top    = self.start_y
    local line_bottom = self.max_y_draw

    love.graphics.setColor(Core.col[10])
    love.graphics.setLineWidth(2)
    love.graphics.line(knob_screen_x, line_top, knob_screen_x, line_bottom)

    local handle_size = 10
    local handle_x = knob_screen_x - (handle_size / 2)
    local handle_y = self.start_y - (handle_size + 4)

    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", handle_x, handle_y, handle_size, handle_size)

    love.graphics.setColor(Core.col[11])
    love.graphics.rectangle("line", handle_x, handle_y, handle_size, handle_size)
end

function PianoRoll:draw_navigation()
    for i=1, self.num_measures do
        love.graphics.print(i, self.start_x + ((i-1) * 20), self.nav_y)
    end
end

------------------------------------------------------------------------------
--                             DRAWING STUFF
------------------------------------------------------------------------------

function PianoRoll:draw()
    self:draw_piano_keys()
    --self:draw_octave_labels()
    self:draw_note_grid()
    self:draw_scrollbars()
    self:draw_playhead()
    self:draw_measure_labels()
    --self:draw_navigation()
end

function PianoRoll:draw_note_grid()
    love.graphics.setScissor(self.start_x, self.start_y, self.visible_width, self.visible_height)
    love.graphics.push()
    love.graphics.translate(self.start_x - self.scroll_x, self.start_y - self.scroll_y)
    
    self:draw_row_backgrounds()
    self:draw_horizontal_grid_lines()
    self:draw_vertical_grid_lines()
    
    self:draw_notes()

    if self.selecting then
	    local x1 = math.min(self.select_start_x, self.select_end_x)
	    local x2 = math.max(self.select_start_x, self.select_end_x)
	    local y1 = math.min(self.select_start_y, self.select_end_y)
	    local y2 = math.max(self.select_start_y, self.select_end_y)

	    love.graphics.setColor(0, 0, 0, 0.2)
	    love.graphics.rectangle("fill", x1, y1, x2 - x1, y2 - y1)
	    love.graphics.setColor(Core.col[11])
	    love.graphics.rectangle("line", x1, y1, x2 - x1, y2 - y1)
	end
    
    love.graphics.pop()
    love.graphics.setScissor()
end

function PianoRoll:deselect_all()
    self.selected_notes = {}
end

function PianoRoll:draw_notes()
    for i, track in ipairs(muse.tracks) do
        if i ~= muse.current_track then
            self:draw_track_notes(track, true)
        end
    end
    
    local current_track = muse.tracks[muse.current_track]
    if current_track then
        self:draw_track_notes(current_track, false)
    end
end

function PianoRoll:draw_track_notes(track, ghost)
    if not track.notes then return end
    
    local ghost_alpha = 0.4
    local normal_color = muse:get_track_color() or {1, 0, 0, 1}
    
    for _, note in ipairs(track.notes) do
        local nx, ny, nw, nh = self:get_note_rect(note)
        
        if ghost then
            love.graphics.setColor(track.color[1], track.color[2], track.color[3], ghost_alpha)
        else
            love.graphics.setColor(track.color)
        end
        
        love.graphics.rectangle("fill", nx, ny, nw, nh)
        
        if ghost then
            love.graphics.setColor(0, 0, 0, ghost_alpha)
        else
        	if self:is_note_selected(note) then
        		love.graphics.setLineWidth(4)
        		love.graphics.setColor(Core.col[7])
        		love.graphics.rectangle("line", nx, ny, nw, nh)
        		love.graphics.setLineWidth(1)
        	else
            	love.graphics.setColor(Core.col[11])
            	love.graphics.rectangle("line", nx, ny, nw, nh)
            end
        end
        
    end

    love.graphics.setColor(1, 1, 1, 1)
end

------------------------------------------------------------------------------
--                      MISC. SCROLL/ROW SHIT
------------------------------------------------------------------------------

function PianoRoll:auto_scroll_if_needed(mx, my)
    local margin = 40
    local scroll_speed = 2

    local left_edge  = self.start_x
    local right_edge = self.start_x + self.visible_width

    if mx < (left_edge + margin) then
        self.scroll_x = self.scroll_x - scroll_speed
        if self.scroll_x < 0 then
            self.scroll_x = 0
        end
    elseif mx > (right_edge - margin) then
        self.scroll_x = self.scroll_x + scroll_speed
        local max_scroll_x = self.total_width - self.visible_width
        if self.scroll_x > max_scroll_x then
            self.scroll_x = max_scroll_x
        end
    end

    local top_edge    = self.start_y
    local bottom_edge = self.start_y + self.visible_height

    if my < (top_edge + margin) then
        self.scroll_y = self.scroll_y - scroll_speed
        if self.scroll_y < 0 then
            self.scroll_y = 0
        end
    elseif my > (bottom_edge - margin) then
        self.scroll_y = self.scroll_y + scroll_speed
        local max_scroll_y = self.total_height - self.visible_height
        if self.scroll_y > max_scroll_y then
            self.scroll_y = max_scroll_y
        end
    end

    self:update_thumb_positions()
end

function PianoRoll:draw_row_backgrounds()
    local total_rows = self.num_octaves * 12
    for row = 0, total_rows - 1 do
        local row_y = row * self.note_height
        if BLACK_KEY_INDICES[row % 12] then
            love.graphics.setColor(Core.col[5])
        else
            love.graphics.setColor(Core.col[2])
        end
        love.graphics.rectangle("fill", 0, row_y, self.total_width, self.note_height)
    end
end

function PianoRoll:draw_horizontal_grid_lines()
    local total_rows = self.num_octaves * 12
    love.graphics.setLineWidth(1)
    love.graphics.setColor(Core.col[6])
    for row = 0, total_rows do
        local row_y = row * self.note_height
        love.graphics.line(0, row_y, self.total_width, row_y)
    end
end

function PianoRoll:draw_vertical_grid_lines()
    love.graphics.setLineWidth(1)
    for measure_index = 0, self.num_measures - 1 do
        local measure_x = measure_index * self.measure_width
        
        love.graphics.setColor(Core.col[4])
        love.graphics.line(measure_x, 0, measure_x, self.total_height)
        
        love.graphics.setColor(Core.col[3])
        for bar = 1, 3 do
            local bar_x = measure_x + (bar * self.bar_width)
            love.graphics.line(bar_x, 0, bar_x, self.total_height)
        end
    end

    local right_edge = self.num_measures * self.measure_width
    love.graphics.setColor(Core.col[4])
    love.graphics.line(right_edge, 0, right_edge, self.total_height)
end

function PianoRoll:build_piano_canvas()
    local octave_height = piano_img:getHeight()
    local total_canvas_height = self.num_octaves * octave_height
    
    local piano_width = self.start_x - self.piano_x
    if piano_width < 1 then
        piano_width = piano_img:getWidth()
    end

    local c = love.graphics.newCanvas(piano_width, total_canvas_height)
    love.graphics.setCanvas(c)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.push()
    love.graphics.origin()

    local c_offset_in_image = 180

    for i = 0, self.num_octaves - 1 do
        local chunk_y = i * octave_height
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(piano_img, 0, chunk_y)

        local base_octave_label = 6
        local octave_label = base_octave_label - i
        local label_str = ("C%d"):format(octave_label)

        local label_x = 60
        local label_y = chunk_y + c_offset_in_image - 6

        love.graphics.setColor(Core.col[11])
        love.graphics.print(label_str, label_x, label_y)
    end

    love.graphics.pop()
    love.graphics.setCanvas()
    self.piano_canvas = c
end

function PianoRoll:draw_piano_keys()
    if not self.piano_canvas then
        self:build_piano_canvas()
    end

    love.graphics.setScissor(
        self.piano_x,
        self.start_y,
        self.start_x - self.piano_x,
        self.visible_height
    )

    love.graphics.push()
    love.graphics.translate(0, -self.scroll_y)

    local offset_y = self.start_y
    love.graphics.draw(self.piano_canvas, self.piano_x, offset_y)

    love.graphics.pop()
    love.graphics.setScissor()
end

------------------------------------------------------------------------------
--                           SCROLLBARS
------------------------------------------------------------------------------

function PianoRoll:draw_scrollbars()
    local sb_h = self.scrollbar_h
    local sb_v = self.scrollbar_v
    
    -- when I'm feeling less lazy I'll have these use Core.col
    -- instead of random numbers
    love.graphics.setColor(0.25, 0.25, 0.25)
    love.graphics.rectangle("fill", sb_h.x, sb_h.y, sb_h.w, sb_h.h)
    love.graphics.setColor(0.65, 0.65, 0.65)
    love.graphics.rectangle("fill", sb_h.thumb_x, sb_h.y, sb_h.thumb_w, sb_h.h)
    
    love.graphics.setColor(0.25, 0.25, 0.25)
    love.graphics.rectangle("fill", sb_v.x, sb_v.y, sb_v.w, sb_v.h)
    love.graphics.setColor(0.65, 0.65, 0.65)
    love.graphics.rectangle("fill", sb_v.x, sb_v.thumb_y, sb_v.w, sb_v.thumb_h)
end

function PianoRoll:check_scrollbar_click(mx, my)
    local sb_h = self.scrollbar_h
    if self:point_in_rect(mx, my, sb_h.thumb_x, sb_h.y, sb_h.thumb_w, sb_h.h) then
        sb_h.is_dragging = true
        sb_h.drag_offset = mx - sb_h.thumb_x
        return true
    end
    
    local sb_v = self.scrollbar_v
    if self:point_in_rect(mx, my, sb_v.x, sb_v.thumb_y, sb_v.w, sb_v.thumb_h) then
        sb_v.is_dragging = true
        sb_v.drag_offset = my - sb_v.thumb_y
        return true
    end
end

function PianoRoll:handle_scrollbar_drag(mx, my, dx, dy)
    local sb_h = self.scrollbar_h
    local sb_v = self.scrollbar_v
    
    if sb_h.is_dragging then
        local new_thumb_x = mx - sb_h.drag_offset
        self:set_scroll_x_from_thumb(new_thumb_x)
        self:update_thumb_positions()
        return
    end
    
    if sb_v.is_dragging then
        local new_thumb_y = my - sb_v.drag_offset
        self:set_scroll_y_from_thumb(new_thumb_y)
        self:update_thumb_positions()
        return
    end
end

function PianoRoll:set_scroll_x_from_thumb(new_thumb_x)
    local sb_h = self.scrollbar_h
    local min_x = sb_h.x
    local max_x = sb_h.x + (sb_h.w - sb_h.thumb_w)
    local clamped = math.max(min_x, math.min(new_thumb_x, max_x))
    sb_h.thumb_x = clamped
    
    if self.total_width > self.visible_width then
        local ratio = (sb_h.thumb_x - sb_h.x) / (sb_h.w - sb_h.thumb_w)
        self.scroll_x = ratio * (self.total_width - self.visible_width)
    else
        self.scroll_x = 0
    end
end

function PianoRoll:set_scroll_y_from_thumb(new_thumb_y)
    local sb_v = self.scrollbar_v
    local min_y = sb_v.y
    local max_y = sb_v.y + (sb_v.h - sb_v.thumb_h)
    local clamped = math.max(min_y, math.min(new_thumb_y, max_y))
    sb_v.thumb_y = clamped
    
    if self.total_height > self.visible_height then
        local ratio = (sb_v.thumb_y - sb_v.y) / (sb_v.h - sb_v.thumb_h)
        self.scroll_y = ratio * (self.total_height - self.visible_height)
    else
        self.scroll_y = 0
    end
end

function PianoRoll:update_thumb_positions()
    local sb_h = self.scrollbar_h
    if self.total_width <= self.visible_width then
        sb_h.thumb_w = sb_h.w
        sb_h.thumb_x = sb_h.x
    else
        local ratio_w = self.visible_width / self.total_width
        sb_h.thumb_w  = sb_h.w * ratio_w
        local scroll_frac = self.scroll_x / (self.total_width - self.visible_width)
        sb_h.thumb_x = sb_h.x + (sb_h.w - sb_h.thumb_w) * scroll_frac
    end
    
    local sb_v = self.scrollbar_v
    if self.total_height <= self.visible_height then
        sb_v.thumb_h = sb_v.h
        sb_v.thumb_y = sb_v.y
    else
        local ratio_h = self.visible_height / self.total_height
        sb_v.thumb_h  = sb_v.h * ratio_h
        local scroll_frac = self.scroll_y / (self.total_height - self.visible_height)
        sb_v.thumb_y = sb_v.y + (sb_v.h - sb_v.thumb_h) * scroll_frac
    end
end

function PianoRoll:point_in_rect(px, py, rx, ry, rw, rh)
    return (px >= rx and px <= rx + rw and py >= ry and py <= ry + rh)
end

return PianoRoll
