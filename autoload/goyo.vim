" Copyright (c) 2015 Junegunn Choi
"
" MIT License
"
" Permission is hereby granted, free of charge, to any person obtaining
" a copy of this software and associated documentation files (the
" "Software"), to deal in the Software without restriction, including
" without limitation the rights to use, copy, modify, merge, publish,
" distribute, sublicense, and/or sell copies of the Software, and to
" permit persons to whom the Software is furnished to do so, subject to
" the following conditions:
"
" The above copyright notice and this permission notice shall be
" included in all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
" EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
" MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
" NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
" LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
" OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
" WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

let s:cpo_save = &cpo
set cpo&vim

function! s:const(val, min, max)
  return min([max([a:val, a:min]), a:max])
endfunction

function! s:get_color(group, attr)
  return synIDattr(synIDtrans(hlID(a:group)), a:attr)
endfunction

function! s:set_color(group, attr, color)
  let gui = has('gui_running') || has('termguicolors') && &termguicolors
  execute printf('hi %s %s%s=%s', a:group, gui ? 'gui' : 'cterm', a:attr, a:color)
endfunction

nnoremap <silent> <Plug>(goyos-off) :call <sid>goyos_off()<cr>

" comment lines 44
function! s:blank(repel)
  if bufwinnr(t:goyos_pads.r) <= bufwinnr(t:goyos_pads.l) + 1
    " \ || bufwinnr(t:goyos_pads.b) <= bufwinnr(t:goyos_pads.t) + 3
    call feedkeys("\<Plug>(goyos-off)")
  endif
  execute 'noautocmd wincmd' a:repel
endfunction

function! s:init_pad(command)
  execute a:command

  setlocal buftype=nofile bufhidden=wipe nomodifiable nobuflisted noswapfile
      \ nonu nocursorline nocursorcolumn winfixwidth winfixheight statusline=\ 
  if exists('&rnu')
    setlocal nornu
  endif
  if exists('&colorcolumn')
    setlocal colorcolumn=
  endif
  let bufnr = winbufnr(0)

  execute winnr('#') . 'wincmd w'
  return bufnr
endfunction

function! s:setup_pad(bufnr, vert, size, repel)
  let win = bufwinnr(a:bufnr)
  execute win . 'wincmd w'
  execute (a:vert ? 'vertical ' : '') . 'resize ' . max([0, a:size])
  augroup goyosp
    execute 'autocmd WinEnter,CursorMoved <buffer> nested call s:blank("'.a:repel.'")'
    autocmd WinLeave <buffer> call s:hide_statusline()
  augroup END

  " To hide scrollbars of pad windows in GVim
  let diff = winheight(0) - line('$') - (has('gui_running') ? 2 : 0)
  if diff > 0
    setlocal modifiable
    call append(0, map(range(1, diff), '""'))
    normal! gg
    setlocal nomodifiable
  endif
  execute winnr('#') . 'wincmd w'
endfunction

function! s:resize_pads()
  augroup goyosp
    autocmd!
  augroup END

  let t:goyos_dim.width = s:const(t:goyos_dim.width, 2, &columns)
  let t:goyos_dim.height = s:const(t:goyos_dim.height, 2, &lines)

  let vmargin = max([0, (&lines - t:goyos_dim.height) / 2 - 1])
  let yoff = s:const(t:goyos_dim.yoff, - vmargin, vmargin)
  let top = vmargin + yoff
  let bot = vmargin - yoff - 1
  " 2 following lines to comment
  " call s:setup_pad(t:goyos_pads.t, 0, top, 'j')
  " call s:setup_pad(t:goyos_pads.b, 0, bot, 'k')

  let nwidth  = max([len(string(line('$'))) + 1, &numberwidth])
  let width   = t:goyos_dim.width + (&number ? nwidth : 0)
  let hmargin = max([0, (&columns - width) / 2 - 1])
  let xoff    = s:const(t:goyos_dim.xoff, - hmargin, hmargin)
  call s:setup_pad(t:goyos_pads.l, 1, hmargin + xoff, 'l')
  call s:setup_pad(t:goyos_pads.r, 1, hmargin - xoff, 'h')
