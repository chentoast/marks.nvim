local utils = require'marks.utils'

local Bookmarks = {}

-- self is an array of mark groups, with indexes from 1 to 10.
-- each element is a table with the following keys:
--  - ns: nvim namespace
--  - sign: the sign to use for this group
--  - virt_text: the virtual text to place at each mark
--  - marks: a table of marks, indexed by line number.
-- each mark is represented by a table with the following keys:
--  buf, line, col, sign_id, extmark_id
--
local function group_under_cursor(groups, bufnr, pos)
  local bufnr = bufnr or vim.api.nvim_get_current_buf()
  local pos = pos or vim.fn.getpos(".")

  for group_nr, group in pairs(groups) do
    if group.marks[bufnr] and group.marks[bufnr][pos[2]] then
      return group_nr
    end
  end
  return nil
end

local function flatten(marks)
  local ret = {}

  for bufnr, buf_marks in pairs(marks) do
    for line, mark in pairs(buf_marks) do
      table.insert(ret, mark)
    end
  end

  function cmp(a, b)
    return (a.buf == b.buf and a.line < b.line) or (a.buf < b.buf)
  end

  table.sort(ret, cmp)
  return ret
end

function Bookmarks:init(group_nr)
  local ns = vim.api.nvim_create_namespace("Bookmarks" .. group_nr)
  local sign = self.signs[group_nr]
  local virt_text = self.virt_text[group_nr]

  self.groups[group_nr] = { ns = ns, sign = sign, virt_text = virt_text, marks = {} }
end

function Bookmarks:place_mark(group_nr, bufnr)
  local bufnr = bufnr or vim.api.nvim_get_current_buf()
  local group = self.groups[group_nr]

  if not group then
    self:init(group_nr)
    group = self.groups[group_nr]
  end

  local pos = vim.fn.getpos(".")
  local data = { buf = bufnr, line = pos[2], col = pos[3], sign_id = -1}

  if group.sign then
    local id = group.sign:byte() * 100 + pos[2]
    utils.add_sign(bufnr, group.sign, pos[2], id, "BookmarkSigns")
    data.sign_id = id
  end

  local opts = {}
  if group.virt_text then
    opts.virt_text = {{ group.virt_text, "MarkVirtTextHL" }}
    opts.virt_text_pos = "eol"
  end

  local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, group.ns, pos[2]-1, pos[3]-1, opts)

  data.extmark_id = extmark_id
  
  if not group.marks[bufnr] then
    group.marks[bufnr] = {}
  end
  group.marks[bufnr][pos[2]] = data
end

function Bookmarks:delete_mark(group_nr, bufnr, lnum)
  local bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lnum = lnum or vim.fn.getpos(".")[2]
  local group = self.groups[group_nr]

  if not group then
    return
  end

  local mark = group.marks[bufnr][lnum]

  if not mark then
    return
  end

  if mark.sign_id then
    utils.remove_sign(bufnr, mark.sign_id, "BookmarkSigns")
  end

  vim.api.nvim_buf_del_extmark(bufnr, group.ns, mark.extmark_id)
  group.marks[bufnr][lnum] = nil
end

function Bookmarks:delete_mark_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.fn.getpos(".")

  local group_nr = group_under_cursor(self.groups, bufnr, pos)
  if not group_nr then
    return
  end

  self:delete_mark(group_nr, bufnr, pos[2])
end

function Bookmarks:delete_all(group_nr)
  local group = self.groups[group_nr]
  if not group then
    return
  end

  for bufnr, buf_marks in pairs(group.marks) do
    for line, mark in pairs(buf_marks) do
      if mark.sign_id then
        utils.remove_sign(bufnr, mark.sign_id, "BookmarkSigns")
      end

      vim.api.nvim_buf_del_extmark(bufnr, group.ns, mark.extmark_id)
    end
    group.marks[bufnr] = nil
  end
end

