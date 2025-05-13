local mark = require'marks.mark'
local bookmark = require'marks.bookmark'
local utils = require'marks.utils'
local M = {}

function M.set()
  local err, input = pcall(function()
    return string.char(vim.fn.getchar())
  end)
  if not err then
    return
  end

  if utils.is_valid_mark(input) then
    if not M.excluded_fts[vim.bo.ft] and not M.excluded_bts[vim.bo.bt] then
      M.mark_state:place_mark_cursor(input)
    end
    vim.cmd("normal! m" .. input)
  end
end

function M.set_next()
  if not M.excluded_fts[vim.bo.ft] and not M.excluded_bts[vim.bo.bt] then
    M.mark_state:place_next_mark_cursor()
  end
end

function M.toggle()
  if not M.excluded_fts[vim.bo.ft] and not M.excluded_bts[vim.bo.bt] then
    M.mark_state:toggle_mark_cursor()
  end
end

function M.delete()
  local err, input = pcall(function()
    return string.char(vim.fn.getchar())
  end)
  if not err then
    return
  end

  if utils.is_valid_mark(input) then
    M.mark_state:delete_mark(input)
    return
  end
end

function M.delete_line()
  M.mark_state:delete_line_marks()
end

function M.delete_buf()
  M.mark_state:delete_buf_marks()
end

function M.preview()
  M.mark_state:preview_mark()
end

function M.next()
  M.mark_state:next_mark()
end

function M.prev()
  M.mark_state:prev_mark()
end

function M.annotate()
  M.bookmark_state:annotate()
end

function M.refresh(force_reregister)
  if M.excluded_fts[vim.bo.ft] or M.excluded_bts[vim.bo.bt] then
    return
  end

  force_reregister = force_reregister or false
  M.mark_state:refresh(nil, force_reregister)
  M.bookmark_state:refresh()
end

function M._on_delete()
  local bufnr = tonumber(vim.fn.expand("<abuf>"))

  if not bufnr then
    return
  end

  M.mark_state.buffers[bufnr] = nil
  for _, group in pairs(M.bookmark_state.groups) do
    group.marks[bufnr] = nil
  end
end

function M.toggle_signs(bufnr)
  if not bufnr then
    M.mark_state.opt.signs = not M.mark_state.opt.signs
    M.bookmark_state.opt.signs = not M.bookmark_state.opt.signs

    for buf, _ in pairs(M.mark_state.opt.buf_signs) do
      M.mark_state.opt.buf_signs[buf] = M.mark_state.opt.signs
    end

    for buf, _ in pairs(M.bookmark_state.opt.buf_signs) do
      M.bookmark_state.opt.buf_signs[buf] = M.bookmark_state.opt.signs
    end
  else
    M.mark_state.opt.buf_signs[bufnr] = not utils.option_nil(
        M.mark_state.opt.buf_signs[bufnr], M.mark_state.opt.signs)
    M.bookmark_state.opt.buf_signs[bufnr] = not utils.option_nil(
        M.bookmark_state.opt.buf_signs[bufnr], M.bookmark_state.opt.signs)
  end

  M.refresh(true)
end

-- set_group[0-9] functions
for i=0,9 do
  M["set_bookmark" .. i] = function() M.bookmark_state:place_mark(i) end
  M["toggle_bookmark" .. i] = function() M.bookmark_state:toggle_mark(i) end
  M["delete_bookmark" .. i] = function() M.bookmark_state:delete_all(i) end
  M["next_bookmark" .. i] = function() M.bookmark_state:next(i) end
  M["prev_bookmark" .. i] = function() M.bookmark_state:prev(i) end
end

function M.delete_bookmark()
  M.bookmark_state:delete_mark_cursor()
end

function M.next_bookmark()
  M.bookmark_state:next()
end

function M.prev_bookmark()
  M.bookmark_state:prev()
end

