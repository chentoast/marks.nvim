if exists("g:loaded_marks")
  finish
endif
let g:loaded_marks = 1

hi default link MarkSignHL Identifier
" hi default link MarkSignLineHL Normal
hi default link MarkSignNumHL LineNr

command! MarksToggleSigns lua require'marks'.mark_state:toggle_signs()
command! MarksListBuf exe "lua require'marks'.mark_state:buffer_to_loclist()" | lopen
command! MarksListGlobal exe "lua require'marks'.mark_state:global_to_qflist()" | copen
command! MarksListAll exe "lua require'marks'.mark_state:all_to_qflist()" | copen

nnoremap <Plug>(Marks-set) <cmd> lua require'marks'.set()<cr>
nnoremap <Plug>(Marks-setnext) <cmd> lua require'marks'.set_next()<cr>
nnoremap <Plug>(Marks-toggle) <cmd> lua require'marks'.toggle()<cr>
nnoremap <Plug>(Marks-delete) <cmd> lua require'marks'.delete()<cr>
nnoremap <Plug>(Marks-deleteline) <cmd> lua require'marks'.deleteline()<cr>
nnoremap <Plug>(Marks-deletebuf) <cmd> lua require'marks'.deletebuf()<cr>
nnoremap <Plug>(Marks-deletepreview) <cmd> lua require'marks'.deletepreview()<cr>
nnoremap <Plug>(Marks-next) <cmd> lua require'marks'.next()<cr>
nnoremap <Plug>(Marks-prev) <cmd> lua require'marks'.prev()<cr>
