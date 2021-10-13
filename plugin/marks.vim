if exists("g:loaded_marks")
  finish
endif
let g:loaded_marks = 1

hi default link MarkSignHL Identifier
" hi default link MarkSignLineHL Normal
hi default link MarkSignNumHL LineNr
hi default link MarkVirtTextHL Comment

command! MarksToggleSigns lua require'marks'.mark_state:toggle_signs()
command! MarksListBuf exe "lua require'marks'.mark_state:buffer_to_loclist()" | lopen
command! MarksListGlobal exe "lua require'marks'.mark_state:global_to_loclist()" | lopen
command! MarksListAll exe "lua require'marks'.mark_state:all_to_loclist()" | lopen
command! -nargs=1 BookmarksList exe "lua require'marks'.bookmark_state:to_loclist("..<args>..")" | lopen
command! BookmarksListAll exe "lua require'marks'.bookmark_state:all_to_loclist()" | lopen

nnoremap <Plug>(Marks-set) <cmd> lua require'marks'.set()<cr>
nnoremap <Plug>(Marks-setnext) <cmd> lua require'marks'.set_next()<cr>
nnoremap <Plug>(Marks-toggle) <cmd> lua require'marks'.toggle()<cr>
nnoremap <Plug>(Marks-delete) <cmd> lua require'marks'.delete()<cr>
nnoremap <Plug>(Marks-deleteline) <cmd> lua require'marks'.delete_line()<cr>
nnoremap <Plug>(Marks-deletebuf) <cmd> lua require'marks'.delete_buf()<cr>
nnoremap <Plug>(Marks-preview) <cmd> lua require'marks'.preview()<cr>
nnoremap <Plug>(Marks-next) <cmd> lua require'marks'.next()<cr>
nnoremap <Plug>(Marks-prev) <cmd> lua require'marks'.prev()<cr>
nnoremap <Plug>(Marks-delete-bookmark) <cmd> lua require'marks'.delete_bookmark()<cr>
nnoremap <Plug>(Marks-next-bookmark) <cmd> lua require'marks'.next_bookmark()<cr>
nnoremap <Plug>(Marks-prev-bookmark) <cmd> lua require'marks'.prev_bookmark()<cr>

for i in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
  exe "nnoremap <Plug>(Marks-set-bookmark"..i..") <cmd> lua require'marks'.set_bookmark"..i.."()<cr>"
  exe "nnoremap <Plug>(Marks-delete-bookmark"..i..") <cmd> lua require'marks'.delete_bookmark"..i.."()<cr>"
  exe "nnoremap <Plug>(Marks-next-bookmark"..i..") <cmd> lua require'marks'.next("..i..")<cr>"
  exe "nnoremap <Plug>(Marks-prev-bookmark"..i..") <cmd> lua require'marks'.prev("..i..")<cr>"
endfor
