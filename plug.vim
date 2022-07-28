" ============================
    " https://github.com/junegunn/vim-plug
    " Copyright (c) 2017 Junegunn Choi
    " MIT License
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

if exists('g:loaded_plug')  | finish  | en
let g:loaded_plug = 1

let s:cpo_save = &cpo  | set cpo&vim

" var
    let s:plug_src = 'https://github.com/sisrfeng/pluger'
    let s:plug_tab = get(s:, 'plug_tab', -1)
    let s:plug_buf = get(s:, 'plug_buf', -1)
    let s:mac_gui = has('gui_macvim') && has('gui_running')
    let s:is_win = has('win32')
    let s:nvim = has('nvim-0.2') || (has('nvim') && exists('*jobwait') && !s:is_win)
    let s:vim8 = has('patch-8.0.0039') && exists('*job_start')
    if s:is_win && &shellslash
        set noshellslash
        let s:me = resolve(expand('<sfile>:p'))
        set shellslash
    el
        let s:me = resolve(expand('<sfile>:p'))
    en
    let s:base_spec = { 'branch': '', 'frozen': 0 }
    let s:TYPE = {
    \   'string':  type(''),
    \   'list':    type([]),
    \   'dict':    type({}),
    \   'funcref': type(function('call'))
    \ }
    let s:loaded = get(s:, 'loaded', {})
    let s:triggers = get(s:, 'triggers', {})

fun! s:is_powershell(shell)
    return a:shell =~# 'powershell\(\.exe\)\?$' || a:shell =~# 'pwsh\(\.exe\)\?$'
endf

fun! s:isabsolute(dir) abort
    return a:dir =~# '^/' || (has('win32') && a:dir =~? '^\%(\\\|[A-Z]:\)')
endf

fun! s:git_dir(dir) abort
    let gitdir = s:end_slash(a:dir) . '/.git'
    if isdirectory(gitdir)
        return gitdir
    en
    if !filereadable(gitdir)
        return ''
    en
    let gitdir = matchstr(get(readfile(gitdir), 0, ''), '^gitdir: \zs.*')
    if len(gitdir) && !s:isabsolute(gitdir)
        let gitdir = a:dir . '/' . gitdir
    en
    return isdirectory(gitdir) ? gitdir : ''
endf

fun! s:git_origin_url(dir) abort
    let gitdir = s:git_dir(a:dir)
    let config = gitdir . '/config'
    if empty(gitdir) || !filereadable(config)
        return ''
    en
    return matchstr(join(readfile(config)), '\[remote "origin"\].\{-}url\s*=\s*\zs\S*\ze')
endf

fun! s:git_revision(dir) abort
    let gitdir = s:git_dir(a:dir)
    let head = gitdir . '/HEAD'
    if empty(gitdir) || !filereadable(head)
        return ''
    en

    let line = get(readfile(head), 0, '')
    let ref = matchstr(line, '^ref: \zs.*')
    if empty(ref)
        return line
    en

    if filereadable(gitdir . '/' . ref)
        return get(readfile(gitdir . '/' . ref), 0, '')
    en

    if filereadable(gitdir . '/packed-refs')
        for line in readfile(gitdir . '/packed-refs')
            if line =~# ' ' . ref
                return matchstr(line, '^[0-9a-f]*')
            en
        endfor
    en

    return ''
endf

fun! s:git_local_branch(dir) abort
    let gitdir = s:git_dir(a:dir)
    let head = gitdir . '/HEAD'
    if empty(gitdir) || !filereadable(head)
        return ''
    en
    let branch = matchstr(get(readfile(head), 0, ''), '^ref: refs/heads/\zs.*')
    return len(branch) ? branch : 'HEAD'
endf

fun! s:git_origin_branch(spec)
    if len(a:spec.branch)
        return a:spec.branch
    en

    " The file may not be present if this is a local repository
    let gitdir = s:git_dir(a:spec.dir)
    let origin_head = gitdir.'/refs/remotes/origin/HEAD'
    if len(gitdir) && filereadable(origin_head)
        return matchstr(get(readfile(origin_head), 0, ''),
                                    \ '^ref: refs/remotes/origin/\zs.*')
    en

    " The command may not return the name of a branch in detached HEAD state
    let result = s:lines(s:system('git symbolic-ref --short HEAD', a:spec.dir))
    return v:shell_error
        \ ? ''
        \ : result[-1]
endf

if s:is_win
    fun! s:plug_call(fn, ...)
        let shellslash = &shellslash
        try
            set noshellslash
            return call(a:fn, a:000)
        finally
            let &shellslash = shellslash
        endtry
    endf
el
    fun! s:plug_call(fn, ...)
        return call(a:fn, a:000)
    endf
en

fun! s:plug_getcwd()
    return s:plug_call('getcwd')
endf

fun! s:plug_fnamemodify(fname, mods)
    return s:plug_call('fnamemodify', a:fname, a:mods)
endf

fun! s:plug_expand(fmt)
    return s:plug_call('expand', a:fmt, 1)
endf

fun! s:plug_tempname()
    return s:plug_call('tempname')
endf


fun! plug#begin(...)
    "\ 每次call ReloaD() 都会到这里
    "\ echom 'plug#begin()开始'
    if a:0 > 0
        let home = s:path(s:plug_fnamemodify(s:plug_expand(a:1), ':p'))
    elseif exists('g:plug_home')
        let home = s:path(g:plug_home)
    elseif has('nvim')
        let home = stdpath('data') . '/plugged'
    elseif !empty(&rtp)
        let home = s:path(split(&rtp, ',')[0]) . '/plugged'
    el
        return s:err('Unable to determine plug home. Try calling plug#begin() with a path argument.')
    en

    echom 'home是' . home
    "\ /home/wf/.local/share/nvim/PL

    if s:plug_fnamemodify(home, ':t') ==# 'plugin' && s:plug_fnamemodify(home, ':h') ==# s:first_rtp
        return s:err('Invalid plug home. '.home.' is a standard Vim runtime path and is not allowed.')
    en

    let g:plug_home = home
    let g:plugs = {}
    let g:plugs_order = []
    let s:triggers = {}

    call s:define_commands()
    return 1
endf


