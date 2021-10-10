local M = { sign_cache = {} }
local builtin_marks = { ["."] = true, ["^"] = true, ["`"] = true, ["'"] = true,
                        ['"'] = true, ["<"] = true, [">"] = true, ["["] = true,
                        ["]"] = true }

-- marks updated after InsertLeave
local insert_marks = { ["."] = true, ["^"] = true }
-- marks updated after CursorMoved
local movement_marks = { ["`"] = true, ["'"] = true,
                        ['"'] = true, ["<"] = true, [">"] = true, ["["] = true,
                        ["]"] = true }

function M.add_sign(bufnr, text, line, id)
  local sign_name = "Marks_" .. text
  if not M.sign_cache[sign_name] then
    M.sign_cache[sign_name] = true
    vim.fn.sign_define(sign_name, { text = text, texthl = "MarkSignHL",
                                    numhl = "MarkSignNumHL" })
  end
  vim.fn.sign_place(id, "MarkSigns", sign_name, bufnr, { lnum = line })
end

function M.remove_sign(bufnr, id)
  vim.fn.sign_unplace("MarkSigns", { buffer = bufnr, id = id })
end

function M.remove_buf_signs(bufnr)
  vim.fn.sign_unplace("MarkSigns", { buffer = bufnr })
end

function M.is_valid_mark(char)
  return M.is_letter(char) or builtin_marks[char]
end

function M.is_special(char)
  return builtin_marks[char] ~= nil
end

function M.is_letter(char)
  return M.is_upper(char) or M.is_lower(char)
end

function M.is_upper(char)
  return (65 <= char:byte() and char:byte() <= 90)
end

function M.is_lower(char)
  return (97 <= char:byte() and char:byte() <= 122)
end

function M.is_insert_mark(mark)
  return insert_marks[mark]
end

function M.is_movement_mark(mark)
  return movement_marks[mark]
end

function M.option_nil(option, default)
  if option == nil then
    return default
  else
    return option
  end
end

return M
