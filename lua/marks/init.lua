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
    M.mark_state:place_mark_cursor(input)
    vim.cmd("normal! m" .. input)
  end
end

function M.set_next()
  M.mark_state:place_next_mark_cursor()
end

function M.toggle()
  M.mark_state:toggle_mark_cursor()
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

function M.refresh()
  M.mark_state:on_load()
end

-- set_group[0-9] functions
for i=0,9 do
  M["set_bookmark" .. i] = function() M.bookmark_state:place_mark(i) end
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
  ["m"] = "set",
  ["m,"] = "set_next",
  ["m;"] = "toggle",
  ["m]"] = "next",
  ["m["] = "prev",
  ["m:"] = "preview",
  ["m}"] = "next_bookmark",
  ["m{"] = "prev_bookmark",
  ["dm"] = "delete",
  ["dm-"] = "delete_line",
  ["dm="] = "delete_bookmark",
  ["dm<space>"] = "delete_buf"
}

for i=0,9 do
  M.mappings["m"..tostring(i)] = "set_bookmark" .. i
  M.mappings["dm"..tostring(i)] = "delete_bookmark" .. i
end

local function user_mappings(config)
  local inverse = {}
  for key, cmd in pairs(M.mappings) do
    inverse[cmd] = key
  end

  for cmd, key in pairs(config.mappings) do
    if inverse[cmd] then
      M.mappings[inverse[cmd]] = nil
    end
    if key ~= false then
      M.mappings[key] = cmd
    end
  end
end

local function apply_mappings()
  for key, cmd in pairs(M.mappings) do
    vim.cmd("nnoremap <silent> "..key.." <cmd>lua require'marks'."..cmd.."()<cr>")
  end
end

local function setup_mappings(config)
  user_mappings(config)
  apply_mappings()
end

local function setup_autocommands(state)
  vim.cmd [[augroup Marks_autocmds
    autocmd!
    autocmd BufWinEnter * lua require'marks'.mark_state:on_load()
  augroup end]]

  -- FIXME icky. change this when the ModeChanged
  -- autocommands get merged
  refresh_aucmd = { "augroup Marks_refresh_autocmds", "autocmd!" }
  if not vim.tbl_isempty(vim.tbl_filter(function(v)
        return utils.is_insert_mark(v)
      end, state.builtin_marks)) then
     table.insert(refresh_aucmd,
       "autocmd InsertLeave * lua require'marks'.mark_state:refresh_insert_marks()"
     )
  end

  if not vim.tbl_isempty(vim.tbl_filter(function(v)
        return utils.is_movement_mark(v)
      end, state.builtin_marks)) then
     table.insert(refresh_aucmd,
      "autocmd CursorMoved * lua require'marks'.mark_state:refresh_movement_marks()"
    )
  end

  table.insert(refresh_aucmd, "augroup end")

  vim.cmd(table.concat(refresh_aucmd, "\n"))
end

function M.setup(config)
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
    end
  end

  config.default_mappings = utils.option_nil(config.default_mappings, true)
  setup_mappings(config)
  setup_autocommands(M.mark_state)

  M.mark_state.opt.signs = utils.option_nil(config.signs, true)
  M.mark_state.opt.force_write_shada = utils.option_nil(config.force_write_shada, false)
  M.mark_state.opt.cyclic = utils.option_nil(config.cyclic, true)
end

return M
