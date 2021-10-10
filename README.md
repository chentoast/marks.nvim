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

If you want to manually install, you can clone this repository, and add the path
to the cloned repo to your `runtimepath`.

## Setup

```lua
require'marks'.setup {
  default_mappings = true, -- whether to map keybinds or not
  builtin_marks = { ".", "<", ">", "^" } -- which builtin marks to show
  mappings = {}
}
```

See `:help marks-setup` for all of the keys that can be passed to the setup function.

## Mappings

By default, the following mappings are included:

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

See `:help marks-mappings` for more information on how to remap these mappings.

## See Also

[vim-signature](https://github.com/kshenoy/vim-signature)

[vim-bookmarks](https://github.com/MattesGroeger/vim-bookmarks)

## Todos

- Mark groups, with both signs and virtual text
- Operator pending mappings
