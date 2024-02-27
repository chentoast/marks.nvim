local telescope = require("telescope")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local entry_display = require("telescope.pickers.entry_display")
local conf = require("telescope.config").values
local marks = require("marks")

local list_buf = function(opts)
  opts = opts or {}
  local results = marks.mark_state:get_buf_list() or {}

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 3 },
      { width = 10 },
      {},
    },
  })

  local make_display = function(entry)
    return displayer({
      { entry.mark, "TelescopeResultsIdentifier" },
      { "l " .. entry.lnum },
      { entry.line, "String" },
    })
  end

  pickers
    .new(opts or {}, {
      prompt_title = "Buffer Marks",
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          entry.value = entry.mark
          entry.ordinal = entry.line
          entry.display = make_display
          return entry
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = conf.grep_previewer(opts),
    })
    :find()
end

local list_all = function(opts)
  opts = opts or {}
  local results = marks.mark_state:get_all_list() or {}

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 3 },
      { width = 10 },
      {},
    },
  })

  local make_display = function(entry)
    return displayer({
      { entry.mark, "TelescopeResultsIdentifier" },
      { "l " .. entry.lnum },
      { entry.filename, "String" },
    })
  end

  pickers
    .new(opts or {}, {
      prompt_title = "All Marks",
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          entry.value = entry.mark
          entry.ordinal = entry.line
          entry.display = make_display
          return entry
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = conf.grep_previewer(opts),
    })
    :find()
end

return telescope.register_extension({
  exports = {
    marks_list_buf = list_buf,
    marks_list_all = list_all
  },
})