endfunction

function! s:tranquilize()
  let bg = s:get_color('Normal', 'bg#')
  for grp in ['NonText', 'FoldColumn', 'ColorColumn', 'VertSplit',
            \ 'StatusLine', 'StatusLineNC', 'SignColumn']
    " -1 on Vim / '' on GVim
    if bg == -1 || empty(bg)
      call s:set_color(grp, 'fg', get(g:, 'goyos_bg', 'black'))
      call s:set_color(grp, 'bg', 'NONE')
    else
      call s:set_color(grp, 'fg', bg)
      call s:set_color(grp, 'bg', bg)
    endif
    call s:set_color(grp, '', 'NONE')
  endfor
endfunction

function! s:hide_statusline()
  setlocal statusline=\ 
endfunction

function! s:hide_linenr()
  if !get(g:, 'goyos_linenr', 0)
    setlocal nonu
    if exists('&rnu')
      setlocal nornu
    endif
  endif
  if exists('&colorcolumn')
    setlocal colorcolumn=
  endif
endfunction

function! s:maps_nop()
  let mapped = filter(['R', 'H', 'J', 'K', 'L', '|', '_'],
                    \ "empty(maparg(\"\<c-w>\".v:val, 'n'))")
  for c in mapped
    execute 'nnoremap <c-w>'.escape(c, '|').' <nop>'
  endfor
  return mapped
endfunction

function! s:maps_resize()
  let commands = {
  \ '=': ':<c-u>let t:goyos_dim = <sid>parse_arg(t:goyos_dim_expr) <bar> call <sid>resize_pads()<cr>',
  \ '>': ':<c-u>let t:goyos_dim.width = winwidth(0) + 2 * v:count1 <bar> call <sid>resize_pads()<cr>',
  \ '<': ':<c-u>let t:goyos_dim.width = winwidth(0) - 2 * v:count1 <bar> call <sid>resize_pads()<cr>',
  \ '+': ':<c-u>let t:goyos_dim.height += 2 * v:count1 <bar> call <sid>resize_pads()<cr>',
  \ '-': ':<c-u>let t:goyos_dim.height -= 2 * v:count1 <bar> call <sid>resize_pads()<cr>'
  \ }
  let mapped = filter(keys(commands), "empty(maparg(\"\<c-w>\".v:val, 'n'))")
  for c in mapped
    execute 'nnoremap <silent> <c-w>'.c.' '.commands[c]
  endfor
  return mapped
endfunction

nnoremap <silent> <plug>(goyos-resize) :<c-u>call <sid>resize_pads()<cr>

