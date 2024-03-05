local telescope = require("telescope")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local entry_display = require("telescope.pickers.entry_display")
local telescope_utils = require("telescope.utils")
local conf = require("telescope.config").values
local marks = require("marks")

local list_marks_buf = function(opts)
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
      { entry.lnum },
      { entry.line, "String" },
    })
  end

  pickers
    .new(opts, {
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

local list_marks_all = function(opts)
  opts = opts or {}
  local conf_path = { path_display = opts.path_display or conf.path_display or {} }
  local results = marks.mark_state:get_all_list() or {}

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 1 },
      { width = 5 },
      { width = 20 },
      {},
    },
  })

  local make_display = function(entry)
    return displayer({
      { entry.mark, "TelescopeResultsIdentifier" },
      { entry.lnum },
      { entry.line, "String" },
      { telescope_utils.transform_path(conf_path, entry.path) },
    })
  end

  pickers
    .new(opts, {
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

local list_bookmarks_group = function(group, opts)
  opts = opts or {}
  local conf_path = { path_display = opts.path_display or conf.path_display or {} }
  local results = marks.bookmark_state:get_group_list(group) or {}

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 1 },
      { width = 5 },
      { width = 20 },
      {},
    },
  })

  local make_display = function(entry)
    return displayer({
      { entry.group, "TelescopeResultsIdentifier" },
      { entry.lnum },
      { entry.line, "String" },
      { telescope_utils.transform_path(conf_path, entry.path) },
    })
  end

  pickers
    .new(opts, {
      prompt_title = "Bookmark " .. group,
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          entry.value = entry.group
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

local list_bookmarks_all = function(opts)
  opts = opts or {}
  local conf_path = { path_display = opts.path_display or conf.path_display or {} }
  local results = marks.bookmark_state:get_all_list() or {}

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 1 },
      { width = 5 },
      { width = 20 },
      {},
    },
  })

  local make_display = function(entry)
    return displayer({
      { entry.group, "TelescopeResultsIdentifier" },
      { entry.lnum },
      { entry.line, "String" },
      { telescope_utils.transform_path(conf_path, entry.path) },
    })
  end

  pickers
    .new(opts, {
      prompt_title = "All Bookmarks",
      finder = finders.new_table({
        results = results,
        entry_maker = function(entry)
          entry.value = entry.group
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
    marks_list_buf = list_marks_buf,
    marks_list_all = list_marks_all,
    bookmarks_list_group = list_bookmarks_group,
    bookmarks_list_all = list_bookmarks_all,
  },
})
