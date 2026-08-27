if exists("b:current_syntax") | finish | endif
runtime! syntax/html.vim
unlet! b:current_syntax
syn region ismlComment start="<iscomment\>" end="</iscomment>" keepend
syn match ismlTagName /<\/\?is\w\+/ containedin=htmlTag
syn region ismlExpr start="\${" end="}" containedin=ALLBUT,ismlComment
hi def link ismlTagName Statement
hi def link ismlExpr Special
hi def link ismlComment Comment
let b:current_syntax = "isml"
