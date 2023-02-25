local utils = require'marks.utils'
local a = vim.api

local Bookmarks = {}

-- self.groups is an array of mark groups, with indexes from 1 to 10.
-- each element is a table with the following keys:
--  - ns: nvim namespace
--  - sign: the sign to use for this group
--  - virt_text: the virtual text to place at each mark
--  - marks: a table of marks, indexed by buffer number, then line number.
-- each mark is represented by a table with the following keys:
--   line, col, sign_id, extmark_id
--
local function group_under_cursor(groups, bufnr, pos)
  bufnr = bufnr or a.nvim_get_current_buf()
  pos = pos or a.nvim_win_get_cursor(0)

  for group_nr, group in pairs(groups) do
    if group.marks[bufnr] and group.marks[bufnr][pos[1]] then
      return group_nr
    end
  end
  return nil
end

local function flatten(marks)
  local ret = {}

  for _, buf_marks in pairs(marks) do
    for _, mark in pairs(buf_marks) do
      table.insert(ret, mark)
    end
  end

  local function comparator(x, y)
    return (x.buf == y.buf and x.line < y.line) or (x.buf < y.buf)
  end

  table.sort(ret, comparator)
  return ret
end

function Bookmarks:init(group_nr)
  local ns = a.nvim_create_namespace("Bookmarks" .. group_nr)
  local sign = self.signs[group_nr]
  local virt_text = self.virt_text[group_nr]

  self.groups[group_nr] = { ns = ns, sign = sign, virt_text = virt_text, marks = {} }
end

function Bookmarks:place_mark(group_nr, bufnr)
  bufnr = bufnr or a.nvim_get_current_buf()
  local group = self.groups[group_nr]

  if not group then
    self:init(group_nr)
    group = self.groups[group_nr]
  end

  local pos = a.nvim_win_get_cursor(0)

  if group.marks[bufnr] and group.marks[bufnr][pos[1]] then
    -- disallow multiple bookmarks on a single line
    return
  end

  local data = { buf = bufnr, line = pos[1], col = pos[2], sign_id = -1}

  local display_signs = utils.option_nil(self.opt.buf_signs[bufnr], self.opt.signs)
  if display_signs and group.sign then
    local id = group.sign:byte() * 100 + pos[1]
    self:add_sign(bufnr, group.sign, pos[1], id)
    data.sign_id = id
  end

  local opts = {}
  if group.virt_text then
    opts.virt_text = {{ group.virt_text, "MarkVirtTextHL" }}
    opts.virt_text_pos = "eol"
  end

  local extmark_id = a.nvim_buf_set_extmark(bufnr, group.ns, pos[1]-1, pos[2], opts)

  data.extmark_id = extmark_id

  if not group.marks[bufnr] then
    group.marks[bufnr] = {}
  end
  group.marks[bufnr][pos[1]] = data

  if self.prompt_annotate[group_nr] then
    self:annotate(group_nr)
  end
end

function Bookmarks:toggle_mark(group_nr, bufnr)
  bufnr = bufnr or a.nvim_get_current_buf()
  local group = self.groups[group_nr]

  if not group then
    self:init(group_nr)
    group = self.groups[group_nr]
  end

  local pos = a.nvim_win_get_cursor(0)

  if group.marks[bufnr] and group.marks[bufnr][pos[1]] then
    self:delete_mark(group_nr)
  else
    self:place_mark(group_nr)
  end
end

function Bookmarks:delete_mark(group_nr, bufnr, line)
  bufnr = bufnr or a.nvim_get_current_buf()
  line = line or a.nvim_win_get_cursor(0)[1]
  local group = self.groups[group_nr]

  if not group then
    return
  end

  local mark = group.marks[bufnr][line]

  if not mark then
    return
  end

  if mark.sign_id then
    utils.remove_sign(bufnr, mark.sign_id, "BookmarkSigns")
  end

  a.nvim_buf_del_extmark(bufnr, group.ns, mark.extmark_id)
  group.marks[bufnr][line] = nil
end

function Bookmarks:delete_mark_cursor()
  local bufnr = a.nvim_get_current_buf()
  local pos = a.nvim_win_get_cursor(0)

  local group_nr = group_under_cursor(self.groups, bufnr, pos)
  if not group_nr then
    return
  end

  self:delete_mark(group_nr, bufnr, pos[1])
end

function Bookmarks:delete_all(group_nr)
  local group = self.groups[group_nr]
  if not group then
    return
  end

  for bufnr, buf_marks in pairs(group.marks) do
    for _, mark in pairs(buf_marks) do
      if mark.sign_id then
        utils.remove_sign(bufnr, mark.sign_id, "BookmarkSigns")
      end

      a.nvim_buf_del_extmark(bufnr, group.ns, mark.extmark_id)
    end
    group.marks[bufnr] = nil
  end
end

function Bookmarks:next(group_nr)
  local bufnr = a.nvim_get_current_buf()
  local pos = a.nvim_win_get_cursor(0)

  if not group_nr then
    group_nr = group_under_cursor(self.groups, bufnr, pos)
  end

  local group = self.groups[group_nr]
  if not group then
    return
  end

  local marks = flatten(group.marks)

  if vim.tbl_isempty(marks) then
    return
  end

  local function comparator(x, y, _)
    if (x.line > y.line and x.buf == y.buf) or (x.buf > y.buf) then
      return true
    end

    return false
  end

  local next = utils.search(marks, {buf = bufnr, line=pos[1]},
      {buf=math.huge, line=math.huge}, comparator, false)

  if not next then
    next = marks[1]
  end

  if next.buf ~= bufnr then
    vim.cmd("silent b" .. next.buf)
  end
  a.nvim_win_set_cursor(0, { next.line, next.col })
