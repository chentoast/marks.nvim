local a = vim.api
local utils = require'marks.utils'

local Mark = {}

-- basic structure: self.buffers is an array of tables indexed by bufnr,
-- where each table has the following keys:
--
-- placed_marks: a table of currently placed/registered marks in the buffer.
-- indexed by mark name and contains information about mark position and sign id.
--
-- marks_by_line: a table of lines that have marks on them. indexed by line number,
-- and contains an array of all marks currently set on that line.
--
-- lowest_available_mark: the next lowest alphabetical mark that is available.

function Mark:register_mark(mark, line, col)
  col = col or 1
  local bufnr = a.nvim_get_current_buf()
  local buffer = self.buffers[bufnr]

  if not buffer then
    return
  end

  if buffer.placed_marks[mark] then
    -- mark already exists: remove it first
    self:delete_mark(mark, false)
  end

  if buffer.marks_by_line[line] then
    table.insert(buffer.marks_by_line[line], mark)
  else
    buffer.marks_by_line[line] = { mark }
  end
  buffer.placed_marks[mark] = { line = line, col = col, id = -1 }

  if self.signs and (utils.is_letter(mark) or 
      vim.tbl_contains(self.builtin_marks, mark)) then
    local id = mark:byte() * 100
    buffer.placed_marks[mark].id = id
    utils.add_sign(bufnr, mark, line, id)
  end

  if not utils.is_lower(mark) then
    return
  end

  while self.buffers[bufnr].placed_marks[mark] do
    mark = string.char(mark:byte() + 1)
  end
  self.buffers[bufnr].lowest_available_mark = mark
end

function Mark:place_mark_cursor(mark)
  local bufnr = a.nvim_get_current_buf()

  local pos = vim.fn.getpos(".")
  self:register_mark(mark, pos[2], pos[3])

  if utils.is_special(mark) then
    return
  end

  local new_mark = self.buffers[bufnr].lowest_available_mark
  while self.buffers[bufnr].placed_marks[new_mark] do
    new_mark = string.char(new_mark:byte() + 1)
  end
  self.buffers[bufnr].lowest_available_mark = new_mark
end

function Mark:place_next_mark(line, col)
  local bufnr = a.nvim_get_current_buf()
  if not self.buffers[bufnr] then
    self.buffers[bufnr] = { placed_marks = {}, -- selfark id and position. Indexed by mark letter
                 marks_by_line = {}, -- Lists all marks placed at a particular line
                 lowest_available_mark = "a" }
  end

  local mark = self.buffers[bufnr].lowest_available_mark
  self:register_mark(mark, line, col)

  vim.cmd("normal! m" .. mark)
end

function Mark:place_next_mark_cursor()
  local pos = vim.fn.getpos(".")
  self:place_next_mark(pos[2], pos[3])
end

function Mark:delete_mark(mark, clear)
  clear = utils.option_nil(clear, true)
  local bufnr = a.nvim_get_current_buf()
  local buffer = self.buffers[bufnr]

  if (not buffer) or (not buffer.placed_marks[mark]) then
    return
  end

  if buffer.placed_marks[mark].id ~= -1 then
    utils.remove_sign(bufnr, buffer.placed_marks[mark].id)
  end

  line = buffer.placed_marks[mark].line
  local line_marks = buffer.marks_by_line[line]
  for key, tmp_mark in pairs(line_marks) do
    if tmp_mark == mark then
      line_marks[key] = nil
    end
  end

  if vim.tbl_isempty(buffer.marks_by_line[line]) then
    buffer.marks_by_line[line] = nil
  end

  buffer.placed_marks[mark] = nil

  if utils.is_special(mark) then
    -- don't adjust lowest_available_mark when deleting builtin marks
    return
  end

  -- We don't actually delete builtin marks, we just hide them
  if clear then
    vim.cmd("delmark " .. mark)
  end

  if self.force_write_shada then
    vim.cmd("wshada!")
  end

  if mark:byte() < buffer.lowest_available_mark:byte() then
    buffer.lowest_available_mark = mark
  end

end

