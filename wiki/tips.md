## Tips

### Automatic installation

_Place the following code in your .vimrc before `plug#begin()` call_

```vim
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
```

`--sync`  installer finishes 后才source 

#### HTTP proxy issues :warning: 

If you're behind an HTTP proxy and your proxy does not have TLS/SSL certificates required for Github or if Github has expired TLS/SSL certificates, you may need to add `--insecure` option to the curl command. In that case, you also need to set `$GIT_SSL_NO_VERIFY` to true.

Resort to this only if git cannot get updated certificates or if Github has TLS/SSL issues.

#### Automatic installation of missing plugins

You can even go a step further and make `:PlugInstall` run on startup if there are any missing plugins.

_Place the following code in your .vimrc before `plug#begin()` call_

```vim
" Install vim-plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif
```

Note that this may increase the startup time of Vim.

### Install plugins on the command line

```sh
# vim
vim -es -u vimrc -i NONE -c "PlugInstall" -c "qa"

# neovim
nvim -es -u init.vim -i NONE -c "PlugInstall" -c "qa"
```

`-u` is used here to force (n)vim to read only the given vimrc. See `:h startup`.
`-i` is used here to skip `viminfo` (vim) or `shada` (nvim). Reduce the `runtimepath` via `--cmd` to speed up vim-plug. Add `-V` to debug vim-plug if there are errors.

### Migrating from other plugin managers

Download plug.vim in `autoload` directory

```sh
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```

and update your .vimrc as needed.

<table>
<tr>
<th>
With Vundle.vim
</th>
<th>
Equivalent vim-plug configuration
</th>
</tr>
<tr>
<td>
<pre>
filetype off
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'VundleVim/Vundle.vim'
Plugin 'junegunn/seoul256.vim'
Plugin 'junegunn/goyo.vim'
Plugin 'junegunn/limelight.vim'
call vundle#end()
filetype plugin indent on
syntax enable
</pre>
</td>
<td>
<pre>
call plug#begin('~/.vim/plugged')
Plug 'junegunn/seoul256.vim'
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'
call plug#end()
</pre>
</td>
</tr>
</table>

vim-plug does not require any extra statement other than `plug#begin()` and `plug#end()`.
You can remove `filetype off`, `filetype plugin indent on` and `syntax on` from your
`.vimrc` as they are automatically handled by `plug#begin()` and `plug#end()`.

Since all the other major plugin managers store plugins in "bundle" directory,
you might want to pass it to `plug#begin()` if you do not wish to reinstall plugins.

```vim
" For Mac/Linux users
call plug#begin('~/.vim/bundle')

" For Windows users
call plug#begin('~/vimfiles/bundle')
```

Unlike Vundle, vim-plug does not implicitly prepend `vim-scripts/` to single-segment argument. So `Plugin 'taglist.vim'` in Vundle should be explicitly written as `Plug 'vim-scripts/taglist.vim'`. However, note that vim-scripts.org is no longer maintained.

### Vim help

If you need Vim help for vim-plug itself (e.g. `:help plug-options`), register vim-plug as a plugin.

```vim
Plug 'junegunn/vim-plug'
```

### Conditional activation

Use plain "if" statement to conditionally activate plugins:

```vim
if has('mac')
  Plug 'junegunn/vim-xmark'
endif
```

The caveat is that when the condition is not met, `PlugClean` will try to remove the plugin. This can be problematic if you share the same configuration across terminal Vim, GVim, and Neovim.

```vim
" When started with plain Vim, the plugin is not registered
" and PlugClean will try to remove it
if has('nvim')
  Plug 'benekastah/neomake'
endif
```

Alternatively, you can pass an empty `on` or `for` option so that the plugin is registered but not loaded by default depending on the condition.

```vim
Plug 'benekastah/neomake', has('nvim') ? {} : { 'on': [] }
```

A helper function can improve the readability.

```vim
function! Cond(cond, ...)
  let opts = get(a:000, 0, {})
  return a:cond ? opts : extend(opts, { 'on': [], 'for': [] })
endfunction

" Looks better
Plug 'benekastah/neomake', Cond(has('nvim'))

" With other options
Plug 'benekastah/neomake', Cond(has('nvim'), { 'on': 'Neomake' })
```

### Gist as plugin

vim-plug does not natively support installing small Vim plugins from Gist.
But there is a workaround if you really want it.

```vim
Plug 'https://gist.github.com/952560a43601cd9898f1.git',
    \ { 'as': 'xxx', 'do': 'mkdir -p plugin; cp -f *.vim plugin/' }
```

### Loading plugins manually

With `on` and `for` options, vim-plug allows you to defer loading of plugins. But if you want a plugin to be loaded on an event that is not supported by vim-plug, you can set `on` or `for` option to an empty list, and use `plug#load(names...)` function later to load the plugin manually. The following example will load [ultisnips](https://github.com/SirVer/ultisnips) and [YouCompleteMe](https://github.com/Valloric/YouCompleteMe) first time you enter insert mode.

```vim
" Load on nothing
Plug 'SirVer/ultisnips', { 'on': [] }
Plug 'Valloric/YouCompleteMe', { 'on': [] }

augroup load_us_ycm
  autocmd!
  autocmd InsertEnter * call plug#load('ultisnips', 'YouCompleteMe')
                     \| autocmd! load_us_ycm
augroup END
```
