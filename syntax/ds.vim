if exists("b:current_syntax") | finish | endif
runtime! syntax/javascript.vim
unlet! b:current_syntax
syn match dwApiModule /dw\.\(catalog\|content\|crypto\|customer\|i18n\|io\|net\|object\|order\|system\|template\|util\|web\)/
syn keyword sfccClass Product ProductMgr Order OrderMgr Customer CustomerMgr Site Transaction Resource URLUtils
hi def link dwApiModule Type
hi def link sfccClass Type
let b:current_syntax = "ds"