function Mark:delete_line_marks()
  local bufnr = a.nvim_get_current_buf()
  local pos = vim.fn.getpos(".")
  if not self.buffers[bufnr].marks_by_line[pos[2]] then
    return
  end
 
  -- delete_mark modifies the table, so make a copy
  local copy = vim.tbl_values(self.buffers[bufnr].marks_by_line[pos[2]])
  for _, mark in pairs(copy) do
    self:delete_mark(mark)
  end
end

function Mark:toggle_mark_cursor()
  local bufnr = a.nvim_get_current_buf()
  local pos = vim.fn.getpos(".")

  if self.buffers[bufnr].marks_by_line[pos[2]] then
    self:delete_line_marks()
  else
    self:place_next_mark(pos[2], pos[3])
  end
end

function Mark:delete_buf_marks(clear)
  clear = utils.option_nil(clear, true)
  local bufnr = a.nvim_get_current_buf()
  self.buffers[bufnr] = { placed_marks = {}, 
               marks_by_line = {},
               lowest_available_mark = "a" }

  utils.remove_buf_signs(bufnr)
  if clear then
    vim.cmd("delmarks!")
  end
end

function Mark:get_next_mark(line)
  local bufnr = a.nvim_get_current_buf()
  if (not self.buffers[bufnr]) or vim.tbl_isempty(self.buffers[bufnr].placed_marks) then
    return
  end

  local min_next_line = math.huge
  local next_mark
  -- if we need to wrap around
  local min_line = math.huge
  local min_mark

  for mark, data in pairs(self.buffers[bufnr].placed_marks) do
    if data.line > line and data.line < min_next_line and utils.is_letter(mark) then
      min_next_line = data.line
      next_mark = mark
    end
    if data.line < min_line and utils.is_letter(mark) then
      min_line = data.line
      min_mark = mark
    end
  end
  if not self.cyclic then
    return next_mark
  end
  return next_mark or min_mark
end

function Mark:next_mark()
  local bufnr = a.nvim_get_current_buf()
  local line = vim.fn.getpos(".")[2]
  next_mark = self:get_next_mark(line)

  if next_mark then
    vim.cmd("normal! `" .. next_mark)
  end
end

function Mark:get_prev_mark(line)
  local bufnr = a.nvim_get_current_buf()
  if (not self.buffers[bufnr]) or vim.tbl_isempty(self.buffers[bufnr].placed_marks) then
    return
  end

  local min_prev_line = -1
  local prev_mark
  -- if we need to wrap around
  local min_line = -1
  local min_mark

  for mark, data in pairs(self.buffers[bufnr].placed_marks) do
    if data.line < line and data.line > min_prev_line and utils.is_letter(mark) then
      min_prev_line = data.line
      prev_mark = mark
    end
    if data.line > min_line and utils.is_letter(mark) then
      min_line = data.line
      min_mark = mark
    end
  end
  if not self.cyclic then
    return prev_mark
  end
  return prev_mark or min_mark
end

function Mark:prev_mark()
  local bufnr = a.nvim_get_current_buf()
  local line = vim.fn.getpos(".")[2]
  prev_mark = self:get_prev_mark(line)

  if prev_mark then
    vim.cmd("normal! `" .. prev_mark)
  end
end

function Mark:preview_mark()
  local bufnr = a.nvim_get_current_buf()

  local mark = vim.fn.getchar()
  if mark == 13 then -- <cr>
    mark = self:get_next_mark(bufnr, vim.fn.getpos(".")[2])
  else
    mark = string.char(mark)
  end

  local pos = vim.fn.getpos("'" .. mark)
  if pos[2] == 0 then
    return
  end

  local winnr = a.nvim_get_current_win()
  local width = a.nvim_win_get_width(0)
  local height = a.nvim_win_get_height(0)

  a.nvim_open_win(pos[1], true, {
      relative = "win",
      win = 0,
      width = math.floor(width / 2),
      height = math.floor(height / 2),
      col = math.floor(width / 4),
      row = math.floor(height / 8),
      border = "single"
    })
  vim.cmd("normal! `" .. mark)
  vim.cmd("normal! zz")
end