function Bookmarks:next(group_nr)
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.fn.getpos(".")

  if not group_nr then
    group_nr = group_under_cursor(self.groups, bufnr, pos)
  end

  local group = self.groups[group_nr]
  if not group then
    return
  end

  local marks = flatten(group.marks)

  local function comparator(a, b, key)
    if (a.line > b.line and a.buf == b.buf) or (a.buf > b.buf) then
      return true
    end

    return false
  end

  local next = utils.search(marks, {buf = bufnr, line=pos[2]},
      {buf=math.huge, line=math.huge}, comparator, false)

  if not next then
    next = marks[1]
  end

  if next.buf ~= bufnr then
    vim.cmd("silent b" .. next.buf)
  end
  vim.fn.setpos(".", { 0, next.line, next.col, 0 })
end

function Bookmarks:prev(group_nr)
  local bufnr = vim.api.nvim_get_current_buf()
  local pos = vim.fn.getpos(".")

  if not group_nr then
    group_nr = group_under_cursor(self.groups, bufnr, pos)
  end

  local group = self.groups[group_nr]
  if not group then
    return
  end

  local marks = flatten(group.marks)

  local function comparator(a, b, key)
    if (a.line < b.line and a.buf == b.buf) or (a.buf < b.buf) then
      return true
    end

    return false
  end

  local prev = utils.search(marks, {buf = bufnr, line=pos[2]},
      {buf=-1, line=-1}, comparator, false)

  if not prev then
    prev = marks[#marks]
  end

  if prev.buf ~= bufnr then
    vim.cmd("silent b" .. prev.buf)
  end
  vim.fn.setpos(".", { 0, prev.line, prev.col, 0 })
end

function Bookmarks:refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  local buf_marks

  -- if we delete and undo really quickly, the extmark's position will be
  -- the same, but the sign will no longer be there. so clear and restore all
  -- signs.

  utils.remove_buf_signs(bufnr, "BookmarkSigns")
  for group_nr, group in pairs(self.groups) do
    buf_marks = group.marks[bufnr]
    if not buf_marks then
      return
    end
    for _, mark in pairs(vim.tbl_values(buf_marks)) do
      local line = vim.api.nvim_buf_get_extmark_by_id(bufnr, group.ns,
          mark.extmark_id, {})[1]

      if line + 1 ~= mark.line then
        buf_marks[line + 1] = mark
        buf_marks[mark.line] = nil
        buf_marks[line + 1].line = line + 1
      end
      utils.add_sign(bufnr, group.sign, line + 1, mark.sign_id, "BookmarkSigns")
    end
  end
end

function Bookmarks:to_loclist(group_nr)
  if not group_nr then
    return
  end

  items = {}
  for bufnr, buffer_marks in pairs(self.groups[group_nr].marks) do
    for lnum, mark in pairs(buffer_marks) do
      local text = vim.api.nvim_buf_get_lines(bufnr, lnum-1, lnum, true)[1]
      table.insert(items, { bufnr=bufnr, lnum=lnum, col=mark.col, text=text })
    end
  end

  vim.fn.setloclist(0, items, "r")
end

function Bookmarks:all_to_loclist()
  items = {}
  for group_nr, group in pairs(self.groups) do
    for bufnr, buffer_marks in pairs(group.marks) do
      for lnum, mark in pairs(buffer_marks) do
      local text = vim.api.nvim_buf_get_lines(bufnr, lnum-1, lnum, true)[1]
        table.insert(items, { bufnr=bufnr, lnum=lnum, col=mark.col,
            text="bookmark group "..group_nr..": "..text })
      end
    end
  end

  vim.fn.setloclist(0, items, "r")
end

function Bookmarks.new()
  return setmetatable({signs = {"!", "@", "#", "$", "%", "^", "&", "*", "(", [0]=")"},
  virt_text = {}, groups = {}}, {__index = Bookmarks})
end

return Bookmarks
