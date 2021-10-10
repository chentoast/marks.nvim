if exists("g:loaded_marks")
  finish
endif

hi default link MarkSignHL Identifier
" hi default link MarkSignLineHL Normal
hi default link MarkSignNumHL LineNr

command! MarksToggleSigns lua require'marks'.mark_state:toggle_signs()
command! MarksListBuf exe "lua require'marks'.mark_state:buffer_to_loclist()" | lopen
command! MarksListGlobal exe "lua require'marks'.mark_state:global_to_qflist()" | copen
command! MarksListAll exe "lua require'marks'.mark_state:all_to_qflist()" | copen
