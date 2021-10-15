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

function Mark:register_mark(mark, line, col, bufnr)
  local col = col or 1
  local bufnr = bufnr or a.nvim_get_current_buf()
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

  if self.opt.signs then
    local id = mark:byte() * 100
    buffer.placed_marks[mark].id = id
    self:add_sign(bufnr, mark, line, id)
  end

  if not utils.is_lower(mark) or
      mark:byte() > buffer.lowest_available_mark:byte() then
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
  self:register_mark(mark, pos[2], pos[3], bufnr)
end

function Mark:place_next_mark(line, col)
  local bufnr = a.nvim_get_current_buf()
  if not self.buffers[bufnr] then
    self.buffers[bufnr] = { placed_marks = {},
                 marks_by_line = {},
                 lowest_available_mark = "a" }
  end

  local mark = self.buffers[bufnr].lowest_available_mark
  self:register_mark(mark, line, col, bufnr)

  vim.cmd("normal! m" .. mark)
end

function Mark:place_next_mark_cursor()
  local pos = vim.fn.getpos(".")
  self:place_next_mark(pos[2], pos[3])
end

function Mark:delete_mark(mark, clear)
  local clear = utils.option_nil(clear, true)
  local bufnr = a.nvim_get_current_buf()
  local buffer = self.buffers[bufnr]

  if (not buffer) or (not buffer.placed_marks[mark]) then
    return
  end

  if buffer.placed_marks[mark].id ~= -1 then
    utils.remove_sign(bufnr, buffer.placed_marks[mark].id)
  end

  local line = buffer.placed_marks[mark].line
  for key, tmp_mark in pairs(buffer.marks_by_line[line]) do
    if tmp_mark == mark then
      buffer.marks_by_line[line][key] = nil
      break
    end
  end

  if vim.tbl_isempty(buffer.marks_by_line[line]) then
    buffer.marks_by_line[line] = nil
  end

  buffer.placed_marks[mark] = nil

  -- We don't actually delete builtin marks, we just hide them
  if utils.is_special(mark) then
    return
  end

  if clear then
    vim.cmd("delmark " .. mark)
  end

  if self.opt.force_write_shada then
    vim.cmd("wshada!")
  end

  -- only adjust lowest_available_mark if it is lowercase
  if utils.is_upper(mark) then
    return
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
  local clear = utils.option_nil(clear, true)
  local bufnr = a.nvim_get_current_buf()
  self.buffers[bufnr] = { placed_marks = {}, 
                          marks_by_line = {},
                          lowest_available_mark = "a" }

  utils.remove_buf_signs(bufnr)
  if clear then
    vim.cmd("delmarks!")
  end
end

function Mark:next_mark()
  local bufnr = a.nvim_get_current_buf()

  if not self.buffers[bufnr] then
    return
    end
  if vim.tbl_isempty(self.buffers[bufnr].placed_marks) then
    return
  end

  local line = vim.fn.getpos(".")[2]
  local marks = {}
  for mark, data in pairs(self.buffers[bufnr].placed_marks) do
    if utils.is_letter(mark) then
      marks[mark] = data
    end
  end

  local function comparator(a, b, key)
    return a.line > b.line
  end

  local next = utils.search(marks, {line=line}, {line=math.huge}, comparator, self.opt.cyclic)

  if next then
    vim.fn.setpos(".", { 0, next.line, next.col, 0 })
  end
end

function Mark:prev_mark()
  local bufnr = a.nvim_get_current_buf()

  if not self.buffers[bufnr] then
    return
    end
  if vim.tbl_isempty(self.buffers[bufnr].placed_marks) then
    return
  end

  local line = vim.fn.getpos(".")[2]
  local marks = {}
  for mark, data in pairs(self.buffers[bufnr].placed_marks) do
    if utils.is_letter(mark) then
      marks[mark] = data
    end
  end

  local function comparator(a, b, key)
    return a.line < b.line
  end
  local prev = utils.search(marks, {line=line}, {line=-1}, comparator, self.opt.cyclic)

  if prev then
    vim.fn.setpos(".", { 0, prev.line, prev.col, 0 })
  end
