local M = { sign_cache = {} }
local builtin_marks = { ["."] = true, ["^"] = true, ["`"] = true, ["'"] = true,
                        ['"'] = true, ["<"] = true, [">"] = true, ["["] = true,
                        ["]"] = true }
for i = 0,9 do
  builtin_marks[tostring(i)] = true
end

function M.add_sign(bufnr, text, line, id, group, priority)
  priority = priority or 10
  local sign_name = "Marks_" .. text
  if not M.sign_cache[sign_name] then
    M.sign_cache[sign_name] = true
    vim.fn.sign_define(sign_name, { text = text, texthl = "MarkSignHL",
                                    numhl = "MarkSignNumHL" })
  end
  vim.fn.sign_place(id, group, sign_name, bufnr, { lnum = line, priority = priority })
end

function M.remove_sign(bufnr, id, group)
  group = group or "MarkSigns"
  vim.fn.sign_unplace(group, { buffer = bufnr, id = id })
end

function M.remove_buf_signs(bufnr, group)
  group = group or "MarkSigns"
  vim.fn.sign_unplace(group, { buffer = bufnr })
end

function M.search(marks, start_data, init_values, cmp, cyclic)
  local min_next = init_values
  local min_next_set = false
  -- if we need to wrap around
  local min = init_values

  for mark, data in pairs(marks) do
    if cmp(data, start_data, mark) and not cmp(data, min_next, mark) then
      min_next = data
      min_next_set = true
    end
    if cyclic and not cmp(data, min, mark) then
      min = data
    end
  end
  if not cyclic then
    return min_next_set and min_next or nil
  end
  return min_next_set and min_next or min
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

function M.option_nil(option, default)
  if option == nil then
    return default
  else
    return option
  end
end

function M.choose_list(list_type)
  local list_fn
  if list_type == "loclist" then
    list_fn = function(items, flags) vim.fn.setloclist(0, items, flags) end
  elseif list_type == "quickfixlist" then
    list_fn = vim.fn.setqflist
  end
  return list_fn
end

return M