end

function Bookmarks:prev(group_nr)
  local bufnr = a.nvim_get_current_buf()
  local pos = a.nvim_win_get_cursor(0)

  if not group_nr then
    group_nr = group_under_cursor(self.groups, bufnr, pos)
  end

  local group = self.groups[group_nr]
  if not group then
    return
  end

  local marks = flatten(group.marks)

  if vim.tbl_isempty(marks) then
    return
  end

  local function comparator(x, y, _)
    if (x.line < y.line and x.buf == y.buf) or (x.buf < y.buf) then
      return true
    end

    return false
  end

  local prev = utils.search(marks, {buf = bufnr, line=pos[1]},
      {buf=-1, line=-1}, comparator, false)

  if not prev then
    prev = marks[#marks]
  end

  if prev.buf ~= bufnr then
    vim.cmd("silent b" .. prev.buf)
  end
  a.nvim_win_set_cursor(0, { prev.line, prev.col })
end

function Bookmarks:annotate(group_nr)
  if vim.fn.has("nvim-0.6") ~= 1 then
    error("virtual line annotations requires neovim 0.6 or higher")
  end

  local bufnr = a.nvim_get_current_buf()
  local pos = a.nvim_win_get_cursor(0)

  group_nr = group_nr or group_under_cursor(self.groups, bufnr, pos)

  if not group_nr then
    return
  end

  local bookmark = self.groups[group_nr].marks[bufnr][pos[1]]

  if not bookmark then
    return
  end

  local text = vim.fn.input("annotation: ")

  if text ~= "" then
    a.nvim_buf_set_extmark(bufnr, self.groups[group_nr].ns, bookmark.line-1, bookmark.col, {
      id = bookmark.extmark_id, virt_lines = {{{text, "MarkVirtTextHL"}}},
      virt_lines_above=true,
    })
  else
    a.nvim_buf_del_extmark(bufnr, self.groups[group_nr].ns, bookmark.extmark_id)

    local opts = {}
    if self.groups[group_nr].virt_text then
      opts.virt_text = {{ self.groups[group_nr].virt_text, "MarkVirtTextHL" }}
      opts.virt_text_pos = "eol"
    end
    bookmark.extmark_id = a.nvim_buf_set_extmark(bufnr, self.groups[group_nr].ns, bookmark.line-1,
                                                 bookmark.col, opts)
  end
end

function Bookmarks:refresh()
  local bufnr = a.nvim_get_current_buf()

  -- if we delete and undo really quickly, the extmark's position will be
  -- the same, but the sign will no longer be there. so clear and restore all
  -- signs.

  local buf_marks
  local display_signs
  utils.remove_buf_signs(bufnr, "BookmarkSigns")
  for _, group in pairs(self.groups) do
    buf_marks = group.marks[bufnr]
    if buf_marks then
      for _, mark in pairs(vim.tbl_values(buf_marks)) do
        local line = a.nvim_buf_get_extmark_by_id(bufnr, group.ns,
            mark.extmark_id, {})[1]

        if line + 1 ~= mark.line then
          buf_marks[line + 1] = mark
          buf_marks[mark.line] = nil
          buf_marks[line + 1].line = line + 1
        end
        display_signs = utils.option_nil(self.opt.buf_signs[bufnr], self.opt.signs)
        if display_signs and group.sign then
          self:add_sign(bufnr, group.sign, line + 1, mark.sign_id)
        end
      end
    end
  end
end

function Bookmarks:to_list(list_type, group_nr)
  if not group_nr or not self.groups[group_nr] then
    return
  end

  list_type = list_type or "loclist"
  local list_fn = utils.choose_list(list_type)

  local items = {}
  for bufnr, buffer_marks in pairs(self.groups[group_nr].marks) do
    for line, mark in pairs(buffer_marks) do
      local text = a.nvim_buf_get_lines(bufnr, line-1, line, true)[1]
      table.insert(items, { bufnr=bufnr, lnum=line, col=mark.col + 1, text=text })
    end
  end

  list_fn(items, "r")
end

function Bookmarks:all_to_list(list_type)
  list_type = list_type or "loclist"
  local list_fn = utils.choose_list(list_type)

  local items = {}
  for group_nr, group in pairs(self.groups) do
    for bufnr, buffer_marks in pairs(group.marks) do
      for line, mark in pairs(buffer_marks) do
      local text = a.nvim_buf_get_lines(bufnr, line-1, line, true)[1]
        table.insert(items, { bufnr=bufnr, lnum=line, col=mark.col + 1,
            text="bookmark group "..group_nr..": "..text })
      end
    end
  end

  list_fn(items, "r")
end

function Bookmarks:add_sign(bufnr, text, line, id)
  utils.add_sign(bufnr, text, line, id, "BookmarkSigns", self.priority)
end

function Bookmarks.new()
  return setmetatable({signs = {"!", "@", "#", "$", "%", "^", "&", "*", "(", [0]=")"},
  virt_text = {}, groups = {}, prompt_annotate = {}, opt = {}}, {__index = Bookmarks})
end

return Bookmarks