M.mappings = {
  set = "m",
  set_next = "m,",
  toggle = "m;",
  next = "m]",
  prev = "m[",
  preview = "m:",
  next_bookmark = "m}",
  prev_bookmark = "m{",
  delete = "dm",
  delete_line = "dm-",
  delete_bookmark = "dm=",
  delete_buf = "dm<space>"
}

for i=0,9 do
  M.mappings["set_bookmark" .. i] = "m"..tostring(i)
  M.mappings["delete_bookmark" .. i] = "dm"..tostring(i)
end

local function user_mappings(config)
  for cmd, key in pairs(config.mappings) do
    if key ~= false then
      M.mappings[cmd] = key
    else
      M.mappings[cmd] = nil
    end
  end
end

local function apply_mappings()
  for cmd, key in pairs(M.mappings) do
    vim.api.nvim_set_keymap("n", key, "", { callback = M[cmd], desc = "marks: "..cmd:gsub("_", " "),
                                            noremap = true })
  end
end

local function setup_mappings(config)
  if not config.default_mappings then
    M.mappings = {}
  end
  if config.mappings then
    user_mappings(config)
  end
  apply_mappings()
end

local function setup_autocommands()
  vim.cmd [[augroup Marks_autocmds
    autocmd!
    autocmd BufEnter * lua require'marks'.refresh(true)
    autocmd BufDelete * lua require'marks'._on_delete()
  augroup end]]
end

function M.setup(config)
  config = config or {}

  M.mark_state = mark.new()
  M.mark_state.builtin_marks = config.builtin_marks or {}

  M.bookmark_state = bookmark.new()

  local bookmark_config
  for i=0,9 do
    bookmark_config = config["bookmark_" .. i]
    if bookmark_config then
      if bookmark_config.sign == false then
        M.bookmark_state.signs[i] = nil
      else
        M.bookmark_state.signs[i] = bookmark_config.sign or M.bookmark_state.signs[i]
      end
      M.bookmark_state.virt_text[i] = bookmark_config.virt_text or
          M.bookmark_state.virt_text[i]
      M.bookmark_state.prompt_annotate[i] = bookmark_config.annotate
    end
  end

  local excluded_fts = {}
  for _, ft in ipairs(config.excluded_filetypes or {}) do
    excluded_fts[ft] = true
  end

  M.excluded_fts = excluded_fts

  local excluded_bts = {}
  for _, bt in ipairs(config.excluded_buftypes or {}) do
    excluded_bts[bt] = true
  end

  M.excluded_bts = excluded_bts

  M.bookmark_state.opt.signs = true
  M.bookmark_state.opt.buf_signs = {}

  config.default_mappings = utils.option_nil(config.default_mappings, true)
  setup_mappings(config)
  setup_autocommands()

  M.mark_state.opt.signs = utils.option_nil(config.signs, true)
  M.mark_state.opt.buf_signs = {}
  M.mark_state.opt.force_write_shada = utils.option_nil(config.force_write_shada, false)
  M.mark_state.opt.cyclic = utils.option_nil(config.cyclic, true)

  M.mark_state.opt.priority = { 10, 10, 10 }
  local mark_priority = M.mark_state.opt.priority
  if type(config.sign_priority) == "table" then
    mark_priority[1] = config.sign_priority.lower or mark_priority[1]
    mark_priority[2] = config.sign_priority.upper or mark_priority[2]
    mark_priority[3] = config.sign_priority.builtin or mark_priority[3]
    M.bookmark_state.priority = config.sign_priority.bookmark or 10
  elseif type(config.sign_priority) == "number" then
    mark_priority[1] = config.sign_priority
    mark_priority[2] = config.sign_priority
    mark_priority[3] = config.sign_priority
    M.bookmark_state.priority = config.sign_priority
  end

  local refresh_interval = utils.option_nil(config.refresh_interval, 150)

  local timer = vim.loop.new_timer()
  timer:start(0, refresh_interval, vim.schedule_wrap(M.refresh))
end

return M