end

function Mark:preview_mark()
  local bufnr = a.nvim_get_current_buf()

  local mark = vim.fn.getchar()
  if mark == 13 then -- <cr>
    mark = self:next_mark(bufnr, vim.fn.getpos(".")[2])
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
  local bufnr = bufnr or a.nvim_get_current_buf()
  if not self.buffers[bufnr] then
    return
  end

  local items = {}
  for mark, data in pairs(self.buffers[bufnr].placed_marks) do
    local text = a.nvim_buf_get_lines(bufnr, data.line-1, data.line, true)[1]
    table.insert(items, { bufnr = bufnr, lnum = data.line, col = data.col,
        text = "mark " .. mark .. ": " .. text})
  end

  vim.fn.setloclist(0, items, "r")
end

function Mark:all_to_loclist()
  local items = {}
  for bufnr, buffer_state in pairs(self.buffers) do
    for mark, data in pairs(buffer_state.placed_marks) do
      local text = a.nvim_buf_get_lines(bufnr, data.line-1, data.line, true)[1]
      table.insert(items, { bufnr = bufnr, lnum = data.line, col = data.col,
          text = "mark " .. mark .. ": " .. text})
    end
  end

  vim.fn.setloclist(0, items, "r")
end

function Mark:global_to_loclist()
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

  vim.fn.setloclist(0, items, "r")
end

function Mark:toggle_signs()
  self.opt.signs = not self.opt.signs
  self:refresh()
end

function Mark:refresh(bufnr)
  local bufnr = bufnr or a.nvim_get_current_buf()
  if not self.buffers[bufnr] then
    self.buffers[bufnr] = { placed_marks = {}, 
                         marks_by_line = {},
                         lowest_available_mark = "a" }
  end

  -- first, remove all marks that were deleted
  for mark, data in pairs(self.buffers[bufnr].placed_marks) do
    if vim.fn.getpos("'" .. mark)[2] == 0 then
      self:delete_mark(mark, false)
    end
  end

  local mark
  local pos
  local cached_mark

  -- uppercase marks
  for _, data in ipairs(vim.fn.getmarklist()) do
    mark = data.mark:sub(2,3)
    pos = data.pos
    cached_mark = self.buffers[bufnr].placed_marks[mark]

    if utils.is_upper(mark) and pos[1] == bufnr and (not cached_mark or
        pos[2] ~= cached_mark.line) then
      self:register_mark(mark, pos[2], pos[3], bufnr)
    end
  end

  -- lowercase
  for _, data in ipairs(vim.fn.getmarklist("%")) do
    mark = data.mark:sub(2, 3)
    pos = data.pos
    cached_mark = self.buffers[bufnr].placed_marks[mark]

    if utils.is_lower(mark) and (not cached_mark or
        pos[2] ~= cached_mark.line) then
      self:register_mark(mark, pos[2], pos[3], bufnr)
    end
  end

  -- builtin marks
  for _, char in pairs(self.builtin_marks) do
    local pos = vim.fn.getpos("'" .. char)
    if pos[2] ~= 0 and pos[1] == 0 then
      self:register_mark(char, pos[2], pos[3], bufnr)
    end
  end
  return
end

function Mark:add_sign(bufnr, text, line, id)
  local priority
  if utils.is_lower(text) then
    priority = self.opt.priority[1]
  elseif utils.is_upper(text) then
    priority = self.opt.priority[2]
  else -- builtin
    priority = self.opt.priority[3]
  end
  utils.add_sign(bufnr, text, line, id, "MarkSigns", priority)
end

function Mark.new()
  return setmetatable({ buffers = {}, opt = {} }, { __index = Mark })
end

return Mark