function Mark:buffer_to_loclist(bufnr)
  bufnr = bufnr or a.nvim_get_current_buf()
  local items = {}
  for mark, data in pairs(self.buffers[bufnr].placed_marks) do
    local text = a.nvim_buf_get_lines(bufnr, data.line-1, data.line, true)[1]
    table.insert(items, { bufnr = bufnr, lnum = data.line, col = data.col,
        text = "mark " .. mark .. ": " .. text})
  end

  vim.fn.setloclist(bufnr, items, "r")
end

function Mark:all_to_qflist()
  local items = {}
  for bufnr, buffer_state in pairs(self.buffers) do
    for mark, data in pairs(buffer_state.placed_marks) do
      local text = a.nvim_buf_get_lines(bufnr, data.line-1, data.line, true)[1]
      table.insert(items, { bufnr = bufnr, lnum = data.line, col = data.col,
          text = "mark " .. mark .. ": " .. text})
    end
  end

  vim.fn.setqflist(items, "r")
end

function Mark:global_to_qflist()
  local items = {}
  for bufnr, buffer_state in pairs(self.buffers) do
    for mark, data in pairs(buffer_state.placed_marks) do
      if utils.is_upper(mark) then
        local text = a.nvim_buf_get_lines(bufnr, data.line-1, data.line, true)[1]
        table.insert(items, { bufnr = bufnr, lnum = data.line, col = data.col,
            text = "mark " .. mark .. ": " .. text})
      end
    end
  end

  vim.fn.setqflist(items, "r")
end

function Mark:toggle_signs()
  self.signs = not self.signs

  self:on_load()
end

function Mark:on_load()
  local bufnr = a.nvim_get_current_buf()
  print("on load")
  if not self.buffers[bufnr] then
    self.buffers[bufnr] = { placed_marks = {}, 
                         marks_by_line = {},
                         lowest_available_mark = "a" }
  end
  -- clear all signs
  utils.remove_buf_signs(bufnr)
  -- see what marks are already present in the buffer
  -- lowercase alphabet
  for char=97,122 do
    local pos = vim.fn.getpos("'" .. string.char(char))
    if pos[2] ~= 0 then
      self:register_mark(string.char(char), pos[2], pos[3])
    end
  end

  -- uppercase alphabet
  for char=64,90 do
    local pos = vim.fn.getpos("'" .. string.char(char))
    if pos[1] == bufnr and pos[2] ~= 0 then
      self:register_mark(string.char(char), pos[2], pos[3])
    end
  end

  -- builtin marks
  for _, char in pairs(self.builtin_marks) do
    local pos = vim.fn.getpos("'" .. char)
    if pos[2] ~= 0 and pos[1] == 0 then
      self:register_mark(char, pos[2], pos[3])
    end
  end
  return
end

function Mark:refresh_insert_marks()
  local bufnr = a.nvim_get_current_buf()
  if not self.buffers[bufnr] then
    return
  end
  for _, mark in pairs(self.builtin_marks) do
    if utils.is_insert_mark(mark) then
      local pos = vim.fn.getpos("'" .. mark)
      local cached_pos = self.buffers[bufnr].placed_marks[mark]
      -- update if:
      -- mark exists but is not registered, or
      -- mark is registered but has changed position
      if not cached_pos and pos[2] ~= 0 then
        self:register_mark(mark, pos[2], pos[3])
      elseif cached_pos and line ~= 0 and line ~= cached_pos.line then
        self:register_mark(mark, pos[2], pos[3])
      end
    end
  end
end

function Mark:refresh_movement_marks()
  local bufnr = a.nvim_get_current_buf()
  if not self.buffers[bufnr] then
    return
  end
  for _, mark in pairs(self.builtin_marks) do
    if utils.is_movement_mark(mark) then
      local pos = vim.fn.getpos("'" .. mark)
      local cached_pos = self.buffers[bufnr].placed_marks[mark]
      -- update if:
      -- mark exists but is not registered, or
      -- mark is registered but has changed position
      if not cached_pos and pos[2] ~= 0 then
        self:register_mark(mark, pos[2], pos[3])
      elseif cached_pos and pos[2] ~= 0 and line ~= cached_pos.line then
        self:register_mark(mark, pos[2], pos[3])
      end
    end
  end
end

function Mark.new()
  return setmetatable({ buffers = {}, opts = {} }, { __index = Mark })
end

return Mark