fun! s:define_commands()
    com!  -nargs=+ -bar Plug call plug#(<args>)
    if !executable('git')
        return s:err('`git` executable not found. Most commands will not be available. To suppress this message, prepend `silent!` to `call plug#begin(...)`.')
    en
    if has('win32')
    \ && &shellslash
    \ && (&shell =~# 'cmd\(\.exe\)\?$' || s:is_powershell(&shell))
        return s:err('vim-plug does not support shell, ' . &shell . ', when shellslash is set.')
    en
    if !has('nvim')
        \ && (has('win32') || has('win32unix'))
        \ && !has('multi_byte')
        return s:err('Vim needs +multi_byte feature on Windows to run shell commands. Enable +iconv for best results.')
    en
    com!  -nargs=* -bar -bang -complete=customlist,s:names PlugInstall call s:install(<bang>0, [<f-args>])
    com!  -nargs=* -bar -bang -complete=customlist,s:names PlugUpdate  call s:update(<bang>0, [<f-args>])
    com!  -nargs=0 -bar -bang                              PlugClean call s:clean(<bang>0)
    com!  -nargs=0 -bar                                    PlugUpgrade if s:upgrade() | execute 'source' s:esc(s:me) | endif
    com!  -nargs=0 -bar                                    PlugStatus  call s:status()
    com!  -nargs=0 -bar                                    PlugDiff    call s:diff()
    com!  -nargs=? -bar -bang -complete=file               PlugSnapshot call s:snapshot(<bang>0, <f-args>)
endf

fun! s:to_a(v)
    return type(a:v) == s:TYPE.list ? a:v : [a:v]
endf

fun! s:to_s(v)
    return type(a:v) == s:TYPE.string ? a:v : join(a:v, "\n") . "\n"
endf

fun! s:glob(from, pattern)
    return s:lines(globpath(a:from, a:pattern))
endf

fun! s:source(from, ...)
    let found = 0
    for pattern in a:000
        for vim in s:glob(a:from, pattern)
            exe  'source' s:esc(vim)
            let found = 1
        endfor
    endfor
    return found
endf

fun! s:assoc(dict, key, val)
    let a:dict[a:key] = add(get(a:dict, a:key, []), a:val)
endf

fun! s:ask(message, ...)
    call inputsave()
    echohl WarningMsg
    let answer = input(a:message.(a:0 ? ' (y/N/a) ' : ' (y/N) '))
    echohl None
    call inputrestore()
    echo "\r"
    return (a:0 && answer =~? '^a') ? 2 : (answer =~? '^y') ? 1 : 0
endf

fun! s:ask_no_interrupt(...)
    try
        return call('s:ask', a:000)
    catch
        return 0
    endtry
endf

fun! s:lazy(plug, opt)
    return has_key(a:plug, a:opt) &&
                \ (empty(s:to_a(a:plug[a:opt]))         ||
                \  !isdirectory(a:plug.dir)             ||
                \  len(s:glob(s:rtp(a:plug), 'plugin')) ||
                \  len(s:glob(s:rtp(a:plug), 'after/plugin')))
endf

fun! plug#end()
    if !exists('g:plugs')
        return s:err('plug#end() called without calling plug#begin() first')
    en

    if exists('#PlugLOD')
        aug  PlugLOD
            au!
        aug  END
        augroup! PlugLOD
    en
    let lod = { 'ft': {}, 'map': {}, 'cmd': {} }

    if exists('g:did_load_filetypes')
        filetype off
    en
    for name in g:plugs_order
        if !has_key(g:plugs, name)
            continue
        en
        let plug = g:plugs[name]
        if get(s:loaded, name, 0) || !s:lazy(plug, 'on') && !s:lazy(plug, 'for')
            let s:loaded[name] = 1
            continue
        en

        if has_key(plug, 'on')
            let s:triggers[name] = { 'map': [], 'cmd': [] }
            for cmd in s:to_a(plug.on)
                if cmd =~? '^<Plug>.\+'
                    if empty(mapcheck(cmd)) && empty(mapcheck(cmd, 'i'))
                        call s:assoc(lod.map, cmd, name)
                    en
                    call add(s:triggers[name].map, cmd)
                elseif cmd =~# '^[A-Z]'
                    let cmd = substitute(cmd, '!*$', '', '')
                    if exists(':'.cmd) != 2
                        call s:assoc(lod.cmd, cmd, name)
                    en
                    call add(s:triggers[name].cmd, cmd)
                el
                    call s:err('Invalid `on` option: '.cmd.
                    \ '. Should start with an uppercase letter or `<Plug>`.')
                en
            endfor
        en

        if has_key(plug, 'for')
            let types = s:to_a(plug.for)
            if !empty(types)
                aug  filetypedetect
                call s:source(s:rtp(plug), 'ftdetect/**/*.vim', 'after/ftdetect/**/*.vim')
                aug  END
            en
            for type in types
                call s:assoc(lod.ft, type, name)
            endfor
        en
    endfor

    for [cmd, names] in items(lod.cmd)
        exe  printf(
        \ 'command! -nargs=* -range -bang -complete=file %s call s:lod_cmd(%s, "<bang>", <line1>, <line2>, <q-args>, %s)',
        \ cmd, string(cmd), string(names))
    endfor

    for [map, names] in items(lod.map)
        for [mode, map_prefix, key_prefix] in
                    \ [['i', '<C-\><C-O>', ''], ['n', '', ''], ['v', '', 'gv'], ['o', '', '']]
            exe  printf(
            \ '%snoremap <silent> %s %s:<C-U>call <SID>lod_map(%s, %s, %s, "%s")<CR>',
            \ mode, map, map_prefix, string(map), string(names), mode != 'i', key_prefix)
        endfor
    endfor

    for [ft, names] in items(lod.ft)
        aug  PlugLOD
            exe  printf('autocmd FileType %s call <SID>lod_ft(%s, %s)',
                        \ ft, string(ft), string(names))
        aug  END
    endfor

    call s:reorg_rtp()
    filetype plugin indent on
    if has('vim_starting')
        if has('syntax') && !exists('g:syntax_on')
            syn  enable
        end
    el
        call s:reload_plugins()
    en
endf

fun! s:loaded_names()
    return filter(copy(g:plugs_order), 'get(s:loaded, v:val, 0)')
endf

fun! s:load_plugin(spec)
    call s:source(s:rtp(a:spec), 'plugin/**/*.vim', 'after/plugin/**/*.vim')
endf

fun! s:reload_plugins()
    for name in s:loaded_names()
        call s:load_plugin(g:plugs[name])
    endfor
endf

fun! s:end_slash(str)
    return substitute(a:str, '[\/]\+$', '', '')
endf

fun! s:version_requirement(val, min)
    for idx in range(0,   len(a:min) - 1)
        let v = get(a:val, idx, 0)

        if v < a:min[idx] | return 0
        elseif v > a:min[idx] | return 1
        en
    endfor
    return 1
endf

fun! s:git_version_requirement(...)
    if !exists('s:git_version')
        let s:git_version = map(split(split(s:system(['git', '--version']))[2], '\.'), 'str2nr(v:val)')
    en
    return s:version_requirement(s:git_version, a:000)
endf

fun! s:progress_opt(base)
    return a:base && !s:is_win &&
                \ s:git_version_requirement(1, 7, 1) ? '--progress' : ''
endf

fun! s:rtp(spec)
    return s:path(a:spec.dir . get(a:spec, 'rtp', ''))
endf

if s:is_win
    fun! s:path(path)
        return s:end_slash(substitute(a:path, '/', '\', 'g'))
    endf

    fun! s:dirpath(path)
        return s:path(a:path) . '\'
    endf

    fun! s:is_local_plug(repo)
        return a:repo =~? '^[a-z]:\|^[%~]'
    endf

    " Copied from fzf
    fun! s:wrap_cmds(cmds)
        let cmds = [
            \ '@echo off',
            \ 'setl  enabledelayedexpansion']
        \ + (type(a:cmds) == type([]) ? a:cmds : [a:cmds])
        \ + ['endlocal']
        if has('iconv')
            if !exists('s:codepage')
                let s:codepage = libcallnr('kernel32.dll', 'GetACP', 0)
            en
            return map(cmds, printf('iconv(v:val."\r", "%s", "cp%d")', &encoding, s:codepage))
        en
        return map(cmds, 'v:val."\r"')
    endf

    fun! s:batchfile(cmd)
        let batchfile = s:plug_tempname().'.bat'
        call writefile(s:wrap_cmds(a:cmd), batchfile)
        let cmd = plug#shellescape(batchfile, {'shell': &shell, 'script': 0})
        if s:is_powershell(&shell)
            let cmd = '& ' . cmd
        en
        return [batchfile, cmd]
    endf
el
    fun! s:path(path)
        return s:end_slash(a:path)
    endf

    fun! s:dirpath(path)
        return substitute(a:path, '[/\\]*$', '/', '')
    endf

    fun! s:is_local_plug(repo)
        return a:repo[0] =~ '[/$~]'
    endf
en

fun! s:err(msg)
    echohl ErrorMsg
    echom '[vim-plug] '.a:msg
    echohl None
endf

fun! s:warn(cmd, msg)
    echohl WarningMsg
    exe  a:cmd 'a:msg'
    echohl None
endf

fun! s:esc(path)
    return escape(a:path, ' ')
endf

fun! s:escrtp(path)
    return escape(a:path, ' ,')
endf

fun! s:remove_rtp()
    for name in s:loaded_names()
        let rtp = s:rtp(g:plugs[name])
        exe  'set rtp-='.s:escrtp(rtp)
        let after = globpath(rtp, 'after')
        if isdirectory(after)
            exe  'set rtp-='.s:escrtp(after)
        en
    endfor
endf

fun! s:reorg_rtp()
    if !empty(s:first_rtp)
        exe  'set rtp-='.s:first_rtp
        exe  'set rtp-='.s:last_rtp
    en

    " &rtp is modified from outside
    if exists('s:prtp') && s:prtp !=# &rtp
        call s:remove_rtp()
        unlet! s:middle
    en

    let s:middle = get(s:, 'middle', &rtp)
    let rtps     = map(s:loaded_names(), 's:rtp(g:plugs[v:val])')
    let afters   = filter(map(copy(rtps), 'globpath(v:val, "after")'), '!empty(v:val)')
    let rtp      = join(map(rtps, 'escape(v:val, ",")'), ',')
                                 \ . ','.s:middle.','
                                 \ . join(map(afters, 'escape(v:val, ",")'), ',')
    let &rtp     = substitute(substitute(rtp, ',,*', ',', 'g'), '^,\|,$', '', 'g')
    let s:prtp   = &rtp

    if !empty(s:first_rtp)
        exe  'set rtp^='.s:first_rtp
        exe  'set rtp+='.s:last_rtp
    en
endf

fun! s:doautocmd(...)
    if exists('#'.join(a:000, '#'))
        exe  'doautocmd' ((v:version > 703 || has('patch442')) ? '<nomodeline>' : '') join(a:000)
    en
endf

fun! s:dobufread(names)
    for name in a:names
        let path = s:rtp(g:plugs[name])
        for dir in ['ftdetect', 'ftplugin', 'after/ftdetect', 'after/ftplugin']
            if len(finddir(dir, path))
                if exists('#BufRead')
                    doautocmd BufRead
                en
                return
            en
        endfor
    endfor
endf

fun! plug#load(...)
    if a:0 == 0
        return s:err('Argument missing: plugin name(s) required')
    en
    if !exists('g:plugs')
        return s:err('plug#begin was not called')
    en
    let names = a:0 == 1 && type(a:1) == s:TYPE.list ? a:1 : a:000
    let unknowns = filter(copy(names), '!has_key(g:plugs, v:val)')
    if !empty(unknowns)
        let s = len(unknowns) > 1 ? 's' : ''
        return s:err(printf('Unknown plugin%s: %s', s, join(unknowns, ', ')))
    end
    let unloaded = filter(copy(names), '!get(s:loaded, v:val, 0)')
    if !empty(unloaded)
        for name in unloaded
            call s:lod([name], ['ftdetect', 'after/ftdetect', 'plugin', 'after/plugin'])
        endfor
        call s:dobufread(unloaded)
        return 1
    end
    return 0
endf

fun! s:remove_triggers(name)
    if !has_key(s:triggers, a:name)
        return
    en
    for cmd in s:triggers[a:name].cmd
        exe  'silent! delc' cmd
    endfor
    for map in s:triggers[a:name].map
        exe  'silent! unmap' map
        exe  'silent! iunmap' map
    endfor
    call remove(s:triggers, a:name)
endf

fun! s:lod(names, types, ...)
    for name in a:names
        call s:remove_triggers(name)
        let s:loaded[name] = 1
    endfor
    call s:reorg_rtp()

    for name in a:names
        let rtp = s:rtp(g:plugs[name])
        for dir in a:types
            call s:source(rtp, dir.'/**/*.vim')
        endfor
        if a:0
            if !s:source(rtp, a:1) && !empty(s:glob(rtp, a:2))
                exe  'runtime' a:1
            en
            call s:source(rtp, a:2)
        en
        call s:doautocmd('User', name)
    endfor
endf

fun! s:lod_ft(pat, names)
    let syn = 'syntax/'.a:pat.'.vim'
    call s:lod(a:names, ['plugin', 'after/plugin'], syn, 'after/'.syn)
    exe  'autocmd! PlugLOD FileType' a:pat
    call s:doautocmd('filetypeplugin', 'FileType')
    call s:doautocmd('filetypeindent', 'FileType')
endf

fun! s:lod_cmd(cmd, bang, l1, l2, args, names)
    call s:lod(a:names, ['ftdetect', 'after/ftdetect', 'plugin', 'after/plugin'])
    call s:dobufread(a:names)
    exe  printf('%s%s%s %s', (a:l1 == a:l2 ? '' : (a:l1.','.a:l2)), a:cmd, a:bang, a:args)
endf

fun! s:lod_map(map, names, with_prefix, prefix)
    call s:lod(a:names, ['ftdetect', 'after/ftdetect', 'plugin', 'after/plugin'])
    call s:dobufread(a:names)
    let extra = ''
    while 1
        let c = getchar(0)
        if c == 0
            break
        en
        let extra .= nr2char(c)
    endwhile

    if a:with_prefix
        let prefix = v:count ? v:count : ''
        let prefix .= '"'.v:register.a:prefix
        if mode(1) == 'no'
            if v:operator == 'c'
                let prefix = "\<esc>" . prefix
            en
            let prefix .= v:operator
        en
        call feedkeys(prefix, 'n')
    en
    call feedkeys(substitute(a:map, '^<Plug>', "\<Plug>", '') . extra)
endf

fun! plug#(repo, ...)
    "\ echom      '进入函数    plug#(repo, ...) '
    if a:0 > 1
        return s:err('Invalid number of arguments (1..2)')
    en

    try
        let repo = s:end_slash(a:repo)
        let opts = a:0 == 1 ? s:parse_options(a:1) : s:base_spec
        let name = get(opts, 'as', s:plug_fnamemodify(repo, ':t:s?\.git$??'))
        let spec = extend(s:infer_properties(name, repo), opts)
        if !has_key(g:plugs, name)
            call add(g:plugs_order, name)
        en
        let g:plugs[name] = spec
        let s:loaded[name] = get(s:loaded, name, 0)
    catch
        return s:err(repo . ' ' . v:exception)
    endtry
endf

fun! s:parse_options(arg)
    let opts = copy(s:base_spec)
    let type = type(a:arg)
    let opt_errfmt = 'Invalid argument for "%s" option of :Plug (expected: %s)'
    if type == s:TYPE.string
        if empty(a:arg)
            throw printf(opt_errfmt, 'tag', 'string')
        en
        let opts.tag = a:arg
    elseif type == s:TYPE.dict
        for opt in ['branch', 'tag', 'commit', 'rtp', 'dir', 'as']
            if has_key(a:arg, opt)
            \ && (type(a:arg[opt]) != s:TYPE.string || empty(a:arg[opt]))
                throw printf(opt_errfmt, opt, 'string')
            en
        endfor
        for opt in ['on', 'for']
            if has_key(a:arg, opt)
            \ && type(a:arg[opt]) != s:TYPE.list
            \ && (type(a:arg[opt]) != s:TYPE.string || empty(a:arg[opt]))
                throw printf(opt_errfmt, opt, 'string or list')
            en
        endfor
        if has_key(a:arg, 'do')
            \ && type(a:arg.do) != s:TYPE.funcref
            \ && (type(a:arg.do) != s:TYPE.string || empty(a:arg.do))
                throw printf(opt_errfmt, 'do', 'string or funcref')
        en
        call extend(opts, a:arg)
        if has_key(opts, 'dir')
            let opts.dir = s:dirpath(s:plug_expand(opts.dir))
        en
    el
        throw 'Invalid argument type (expected: string or dictionary)'
    en
    return opts
endf

fun! s:infer_properties(name, repo)
    let repo = a:repo
    if s:is_local_plug(repo)
        return { 'dir': s:dirpath(s:plug_expand(repo)) }
    el
        if repo =~ ':'
            let uri = repo
        el
            if repo !~ '/'
                throw printf('Invalid argument: %s (implicit `vim-scripts'' expansion is deprecated)', repo)
            en
            let fmt = get(g:, 'plug_url_format', 'https://git::@github.com/%s.git')
            let uri = printf(fmt, repo)
        en
        return { 'dir': s:dirpath(g:plug_home.'/'.a:name), 'uri': uri }
    en
endf

fun! s:install(force, names)
    call s:update_impl(0, a:force, a:names)
endf

fun! s:update(force, names)
    call s:update_impl(1, a:force, a:names)
endf

fun! plug#helptags()
    if !exists('g:plugs')
        return s:err('plug#begin was not called')
    en
    for spec in values(g:plugs)
        let docd = join([s:rtp(spec), 'doc'], '/')
        if isdirectory(docd)
            silent! execute 'helptags' s:esc(docd)
        en
    endfor
    return 1
endf

fun! s:syntax()
    syn  clear
    syn  region plug1 start=/\%1l/ end=/\%2l/ contains=plugNumber
    syn  region plug2 start=/\%2l/ end=/\%3l/ contains=plugBracket,plugX

    syn match plugNumber /[0-9]\+[0-9.]*/ contained
    syn match plugBracket /[[\]]/ contained
    syn match plugX /x/ contained
    syn match plugDash /^-\{1}\ /
    syn match plugPlus /^+/
    syn match plugStar /^*/
    syn match plugMessage /\(^- \)\@<=.*/
    syn match plugName /\(^- \)\@<=[^ ]*:/
    syn match plugSha /\%(: \)\@<=[0-9a-f]\{4,}$/
    syn match plugTag /(tag: [^)]\+)/
    syn match plugInstall /\(^+ \)\@<=[^:]*/
    syn match plugUpdate /\(^* \)\@<=[^:]*/
    syn match plugCommit /^  \X*[0-9a-f]\{7,9} .*/ contains=plugRelDate,plugEdge,plugTag
    syn match plugEdge /^  \X\+$/
    syn match plugEdge /^  \X*/ contained nextgroup=plugSha
    syn match plugSha /[0-9a-f]\{7,9}/ contained
    syn match plugRelDate /([^)]*)$/ contained
    syn match plugNotLoaded /(not loaded)$/
    syn match plugError /^x.*/
    syn region plugDeleted start=/^\~ .*/ end=/^\ze\S/
    syn match plugH2 /^.*:\n-\+$/
    syn match plugH2 /^-\{2,}/
    syn keyword Function PlugInstall PlugStatus PlugUpdate PlugClean

    "\ link
        hi def link plug1       Title
        hi def link plug2       Repeat
        hi def link plugH2      Type
        hi def link plugX       Exception
        hi def link plugBracket Structure
        hi def link plugNumber  Number

        hi def link plugDash    Special
        hi def link plugPlus    Constant
        hi def link plugStar    Boolean

        hi def link plugMessage Function
        hi def link plugName    Label
        hi def link plugInstall Function
        hi def link plugUpdate  Type

        hi def link plugError   Error
        hi def link plugDeleted Ignore
        hi def link plugRelDate Comment
        hi def link plugEdge    PreProc
        hi def link plugSha     Identifier
        hi def link plugTag     Constant

        hi def link plugNotLoaded Comment
endf

fun! s:lpad(str, len)
    return a:str . repeat(' ', a:len - len(a:str))
endf

fun! s:lines(msg)
    return split(a:msg, "[\r\n]")
endf

fun! s:lastline(msg)
    return get(s:lines(a:msg), -1, '')
endf

fun! s:new_window()
    exe  get(g:, 'plug_window', 'vertical topleft new')
endf

fun! s:plug_window_exists()
    let buflist = tabpagebuflist(s:plug_tab)
    return !empty(buflist) && index(buflist, s:plug_buf) >= 0
endf

fun! s:switch_in()
    if !s:plug_window_exists()  | return 0  | en

    if winbufnr(0) != s:plug_buf
        let s:pos = [tabpagenr(), winnr(), winsaveview()]
        exe  'normal!'    s:plug_tab . 'gt'
        let winnr = bufwinnr(s:plug_buf)
        exe  winnr . 'wincmd w'
        call add(s:pos, winsaveview())
    el
        let s:pos = [winsaveview()]
    en

    setl  modifiable
    return 1
endf

fun! s:switch_out(...)
    call winrestview(s:pos[-1])
    setl  nomodifiable
    if a:0 > 0
        exe  a:1
    en

    if len(s:pos) > 1
        exe  'normal!' s:pos[0].'gt'
        exe  s:pos[1] 'wincmd w'
        call winrestview(s:pos[2])
    en
endf

fun! s:finish_bindings()
    nno  <silent> <buffer> R  :call <SID>retry()<cr>
    nno  <silent> <buffer> D  :PlugDiff<cr>
    nno  <silent> <buffer> S  :PlugStatus<cr>
    nno  <silent> <buffer> U  :call <SID>status_update()<cr>
    xno  <silent> <buffer> U  :call <SID>status_update()<cr>
    nno  <silent> <buffer> ]] :silent! call <SID>section('')<cr>
    nno  <silent> <buffer> [[ :silent! call <SID>section('b')<cr>
endf

fun! s:prepare(...)
    if empty(s:plug_getcwd())
        throw 'Invalid current working directory. Cannot proceed.'
    en

    for evar in ['$GIT_DIR', '$GIT_WORK_TREE']
        if exists(evar)  | throw evar.' detected. Cannot proceed.'  | en
    endfor

    call s:job_abort()

    if s:switch_in()
        if b:plug_preview == 1
            pc
        en
        enew
    el
        call s:new_window()
    en

    nno  <silent> <buffer>   q :call <SID>close_pane()<cr>

    if a:0 == 0  | call s:finish_bindings()  | en

    let b:plug_preview = -1
    let s:plug_tab = tabpagenr()
    let s:plug_buf = winbufnr(0)
    call s:assign_name()

    for k in ['<cr>', 'L', 'o', 'X', 'd', 'dd']
        exe  'silent! unmap <buffer>' k
    endfor
    setl  buftype=nofile
        \ bufhidden=wipe
        \ nobuflisted
        \ nolist
        \ noswapfile
        \ nowrap
        \ cursorline
        \ modifiable
        \ nospell

    if exists('+colorcolumn')  | setl  colorcolumn=  | en

    setfiletype vim-plug

    if exists('g:syntax_on')  | call s:syntax()  | en
endf

fun! s:close_pane()
    if b:plug_preview == 1
        pclose
        "\ Close any "Preview" window currently open.
        let b:plug_preview = -1
    el
        bdelete
    en
endf

fun! s:assign_name()
    " Assign buffer name
    let prefix = '插件'
    let name   = prefix
    let idx    = 2
    while bufexists(name)
        let name = printf('%s (%s)', prefix, idx)
        let idx = idx + 1
    endwhile
    silent! exe 'file' fnameescape(name)
endf

fun! s:chsh(swap)
    let prev = [&shell, &shellcmdflag, &shellredir]
    if !s:is_win  | set shell=sh  | en
    if a:swap
        if s:is_powershell(&shell)
            let &shellredir = '2>&1 | Out-File -Encoding UTF8 %s'
        elseif &shell =~# 'sh' || &shell =~# 'cmd\(\.exe\)\?$'
            set shellredir=>%s\ 2>&1
        en
    en
    return prev
endf

fun! s:bang(cmd, ...)
    let batchfile = ''
    try
        let [sh, shellcmdflag, shrd] = s:chsh(a:0)
        " FIXME: Escaping is incomplete. We could use shellescape with eval,
        "        but it won't work on Windows.
        let cmd = a:0 ? s:with_cd(a:cmd, a:1) : a:cmd
        if s:is_win
            let [batchfile, cmd] = s:batchfile(cmd)
        en
        let g:_plug_bang = (s:is_win && has('gui_running') ? 'silent ' : '').'!'.escape(cmd, '#!%')
        exe  "normal! :execute g:_plug_bang\<cr>\<cr>"
    finally
        unlet g:_plug_bang
        let [&shell, &shellcmdflag, &shellredir] = [sh, shellcmdflag, shrd]
        if s:is_win && filereadable(batchfile)
            call delete(batchfile)
        en
    endtry
    return v:shell_error ? 'Exit status: ' . v:shell_error : ''
endf

fun! s:regress_bar()
    let bar = substitute(getline(2)[1:-2], '.*\zs=', 'x', '')
    call s:progress_bar(2, bar, len(bar))
endf

fun! s:is_updated(dir)
    return !empty(s:system_chomp(
                        \ [
                         \ 'git'                ,
                         \ 'log'                ,
                         \ '--pretty=format:%h' ,
                         \ 'HEAD...HEAD@{1}'    ,
                        \ ],
                        \ a:dir,
                       \ )
          \ )
endf

fun! s:do(pull, force, todo)
    for [name, spec] in items(a:todo)
        if !isdirectory(spec.dir)  | continue  | en
        let installed = has_key(s:update.new, name)
        let updated = installed
                    \ ? 0
                    \ : (    a:pull
                        \ && index(s:update.errors, name) < 0
                        \ && s:is_updated(spec.dir)
                      \ )

        if a:force || installed || updated
            exe  'cd'  s:esc(spec.dir)
            call append(3,  '- Post-update hook for ' . name  . ' ... ')
            let error = ''
            let type = type(spec.do)
            if type == s:TYPE.string
                if spec.do[0] == ':'
                    if !get(s:loaded, name, 0)
                        let s:loaded[name] = 1
                        call s:reorg_rtp()
                    en

                    call s:load_plugin(spec)

                    try
                        exe  spec.do[1:]
                    catch
                        let error = v:exception
                    endtry

                    if !s:plug_window_exists()
                        cd -
                        throw '!vim-plug was terminated by the post-update hook of ' . name
                    en
                el
                    let error = s:bang(spec.do)
                en
            elseif type == s:TYPE.funcref
                try
                    call s:load_plugin(spec)
                    let status = installed ? 'installed' : (updated ? 'updated' : 'unchanged')
                    call spec.do({ 'name': name, 'status': status, 'force': a:force })
                catch
                    let error = v:exception
                endtry
            el
                let error = 'Invalid hook type'
            en
            call s:switch_in()
            call setline(4, empty(error) ? (getline(4) . 'OK')
                                                                 \ : ('x' . getline(4)[1:] . error))
            if !empty(error)
                call add(s:update.errors, name)
                call s:regress_bar()
            en
            cd -
        en
    endfor
endf

fun! s:hash_match(a, b)
    return stridx(a:a, a:b) == 0 || stridx(a:b, a:a) == 0
endf

fun! s:checkout(spec)
    let sha = a:spec.commit
    let output = s:git_revision(a:spec.dir)
    if !empty(output) && !s:hash_match(sha, s:lines(output)[0])
        let credential_helper = s:git_version_requirement(2) ? '-c credential.helper= ' : ''
        let output = s:system(
                    \ 'git '.credential_helper.'fetch --depth 999999 && git checkout '.plug#shellescape(sha).' --', a:spec.dir)
    en
    return output
endf

fun! s:finish(pull)
    let new_frozen = len(filter(keys(s:update.new), 'g:plugs[v:val].frozen'))
    if new_frozen
        let s = new_frozen > 1 ? 's' : ''
        call append(3, printf('- Installed %d frozen plugin%s', new_frozen, s))
    en
    call append(3, '- Finishing ... ') | 4
    redraw
    call plug#helptags()
    call plug#end()
    call setline(4, getline(4) . 'Done!')
    redraw
    let msgs = []
    if !empty(s:update.errors)
        call add(msgs, "Press 'R' to retry.")
    en
    if a:pull
  \ && len(s:update.new) < len(filter(getline(5, '$'),
                                  \ "v:val =~ '^- ' && v:val !~# 'up.to.date'") )

        call add(msgs, "Press 'D' to see the updated changes.")
    en
    echo join(msgs, ' ')
    call s:finish_bindings()
endf

fun! s:retry()
    if empty(s:update.errors)
        return
    en
    echo
    call s:update_impl(s:update.pull, s:update.force,
                \ extend(copy(s:update.errors), [s:update.threads]))
endf

fun! s:is_managed(name)
    return has_key(g:plugs[a:name], 'uri')
endf

fun! s:names(...)
    return sort(filter(keys(g:plugs), 'stridx(v:val, a:1) == 0 && s:is_managed(v:val)'))
endf


fun! s:update_impl(pull, force, args) abort
    let sync = index(a:args, '--sync') >= 0
       \ || has('vim_starting')

    let args = filter(copy(a:args),  'v:val != "--sync"')
    let threads = (   len(args) > 0
             \ && args[-1] =~ '^[1-9][0-9]*$')
                        \ ? remove(args, -1)
                        \ : get(g:, 'plug_threads', 16
              \)

    let managed = filter(copy(g:plugs), 's:is_managed(v:key)' )
    let todo = empty(args)
            \ ? filter(managed, '!v:val.frozen || !isdirectory(v:val.dir)')
            \ : filter(managed, 'index(args, v:key) >= 0' )

    if empty(todo)  | return s:warn('echo', 'No plugin to ' . (a:pull ? 'update' : 'install'))  | en

    if !s:is_win && s:git_version_requirement(2, 3)
        let s:git_terminal_prompt = exists('$GIT_TERMINAL_PROMPT')
                                       \? $GIT_TERMINAL_PROMPT
                                      \ : ''
        let $GIT_TERMINAL_PROMPT = 0
        for plug in values(todo)
            let plug.uri = substitute(
                                 \ plug.uri,
                                 \ '^https://git::@github\.com',
                                 \ 'https://github.com',
                                 \ '',
                                \ )
        endfor
    en

    if !isdirectory(g:plug_home)
        try
            call mkdir(g:plug_home, 'p')
        catch
            return s:err(printf('Invalid plug directory: %s. ' .
                       \ 'Try to call plug#begin with a valid directory', g:plug_home))
        endtry
    en

    let use_job = s:nvim || s:vim8
    echom "use_job 是: "   use_job

    let s:update = {
        \ 'start':   reltime(),
        \ 'all':     todo,
        \ 'todo':    copy(todo),
        \ 'errors':  [],
        \ 'pull':    a:pull,
        \ 'force':   a:force,
        \ 'new':     {},
        \ 'threads': min([len(todo), threads]),
        \ 'bar':     '',
        \ 'fin':     0
    \ }

    call s:prepare(1)
    call append(0, ['', ''])
    norm! 2G
    silent! redraw

    " Set remote name,
    " overriding a possible user git config's clone.defaultRemoteName
    let s:clone_opt = ['--origin', 'origin']
    if get(g:, 'plug_shallow', 1)
        call extend(s:clone_opt, ['--depth', '1'])
        if s:git_version_requirement(1, 7, 10)  | call add(s:clone_opt, '--no-single-branch')  | en
    en

    if has('win32unix') || has('wsl')
        call extend(
             \ s:clone_opt,
             \ ['-c', 'core.eol=lf', '-c', 'core.autocrlf=input'],
            \ )
    en

    let s:submodule_opt = s:git_version_requirement(2, 8)
                    \ ? ' --jobs=' . threads
                    \ : ''

    call s:update_vim()
    while use_job && sync
        sleep 100m
        if s:update.OK  | break  | en
    endwhile
endf

fun! s:log4(name, msg)
    call setline(4, printf('- %s (%s)', a:msg, a:name))
    redraw
endf

fun! s:update_finish()
    if exists('s:git_terminal_prompt')
        let $GIT_TERMINAL_PROMPT = s:git_terminal_prompt
    en
    if s:switch_in()
        call append(3, '- Updating ...') | 4
        for [name, spec] in items(filter(copy(s:update.all), 'index(s:update.errors, v:key) < 0 && (s:update.force || s:update.pull || has_key(s:update.new, v:key))'))
            let [pos, _] = s:logpos(name)
            if !pos
                continue
            en
            if has_key(spec, 'commit')
                call s:log4(name, 'Checking out '.spec.commit)
                let out = s:checkout(spec)
            elseif has_key(spec, 'tag')
                let tag = spec.tag
                if tag =~ '\*'
                    let tags = s:lines(s:system('git tag --list '.plug#shellescape(tag).' --sort -version:refname 2>&1', spec.dir))
                    if !v:shell_error && !empty(tags)
                        let tag = tags[0]
                        call s:log4(name, printf('Latest tag for %s -> %s', spec.tag, tag))
                        call append(3, '')
                    en
                en
                call s:log4(name, 'Checking out '.tag)
                let out = s:system('git checkout -q '.plug#shellescape(tag).' -- 2>&1', spec.dir)
            el
                let branch = s:git_origin_branch(spec)
                call s:log4(name, 'Merging origin/'.s:esc(branch))
                let out = s:system('git checkout -q '.plug#shellescape(branch).' -- 2>&1'
                            \. (has_key(s:update.new, name) ? '' : ('&& git merge --ff-only '.plug#shellescape('origin/'.branch).' 2>&1')), spec.dir)
            en
            if !v:shell_error && filereadable(spec.dir.'/.gitmodules') &&
                        \ (s:update.force || has_key(s:update.new, name) || s:is_updated(spec.dir))
                call s:log4(name, 'Updating submodules. This may take a while.')
                let out .= s:bang('git submodule update --init --recursive'.s:submodule_opt.' 2>&1', spec.dir)
            en
            let msg = s:format_message(
                                \ v:shell_error ? 'x': '-'  ,
                                \ name                  ,
                                \ out                   ,
                               \ )
            if v:shell_error
                call add(s:update.errors, name)
                call s:regress_bar()
                silent exe  pos 'd _'
                call append(4, msg) | 4
            elseif !empty(out)
                call setline(pos, msg[0])
            en
            redraw
        endfor
        silent 4 d _
        try
            call s:do(s:update.pull, s:update.force, filter(copy(s:update.all), 'index(s:update.errors, v:key) < 0 && has_key(v:val, "do")'))
        catch
            call s:warn('echom', v:exception)
            call s:warn('echo', '')
            return
        endtry
        call s:finish(s:update.pull)
        let time_cost = split(reltimestr(reltime(s:update.start)))[0]
        if str2float(time_cost) > 2
            call setline(
                  \ 1,
                  \ 'Updated. cost: ' . time_cost . ' sec.',
                 \ )
        en
        call s:switch_out('normal! gg')
    en
endf

fun! s:job_abort()
    if (!s:nvim && !s:vim8) || !exists('s:jobs')
        return
    en

    for [name, j] in items(s:jobs)
        if s:nvim
            silent! call jobstop(j.jobid)
        elseif s:vim8
            silent! call job_stop(j.jobid)
        en
        if j.new
            call s:rm_rf(g:plugs[name].dir)
        en
    endfor
    let s:jobs = {}
endf

fun! s:last_non_empty_line(lines)
    let len = len(a:lines)
    for idx in range(len)
        let line = a:lines[len-idx-1]
        if !empty(line)
            return line
        en
    endfor
    return ''
endf

fun! s:job_out_cb(self, data) abort
    let self = a:self
    let data = remove(self.lines, -1) . a:data
    let lines = map(split(data, "\n", 1), 'split(v:val, "\r", 1)[-1]')
    call extend(self.lines, lines)
    " To reduce the number of buffer updates
    let self.tick = get(self, 'tick', -1) + 1
    if !self.running || self.tick % len(s:jobs) == 0
        let bullet = self.running ? (self.new ? '+' : '*') : (self.error ? 'x' : '-')
        let result = self.error ? join(self.lines, "\n") : s:last_non_empty_line(self.lines)
        call s:log(bullet, self.name, result)
    en
endf

fun! s:job_exit_cb(self, data) abort
    let a:self.running = 0
    let a:self.error = a:data != 0
    call s:again(a:self.name)
    call s:tick()
endf

fun! s:job_cb(fn, job, ch, data)
    " plug window closed
    if !s:plug_window_exists()   | return s:job_abort()  | en
    call call(a:fn, [a:job, a:data])
endf

fun! s:nvim_cb(job_id, data, event) dict abort

    return (a:event == 'stdout' || a:event == 'stderr')
        \ ?   s:job_cb('s:job_out_cb',  self, 0, join(a:data, "\n"))
        \ :   s:job_cb('s:job_exit_cb', self, 0, a:data)
endf

"\ _cb 是spawn的谐音?
fun! s:spawn(name, cmd, opts)
    let job = { 'name': a:name, 'running': 1, 'error': 0, 'lines': [''],
                        \ 'new': get(a:opts, 'new', 0) }
    let s:jobs[a:name] = job

    if s:nvim
        if has_key(a:opts, 'dir')
            let job.cwd = a:opts.dir
        en
        let argv = a:cmd
        call extend(job, {
        \ 'on_stdout' :  function('s:nvim_cb'),
        \ 'on_stderr' :  function('s:nvim_cb'),
        \ 'on_exit'   :  function('s:nvim_cb'),
        \ })

        let jid = s:plug_call('jobstart', argv, job)
        if jid > 0
            let job.jobid = jid
        el
            let job.running = 0
            let job.error   = 1
            let job.lines   = [jid < 0 ? argv[0].' is not executable' :
                        \ 'Invalid arguments (or job table is full)']
        en
    elseif s:vim8
        let cmd = join(map(copy(a:cmd), 'plug#shellescape(v:val, {"script": 0})'))
        if has_key(a:opts, 'dir')
            let cmd = s:with_cd(cmd, a:opts.dir, 0)
        en
        let argv = s:is_win ? ['cmd', '/s', '/c', '"'.cmd.'"'] : ['sh', '-c', cmd]
        let jid = job_start(s:is_win ? join(argv, ' ') : argv, {
        \ 'out_cb':   function('s:job_cb', ['s:job_out_cb',  job]),
        \ 'err_cb':   function('s:job_cb', ['s:job_out_cb',  job]),
        \ 'exit_cb':  function('s:job_cb', ['s:job_exit_cb', job]),
        \ 'err_mode': 'raw',
        \ 'out_mode': 'raw'
        \})
        if job_status(jid) == 'run'
            let job.jobid = jid
        el
            let job.running = 0
            let job.error   = 1
            let job.lines   = ['Failed to start job']
        en
    el
        let job.lines = s:lines(call('s:system', has_key(a:opts, 'dir') ? [a:cmd, a:opts.dir] : [a:cmd]))
        let job.error = v:shell_error != 0
        let job.running = 0
    en
endf

fun! s:again(name)
    let job = s:jobs[a:name]
    if job.error
        call add(s:update.errors, a:name)
    elseif get(job, 'new', 0)
        let s:update.new[a:name] = 1
    en
    let s:update.bar .= job.error
                      \ ? 'x'
                      \ : '='

    let bullet = job.error
                \ ? 'x'
                \ : '-'

    let result = job.error
                \ ? join(job.lines, "\n")
                \ : s:last_non_empty_line(job.lines)

    call s:log(
      \ bullet,
      \ a:name,
      \ empty(result)
        \ ? 'OK'
        \ : result,
 \     )
    call s:bar()

    call remove(s:jobs, a:name)
endf

fun! s:bar()
    if s:switch_in()
        let total = len(s:update.all)
        call setline(
              \ 1,
              \ (s:update.pull ? 'Updating' : 'Installing')  . ' plugins (' . len(s:update.bar) . '/' . total . ')',
             \ )
        call s:progress_bar(2, s:update.bar, total)
        call s:switch_out()
    en
endf

fun! s:logpos(name)
    let max = line('$')
    for i in range(4, max > 4 ? max : 4)
        if getline(i) =~# '^[-+x*] '.a:name.':'
            for j in range(i + 1, max > 5 ? max : 5)
                if getline(j) !~ '^ '
                    return [i, j - 1]
                en
            endfor
            return [i, i]
        en
    endfor
    return [0, 0]
endf

fun! s:log(bullet, name, lines)
    if s:switch_in()
        let [b, e] = s:logpos(a:name)
        if b > 0
            silent execute printf('%d,%d d _', b, e)
            if b > winheight('.')
                let b = 4
            en
        el
            let b = 4
        en
        " FIXME For some reason, nomodifiable is set after :d in vim8
        setl  modifiable
        call append(b - 1, s:format_message(a:bullet, a:name, a:lines))
        call s:switch_out()
    en
endf

fun! s:update_vim()
    let s:jobs = {}
    call s:bar()
    call s:tick()
endf

fun! s:tick()
    let pull = s:update.pull
    let prog = s:progress_opt(s:nvim || s:vim8)

    "\ total cost of ownership
    while 1 " Without TCO, Vim stack is bound to explode
        if empty(s:update.todo)
            if empty(s:jobs)
          \ && !s:update.OK
                call s:update_finish()
                let s:update.OK = 1
            en
            return
        en

        let name = keys(s:update.todo)[0]
        let spec = remove(s:update.todo, name)
        let new  = empty(globpath(spec.dir, '.git', 1))

        call s:log(new ? '+' : '*', name, pull ? 'Updating ...' : 'Installing ...')
        redraw

        let has_tag = has_key(spec, 'tag')
        if !new
            let [error, _] = s:git_validate(spec, 0)
            if empty(error)
                if pull
                    let cmd = s:git_version_requirement(2) ? ['git', '-c', 'credential.helper=', 'fetch'] : ['git', 'fetch']
                    if has_tag && !empty(globpath(spec.dir, '.git/shallow'))
                        call extend(cmd, ['--depth', '99999999'])
                    en
                    if !empty(prog)
                        call add(cmd, prog)
                    en
                    call s:spawn(name, cmd, { 'dir': spec.dir })
                el
                    let s:jobs[name] = { 'running': 0, 'lines': [ '' ], 'error': 0 }
                en
            el
                let s:jobs[name] = { 'running': 0, 'lines': s:lines(error), 'error': 1 }
            en
        el
            let cmd = ['git', 'clone']
            if !has_tag
                call extend(cmd, s:clone_opt)
            en
            if !empty(prog)
                call add(cmd, prog)
            en
            call s:spawn(name, extend(cmd, [spec.uri, s:end_slash(spec.dir)]), { 'new': 1 })
        en

        if !s:jobs[name].running          | call s:again(name)  | en
        if len(s:jobs) >= s:update.threads  | break        | en
    endwhile
endf


fun! s:shellesc_cmd(arg, script)
    let escaped = substitute('"'.a:arg.'"', '[&|<>()@^!"]', '^&', 'g')
    return substitute(escaped, '%', (a:script ? '%' : '^') . '&', 'g')
endf

fun! s:shellesc_ps1(arg)
    return "'".substitute(escape(a:arg, '\"'), "'", "''", 'g')."'"
endf

fun! s:shellesc_sh(arg)
    return "'".substitute(a:arg, "'", "'\\\\''", 'g')."'"
endf

" Escape the shell argument based on the shell.
" Vim and Neovim's shellescape() are insufficient.
" 1. shellslash determines whether to use single/double quotes.
"    Double-quote escaping is fragile for cmd.exe.
" 2. It does not work for powershell.
" 3. It does not work for *sh shells if the command is executed
"    via cmd.exe (ie. cmd.exe /c sh -c command command_args)
" 4. It does not support batchfile syntax.
"
" Accepts an optional dictionary with the following keys:
" - shell: same as Vim/Neovim 'shell' option.
"          If unset, fallback to 'cmd.exe' on Windows or 'sh'.
" - script: If truthy and shell is cmd.exe, escape for batchfile syntax.
fun! plug#shellescape(arg, ...)
    if a:arg =~# '^[A-Za-z0-9_/:.-]\+$'
        return a:arg
    en
    let opts = a:0 > 0 && type(a:1) == s:TYPE.dict ? a:1 : {}
    let shell = get(opts, 'shell', s:is_win ? 'cmd.exe' : 'sh')
    let script = get(opts, 'script', 1)
    if shell =~# 'cmd\(\.exe\)\?$'
        return s:shellesc_cmd(a:arg, script)
    elseif s:is_powershell(shell)
        return s:shellesc_ps1(a:arg)
    en
    return s:shellesc_sh(a:arg)
endf

fun! s:glob_dir(path)
    return map(filter(s:glob(a:path, '**'), 'isdirectory(v:val)'), 's:dirpath(v:val)')
endf

fun! s:progress_bar(line, bar, total)
    call setline(a:line, '[' . s:lpad(a:bar, a:total) . ']')
endf

fun! s:compare_git_uri(a, b)
    " See `git help clone'
    " https:// [user@] github.com[:port] / junegunn/vim-plug [.git]
    "          [git@]  github.com[:port] : junegunn/vim-plug [.git]
    " file://                            / junegunn/vim-plug        [/]
    "                                    / junegunn/vim-plug        [/]
    let pat = '^\%(\w\+://\)\='.'\%([^@/]*@\)\='.'\([^:/]*\%(:[0-9]*\)\=\)'.'[:/]'.'\(.\{-}\)'.'\%(\.git\)\=/\?$'
    let ma = matchlist(a:a, pat)
    let mb = matchlist(a:b, pat)
    return ma[1:2] ==# mb[1:2]
endf

fun! s:format_message(bullet, name, message)
    if a:bullet != 'x'
        return [printf('%s %s: %s', a:bullet, a:name, s:lastline(a:message))]
    el
        let lines = map(s:lines(a:message), '"    ".v:val')
        return extend([printf('x %s:', a:name)], lines)
    en
endf

fun! s:with_cd(cmd, dir, ...)
    let script = a:0 > 0 ? a:1 : 1
    return printf('cd%s %s && %s', s:is_win ? ' /d' : '', plug#shellescape(a:dir, {'script': script}), a:cmd)
endf

fun! s:system(cmd, ...)
    let batchfile = ''
    try
        let [sh, shellcmdflag, shrd] = s:chsh(1)
        if type(a:cmd) == s:TYPE.list
            " Neovim's system() supports list argument to bypass the shell
            " but it cannot set the working directory for the command.
            " Assume that the command does not rely on the shell.
            if has('nvim') && a:0 == 0
                return system(a:cmd)
            en
            let cmd = join(map(copy(a:cmd), 'plug#shellescape(v:val, {"shell": &shell, "script": 0})'))
            if s:is_powershell(&shell)
                let cmd = '& ' . cmd
            en
        el
            let cmd = a:cmd
        en
        if a:0 > 0
            let cmd = s:with_cd(cmd, a:1, type(a:cmd) != s:TYPE.list)
        en
        if s:is_win && type(a:cmd) != s:TYPE.list
            let [batchfile, cmd] = s:batchfile(cmd)
        en
        return system(cmd)
    finally
        let [&shell, &shellcmdflag, &shellredir] = [sh, shellcmdflag, shrd]
        if s:is_win && filereadable(batchfile)
            call delete(batchfile)
        en
    endtry
endf

fun! s:system_chomp(...)
    let ret = call('s:system', a:000)
    return v:shell_error ? '' : substitute(ret, '\n$', '', '')
endf

fun! s:git_validate(spec, check_branch)
    let err = ''
    if isdirectory(a:spec.dir)
        let result = [s:git_local_branch(a:spec.dir), s:git_origin_url(a:spec.dir)]
        let remote = result[-1]
        if empty(remote)
            let err = join([remote, 'PlugClean required.'], "\n")
        elseif !s:compare_git_uri(remote, a:spec.uri)
            let err = join(['Invalid URI: '.remote,
                                        \ 'Expected:    '.a:spec.uri,
                                        \ 'PlugClean required.'], "\n")
        elseif a:check_branch && has_key(a:spec, 'commit')
            let sha = s:git_revision(a:spec.dir)
            if empty(sha)
                let err = join(add(result, 'PlugClean required.'), "\n")
            elseif !s:hash_match(sha, a:spec.commit)
                let err = join([printf('Invalid HEAD (expected: %s, actual: %s)',
                                                            \ a:spec.commit[:6], sha[:6]),
                                            \ 'PlugUpdate required.'], "\n")
            en
        elseif a:check_branch
            let current_branch = result[0]
            " Check tag
            let origin_branch = s:git_origin_branch(a:spec)
            if has_key(a:spec, 'tag')
                let tag = s:system_chomp('git describe --exact-match --tags HEAD 2>&1', a:spec.dir)
                if a:spec.tag !=# tag && a:spec.tag !~ '\*'
                    let err = printf('Invalid tag: %s (expected: %s). Try PlugUpdate.',
                                \ (empty(tag) ? 'N/A' : tag), a:spec.tag)
                en
            " Check branch
            elseif origin_branch !=# current_branch
                let err = printf('Invalid branch: %s (expected: %s). Try PlugUpdate.',
                            \ current_branch, origin_branch)
            en
            if empty(err)
                let [ahead, behind] = split(s:lastline(s:system([
                \ 'git', 'rev-list', '--count', '--left-right',
                \ printf('HEAD...origin/%s', origin_branch)
                \ ], a:spec.dir)), '\t')
                if !v:shell_error && ahead
                    if behind
                        " Only mention PlugClean if diverged, otherwise it's likely to be
                        " pushable (and probably not that messed up).
                        let err = printf(
                                    \ "Diverged from origin/%s (%d commit(s) ahead and %d commit(s) behind!\n"
                                    \ .'Backup local changes and run PlugClean and PlugUpdate to reinstall it.', origin_branch, ahead, behind)
                    el
                        let err = printf("Ahead of origin/%s by %d commit(s).\n"
                                    \ .'Cannot update until local changes are pushed.',
                                    \ origin_branch, ahead)
                    en
                en
            en
        en
    el
        let err = 'Not found'
    en
    return [err, err =~# 'PlugClean']
endf

fun! s:rm_rf(dir)
    if isdirectory(a:dir)
        return s:system(s:is_win
        \ ? 'rmdir /S /Q '.plug#shellescape(a:dir)
        \ : ['rm', '-rf', a:dir])
    en
endf

fun! s:clean(force)
    call s:prepare()
    call append(0, 'Searching for invalid plugins in '.g:plug_home)
    call append(1, '')

    " List of valid directories
    let dirs = []
    let errs = {}
    let [cnt, total] = [0, len(g:plugs)]
    for [name, spec] in items(g:plugs)
        if !s:is_managed(name)
            call add(dirs, spec.dir)
        el
            let [err, clean] = s:git_validate(spec, 1)
            if clean
                let errs[spec.dir] = s:lines(err)[0]
            el
                call add(dirs, spec.dir)
            en
        en
        let cnt += 1
        call s:progress_bar(2, repeat('=', cnt), total)
        norm! 2G
        redraw
    endfor

    let allowed = {}
    for dir in dirs
        let allowed[s:dirpath(s:plug_fnamemodify(dir, ':h:h'))] = 1
        let allowed[dir] = 1
        for child in s:glob_dir(dir)
            let allowed[child] = 1
        endfor
    endfor

    let todo = []
    let found = sort(s:glob_dir(g:plug_home))
    while !empty(found)
        let f = remove(found, 0)
        if !has_key(allowed, f) && isdirectory(f)
            call add(todo, f)
            call append(line('$'), '- ' . f)
            if has_key(errs, f)
                call append(line('$'), '    ' . errs[f])
            en
            let found = filter(found, 'stridx(v:val, f) != 0')
        end
    endwhile

    4
    redraw
    if empty(todo)
        call append(line('$'), 'Cleaned')
    el
        let s:clean_count = 0
        call append(3, ['Directories to delete:', ''])
        redraw!
        if a:force || s:ask_no_interrupt('Delete all directories?')
            call s:delete([6, line('$')], 1)
        el
            call setline(4, 'Cancelled.')
            nno  <silent> <buffer> d :set opfunc=<sid>delete_op<cr>g@
            nmap     <silent> <buffer> dd d_
            xno  <silent> <buffer> d :<c-u>call <sid>delete_op(visualmode(), 1)<cr>
            echo 'Delete the lines (d{motion}) to delete the corresponding directories'
        en
    en
    4
    setl  nomodifiable
endf

fun! s:delete_op(type, ...)
    call s:delete(a:0 ? [line("'<"), line("'>")] : [line("'["), line("']")], 0)
endf

fun! s:delete(range, force)
    let [l1, l2] = a:range
    let force = a:force
    let err_count = 0
    while l1 <= l2
        let line = getline(l1)
        if line =~ '^- ' && isdirectory(line[2:])
            exe  l1
            redraw!
            let answer = force ? 1 : s:ask('Delete '.line[2:].'?', 1)
            let force = force || answer > 1
            if answer
                let err = s:rm_rf(line[2:])
                setl  modifiable
                if empty(err)
                    call setline(l1, '~'.line[1:])
                    let s:clean_count += 1
                el
                    delete _
                    call append(l1 - 1, s:format_message('x', line[1:], err))
                    let l2 += len(s:lines(err))
                    let err_count += 1
                en
                let msg = printf('Removed %d directories.', s:clean_count)
                if err_count > 0
                    let msg .= printf(' Failed to remove %d directories.', err_count)
                en
                call setline(4, msg)
                setl  nomodifiable
            en
        en
        let l1 += 1
    endwhile
endf

fun! s:upgrade()
    echo 'Downloading the latest version of vim-plug'
    redraw
    let tmp = s:plug_tempname()
    let new = tmp . '/plug.vim'

    try
        let out = s:system(['git', 'clone', '--depth', '1', s:plug_src, tmp])
        if v:shell_error
            return s:err('Error upgrading vim-plug: '. out)
        en

        if readfile(s:me) ==# readfile(new)
            echo '插件管理器 本就是最新'
            return 0
        el
            call rename(s:me, s:me . '.old')
            call rename(new, s:me)
            unlet g:loaded_plug
            echo '插件管理器upgrade了'
            return 1
        en
    finally
        silent! call s:rm_rf(tmp)
    endtry
endf

fun! s:upgrade_specs()
    for spec in values(g:plugs)
        let spec.frozen = get(spec, 'frozen', 0)
    endfor
endf

fun! s:status()
    call s:prepare()
    call append(0, 'Checking plugins')
    call append(1, '')

    let ecnt = 0
    let unloaded = 0
    let [cnt, total] = [0, len(g:plugs)]
    for [name, spec] in items(g:plugs)
        let is_dir = isdirectory(spec.dir)
        if has_key(spec, 'uri')
            if is_dir
                let [err, _] = s:git_validate(spec, 1)
                let [valid, msg] = [empty(err), empty(err) ? 'OK' : err]
            el
                let [valid, msg] = [0, 'Not found. Try PlugInstall.']
            en
        el
            if is_dir
                let [valid, msg] = [1, 'OK']
            el
                let [valid, msg] = [0, 'Not found.']
            en
        en
        let cnt += 1
        let ecnt += !valid
        " `s:loaded` entry can be missing if PlugUpgraded
        if is_dir && get(s:loaded, name, -1) == 0
            let unloaded = 1
            let msg .= ' (not loaded)'
        en
        call s:progress_bar(2, repeat('=', cnt), total)
        call append(3, s:format_message(valid ? '-' : 'x', name, msg))
        norm! 2G
        redraw
    endfor
    call setline(1, 'Finished. '.ecnt.' error(s).')
    norm! gg
    setl  nomodifiable
    if unloaded
        echo "Press 'L' on each line to load plugin, or 'U' to update"
        nno  <silent> <buffer> L :call <SID>status_load(line('.'))<cr>
        xno  <silent> <buffer> L :call <SID>status_load(line('.'))<cr>
    end
endf

fun! s:extract_name(str, prefix, suffix)
    return matchstr(a:str, '^'.a:prefix.' \zs[^:]\+\ze:.*'.a:suffix.'$')
endf

fun! s:status_load(lnum)
    let line = getline(a:lnum)
    let name = s:extract_name(line, '-', '(not loaded)')
    if !empty(name)
        call plug#load(name)
        setl  modifiable
        call setline(a:lnum, substitute(line, ' (not loaded)$', '', ''))
        setl  nomodifiable
    en
endf

fun! s:status_update() range
    let lines = getline(a:firstline, a:lastline)
    let names = filter(map(lines, 's:extract_name(v:val, "[x-]", "")'), '!empty(v:val)')
    if !empty(names)
        echo
        exe  'PlugUpdate' join(names)
    en
endf

fun! s:is_preview_window_open()
    silent! wincmd P
    if &previewwindow
        wincmd p
        return 1
    en
endf

fun! s:find_name(lnum)
    for lnum in reverse(range(1, a:lnum))
        let line = getline(lnum)
        if empty(line)
            return ''
        en
        let name = s:extract_name(line, '-', '')
        if !empty(name)
            return name
        en
    endfor
    return ''
endf

fun! s:preview_commit()
    if b:plug_preview < 0
        let b:plug_preview = !s:is_preview_window_open()
    en

    let sha = matchstr(getline('.'), '^  \X*\zs[0-9a-f]\{7,9}')
    if empty(sha)
        return
    en

    let name = s:find_name(line('.'))
    if empty(name) || !has_key(g:plugs, name) || !isdirectory(g:plugs[name].dir)
        return
    en

    if exists('g:plug_pwindow') && !s:is_preview_window_open()
        exe  g:plug_pwindow
        exe  'e' sha
    el
        exe  'pedit' sha
        wincmd P
    en
    setl  previewwindow filetype=git buftype=nofile nobuflisted modifiable
    let batchfile = ''
    try
        let [sh, shellcmdflag, shrd] = s:chsh(1)
        let cmd = 'cd '.plug#shellescape(g:plugs[name].dir).' && git show --no-color --pretty=medium '.sha
        if s:is_win
            let [batchfile, cmd] = s:batchfile(cmd)
        en
        exe  'silent %!' cmd
    finally
        let [&shell, &shellcmdflag, &shellredir] = [sh, shellcmdflag, shrd]
        if s:is_win && filereadable(batchfile)
            call delete(batchfile)
        en
    endtry
    setl  nomodifiable
    nno  <silent> <buffer> q :q<cr>
    wincmd p
endf

fun! s:section(flags)
    call search('\(^[x-] \)\@<=[^:]\+:', a:flags)
endf

fun! s:format_git_log(line)
    let indent = '  '
    let tokens = split(a:line, nr2char(1))
    if len(tokens) != 5
        return indent.substitute(a:line, '\s*$', '', '')
    en
    let [graph, sha, refs, subject, date] = tokens
    let tag = matchstr(refs, 'tag: [^,)]\+')
    let tag = empty(tag) ? ' ' : ' ('.tag.') '
    return printf('%s%s%s%s%s (%s)', indent, graph, sha, tag, subject, date)
endf

fun! s:append_ul(lnum, text)
    call append(a:lnum, ['', a:text, repeat('-', len(a:text))])
endf

fun! s:diff()
    call s:prepare()
    call append(0, ['Collecting changes ...', ''])
    let cnts = [0, 0]
    let bar = ''
    let total = filter(copy(g:plugs), 's:is_managed(v:key) && isdirectory(v:val.dir)')
    call s:progress_bar(2, bar, len(total))
    for origin in [1, 0]
        let plugs = reverse(sort(items(filter(copy(total), (origin ? '' : '!').'(has_key(v:val, "commit") || has_key(v:val, "tag"))'))))
        if empty(plugs)
            continue
        en
        call s:append_ul(2, origin ? 'Pending updates:' : 'Last update:')
        for [k, v] in plugs
            let branch = s:git_origin_branch(v)
            if len(branch)
                let range = origin ? '..origin/'.branch : 'HEAD@{1}..'
                let cmd = ['git', 'log', '--graph', '--color=never']
                if s:git_version_requirement(2, 10, 0)
                    call add(cmd, '--no-show-signature')
                en
                call extend(cmd, ['--pretty=format:%x01%h%x01%d%x01%s%x01%cr', range])
                if has_key(v, 'rtp')
                    call extend(cmd, ['--', v.rtp])
                en
                let diff = s:system_chomp(cmd, v.dir)
                if !empty(diff)
                    let ref = has_key(v, 'tag') ? (' (tag: '.v.tag.')') : has_key(v, 'commit') ? (' '.v.commit) : ''
                    call append(5, extend(['', '- '.k.':'.ref], map(s:lines(diff), 's:format_git_log(v:val)')))
                    let cnts[origin] += 1
                en
            en
            let bar .= '='
            call s:progress_bar(2, bar, len(total))
            norm! 2G
            redraw
        endfor
        if !cnts[origin]
            call append(5, ['', 'N/A'])
        en
    endfor
    call setline(1, printf('%d plugin(s) updated.', cnts[0])
                \ . (cnts[1] ? printf(' %d plugin(s) have pending updates.', cnts[1]) : ''))

    if cnts[0] || cnts[1]
        nno  <silent> <buffer> <plug>(plug-preview) :silent! call <SID>preview_commit()<cr>
        if empty(maparg("\<cr>", 'n'))
            nmap <buffer> <cr> <plug>(plug-preview)
        en
        if empty(maparg('o', 'n'))
            nmap <buffer> o <plug>(plug-preview)
        en
    en
    if cnts[0]
        nno  <silent> <buffer> X :call <SID>revert()<cr>
        echo "Press 'X' on each block to revert the update"
    en
    norm! gg
    setl  nomodifiable
endf

fun! s:revert()
    if search('^Pending updates', 'bnW')
        return
    en

    let name = s:find_name(line('.'))
    if empty(name) || !has_key(g:plugs, name) ||
        \ input(printf('Revert the update of %s? (y/N) ', name)) !~? '^y'
        return
    en

    call s:system('git reset --hard HEAD@{1} && git checkout '.plug#shellescape(g:plugs[name].branch).' --', g:plugs[name].dir)
    setl  modifiable
    norm! "_dap
    setl  nomodifiable
    echo 'Reverted'
endf

fun! s:snapshot(force, ...) abort
    call s:prepare()
    setf vim
    call append(0, ['" Generated by vim-plug',
                                \ '" '.strftime("%c"),
                                \ '" :source this file in vim to restore the snapshot',
                                \ '" or execute: vim -S snapshot.vim',
                                \ '', '', 'PlugUpdate!'])
    1
    let anchor = line('$') - 3
    let names = sort(keys(filter(copy(g:plugs),
                \'has_key(v:val, "uri") && isdirectory(v:val.dir)')))
    for name in reverse(names)
        let sha = has_key(g:plugs[name], 'commit') ? g:plugs[name].commit : s:git_revision(g:plugs[name].dir)
        if !empty(sha)
            call append(anchor, printf("silent! let g:plugs['%s'].commit = '%s'", name, sha))
            redraw
        en
    endfor

    if a:0 > 0
        let fn = s:plug_expand(a:1)
        if filereadable(fn) && !(a:force || s:ask(a:1 . '存在,要覆盖?'))
            return
        en
        call writefile(getline(1, '$'), fn)
        echo 'Saved as '.a:1
        silent execute 'e' s:esc(fn)
        setf vim
    en
endf

fun! s:split_rtp()
    return split(&rtp, '\\\@<!,')
endf

let s:first_rtp = s:escrtp(get(s:split_rtp(), 0, ''))
let s:last_rtp  = s:escrtp(get(s:split_rtp(), -1, ''))

if exists('g:plugs')
    let g:plugs_order = get(g:, 'plugs_order', keys(g:plugs))
    call s:upgrade_specs()
    call s:define_commands()
en

let &cpo = s:cpo_save  | unlet s:cpo_save

"\ echom '结束/home/wf/.local/share/nvim/plugged/plug-vim/plug.vim'