function! s:goyos_on(dim)
  let dim = s:parse_arg(a:dim)
  if empty(dim)
    return
  endif

  let s:orig_tab = tabpagenr()
  let settings =
    \ { 'laststatus':    &laststatus,
    \   'showtabline':   &showtabline,
    \   'fillchars':     &fillchars,
    \   'winminwidth':   &winminwidth,
    \   'winwidth':      &winwidth,
    \   'winminheight':  &winminheight,
    \   'winheight':     &winheight,
    \   'ruler':         &ruler,
    \   'sidescroll':    &sidescroll,
    \   'sidescrolloff': &sidescrolloff
    \ }

  " New tab
  tab split

  let t:goyos_master = winbufnr(0)
  let t:goyos_dim = dim
  let t:goyos_dim_expr = a:dim
  let t:goyos_pads = {}
  let t:goyos_revert = settings
  let t:goyos_maps = extend(s:maps_nop(), s:maps_resize())
  if has('gui_running')
    let t:goyos_revert.guioptions = &guioptions
  endif

  " vim-gitgutter
  let t:goyos_disabled_gitgutter = get(g:, 'gitgutter_enabled', 0)
  if t:goyos_disabled_gitgutter
    silent! GitGutterDisable
  endif

  " vim-signify
  let t:goyos_disabled_signify = !empty(getbufvar(bufnr(''), 'sy'))
  if t:goyos_disabled_signify
    SignifyToggle
  endif

  " vim-airline
  let t:goyos_disabled_airline = exists('#airline')
  if t:goyos_disabled_airline
    AirlineToggle
  endif

  " vim-powerline
  let t:goyos_disabled_powerline = exists('#PowerlineMain')
  if t:goyos_disabled_powerline
    augroup PowerlineMain
      autocmd!
    augroup END
    augroup! PowerlineMain
  endif

  " lightline.vim
  let t:goyos_disabled_lightline = exists('#lightline')
  if t:goyos_disabled_lightline
    silent! call lightline#disable()
  endif

  call s:hide_linenr()
  " Global options
  let &winheight = max([&winminheight, 1])
  set winminheight=1
  set winheight=1
  set winminwidth=1 winwidth=1
  set laststatus=0
  set showtabline=0
  set noruler
  set fillchars+=vert:\ 
  set fillchars+=stl:\ 
  set fillchars+=stlnc:\ 
  set sidescroll=1
  set sidescrolloff=0

  " Hide left-hand scrollbars
  if has('gui_running')
    set guioptions-=l
    set guioptions-=L
  endif

  let t:goyos_pads.l = s:init_pad('vertical topleft new')
  let t:goyos_pads.r = s:init_pad('vertical botright new')
  " 2 following lines
  " let t:goyos_pads.t = s:init_pad('topleft new')
  " let t:goyos_pads.b = s:init_pad('botright new')

  call s:resize_pads()
  call s:tranquilize()

  augroup goyos
    autocmd!
    autocmd TabLeave    * nested call s:goyos_off()
    autocmd VimResized  *        call s:resize_pads()
    autocmd ColorScheme *        call s:tranquilize()
    autocmd BufWinEnter *        call s:hide_linenr() | call s:hide_statusline()
    autocmd WinEnter,WinLeave *  call s:hide_statusline()
    if has('nvim')
      autocmd TermClose * call feedkeys("\<plug>(goyos-resize)")
    endif
  augroup END

  call s:hide_statusline()
  if exists('g:goyos_callbacks[0]')
    call g:goyos_callbacks[0]()
  endif
  if exists('#User#GoyosEnter')
    doautocmd User GoyosEnter
  endif
endfunction

function! s:goyos_off()
  if !exists('#goyos')
    return
  endif

  " Oops, not this tab
  if !exists('t:goyos_revert')
    return
  endif

  " Clear auto commands
  augroup goyos
    autocmd!
  augroup END
  augroup! goyos
  augroup goyosp
    autocmd!
  augroup END
  augroup! goyosp

  for c in t:goyos_maps
    execute 'nunmap <c-w>'.escape(c, '|')
  endfor

  let goyos_revert             = t:goyos_revert
  let goyos_disabled_gitgutter = t:goyos_disabled_gitgutter
  let goyos_disabled_signify   = t:goyos_disabled_signify
  let goyos_disabled_airline   = t:goyos_disabled_airline
  let goyos_disabled_powerline = t:goyos_disabled_powerline
  let goyos_disabled_lightline = t:goyos_disabled_lightline
  let goyos_orig_buffer        = t:goyos_master
  let [line, col]             = [line('.'), col('.')]

  if tabpagenr() == 1
    tabnew
    normal! gt
    bd
  endif
  tabclose
  execute 'normal! '.s:orig_tab.'gt'
  if winbufnr(0) == goyos_orig_buffer
    " Doesn't work if window closed with `q`
    execute printf('normal! %dG%d|', line, col)
  endif

  let wmw = remove(goyos_revert, 'winminwidth')
  let ww  = remove(goyos_revert, 'winwidth')
  let &winwidth     = ww
  let &winminwidth  = wmw
  let wmh = remove(goyos_revert, 'winminheight')
  let wh  = remove(goyos_revert, 'winheight')
  let &winheight    = max([wmh, 1])
  let &winminheight = wmh
  let &winheight    = wh

  for [k, v] in items(goyos_revert)
    execute printf('let &%s = %s', k, string(v))
  endfor
  execute 'colo '. get(g:, 'colors_name', 'default')

  if goyos_disabled_gitgutter
    silent! GitGutterEnable
  endif

  if goyos_disabled_signify
    silent! if !b:sy.active
      SignifyToggle
    endif
  endif

  if goyos_disabled_airline && !exists('#airline')
    AirlineToggle
    " For some reason, Airline requires two refreshes to avoid display
    " artifacts
    silent! AirlineRefresh
    silent! AirlineRefresh
  endif

  if goyos_disabled_powerline && !exists('#PowerlineMain')
    doautocmd PowerlineStartup VimEnter
    silent! PowerlineReloadColorscheme
  endif

  if goyos_disabled_lightline
    silent! call lightline#enable()
  endif

  if exists('#Powerline')
    doautocmd Powerline ColorScheme
  endif

  if exists('g:goyos_callbacks[1]')
    call g:goyos_callbacks[1]()
  endif
  if exists('#User#GoyosLeave')
    doautocmd User GoyosLeave
  endif
