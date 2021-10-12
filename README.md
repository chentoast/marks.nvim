# marks.nvim
A better user experience for interacting with and manipulating Vim marks.
Requires Neovim 0.5+.

![](../assets/marks-demo.gif)

## Features

- view marks in the sign column
- quickly add, delete, and toggle marks
- cycle between marks
- preview marks in floating windows
- extract marks to quickfix/location list

## Installation

I recommend you use your favorite vim plugin manager, like vim-plug, or packer.

For example, using vim-plug, you would add the following line:

`Plug 'chentau/marks.nvim'`

If you want to manually install, you can clone this repository, and add the path
to the cloned repo to your runtimepath: `set rtp+=/path/to/cloned/repo`.

## Setup

```lua
require'marks'.setup {
  default_mappings = true, -- whether to map keybinds or not. default true
  builtin_marks = { ".", "<", ">", "^" } -- which builtin marks to show. default {}
  cyclic = true -- whether movements cycle back to the beginning/end of buffer. default true
  force_write_shada = false -- whether the shada file is updated after modifying uppercase marks. default false
  mappings = {}
}
```

See `:help marks-setup` for all of the keys that can be passed to the setup function.

## Mappings

The following default mappings are included:

```
    mx              Set mark x
    m,              Set the next available alphabetical (lowercase) mark
    m;              Toggle the next available mark at the current line
    dmx             Delete mark x
    dm-             Delete all marks on the current line
    dm<space>       Delete all marks in the current buffer
    m]              Move to next mark
    m[              Move to previous mark
    m:              Preview mark. This will prompt you for a specific mark to
                    preview; press <cr> to preview the next mark.
```

Set `default_mappings = false` in the setup function if you don't want to have these mapped.

By default, mappings are prefixed with a "leader" key, such that set/move/preview mappings are done with `<leader><key>` and delete operations are done with `d<leader><key>`.

You can change both the leader key and also the keybindings by setting the `mapping` table in the setup function:

```lua
require'marks'.setup {
  mappings = {
    leader = "n", -- now, setting mark a is done by pressing "na", and deleting mark a is done via "dna"
    set_next = ",", -- "n," to set the next available mark
    next = "]", -- "n]" to go to next mark
    preview = ";" -- "n;" to preview mark (will wait for input)
  }
}
```

The following keys are available to be passed to the mapping table:

```
  leader        prefixes all commands. also handles setting and deleting named marks.
  set_next      set next available lowercase mark at cursor.
  toggle        toggle next available mark at cursor.
  delete_line   deletes all marks on current line.
  delete_buf    deletes all marks in current buffer.
  next          goes to next mark in buffer.
  prev          goes to previous mark in buffer.
  preview       previews mark (will wait for user input). press <cr> to just preview the next mark.
  set           sets a letter mark (will wait for input). the leader key implements this functionality by default,
                so you only need to set this if you disable the leader (see below)
  delete        delete a letter mark (will wait for input). just like 'set', this is automatically handled if
                the leader key is present, so only set this if the leader is disabled.
```

If you don't like this prefix behavior, or you want to set mappings that are multiple keys long, you can set `leader = false` to map things the regular way. Note that since the leader key handles setting and deleting letter marks, you will need to specify the `set` and `delete` keys if you disable the leader:

```lua
require'marks'.setup {
  mappings = {
    leader = false, -- set leader to false to disable prefix mappings
    next = "]]",
    set = "m", -- set mark a by pressing 'ma'
    delete = "dm" -- delete mark a by pressing 'dma'
  }
}
```

marks.nvim also provides a list of `<Plug>` mappings for you, in case you want to map things via vimscript. The list of provided mappings are:

```
<Plug>(Marks-set)
<Plug>(Marks-setnext)
<Plug>(Marks-toggle)
<Plug>(Marks-delete)
<Plug>(Marks-deleteline)
<Plug>(Marks-deletebuf)
<Plug>(Marks-preview)
<Plug>(Marks-next)
<Plug>(Marks-prev)
```

See `:help marks-mappings` for more information.

## See Also

[vim-signature](https://github.com/kshenoy/vim-signature)

[vim-bookmarks](https://github.com/MattesGroeger/vim-bookmarks)

## Todos

- Bookmarks, with signs and virtual text
- Operator pending mappings and count aware movement mappings