endfunction

function! s:relsz(expr, limit)
  if a:expr !~ '%$'
    return str2nr(a:expr)
  endif
  return a:limit * str2nr(a:expr[:-2]) / 100
endfunction

function! s:parse_arg(arg)
  if exists('g:goyos_height') || !exists('g:goyos_margin_top') && !exists('g:goyos_margin_bottom')
    let height = s:relsz(get(g:, 'goyos_height', '85%'), &lines)
    " let height = s:relsz(get(g:, 'goyos_height', '100%'), &lines)
    let yoff = 0
  else
    let top = max([0, s:relsz(get(g:, 'goyos_margin_top', 4), &lines)])
    let bot = max([0, s:relsz(get(g:, 'goyos_margin_bottom', 4), &lines)])
    let height = &lines - top - bot
    let yoff = top - bot
  endif

  let dim = { 'width':  s:relsz(get(g:, 'goyos_width', 80), &columns),
            \ 'height': height,
            \ 'xoff':   0,
            \ 'yoff':   yoff }
  if empty(a:arg)
    return dim
  endif
  let parts = matchlist(a:arg, '^\s*\([0-9]\+%\?\)\?\([+-][0-9]\+%\?\)\?\%(x\([0-9]\+%\?\)\?\([+-][0-9]\+%\?\)\?\)\?\s*$')
  if empty(parts)
    echohl WarningMsg
    echo 'Invalid dimension expression: '.a:arg
    echohl None
    return {}
  endif
  if !empty(parts[1]) | let dim.width  = s:relsz(parts[1], &columns) | endif
  if !empty(parts[2]) | let dim.xoff   = s:relsz(parts[2], &columns) | endif
  if !empty(parts[3]) | let dim.height = s:relsz(parts[3], &lines)   | endif
  if !empty(parts[4]) | let dim.yoff   = s:relsz(parts[4], &lines)   | endif
  return dim
endfunction

function! goyos#execute(bang, dim)
  if a:bang
    if exists('#goyos')
      call s:goyos_off()
    endif
  else
    if exists('#goyos') == 0
      call s:goyos_on(a:dim)
    elseif !empty(a:dim)
      if winnr('$') < 5
        call s:goyos_off()
        return goyos#execute(a:bang, a:dim)
      endif
      let dim = s:parse_arg(a:dim)
      if !empty(dim)
        let t:goyos_dim = dim
        let t:goyos_dim_expr = a:dim
        call s:resize_pads()
      endif
    else
      call s:goyos_off()
    end
  end
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

