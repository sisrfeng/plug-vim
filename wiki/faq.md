## FAQ

### Does vim-plug generate help tags for my plugins?

Yes, it automatically generates help tags for all of your plugins whenever you run `PlugInstall` or `PlugUpdate`. But you can regenerate help tags only with `plug#helptags()` function.

### When should I use `on` or `for` option?

_"Premature optimization is the root of all evil."_

You most likely don't need them at all. A properly implemented Vim plugin should already load lazily without any help from the plugin manager (`:help autoload`). There are very few cases where those options actually make much sense. On-demand loading should only be used as the last resort. It is basically a hacky workaround and is not always guaranteed to work.

Before applying the options, make sure that you're tackling the right problem by breaking down the startup of time of Vim using `--startuptime`. See if there are plugins that take more than a few milliseconds to load.

```sh
vim --startuptime /tmp/log
```

### Shouldn't vim-plug update itself on `PlugUpdate` like Vundle?

There is a separate `PlugUpgrade` command and there are valid reasons behind the decision.
A detailed discussion can be found [here](https://github.com/junegunn/vim-plug/pull/240).

So if you want to make sure that you have the latest version of vim-plug after `PlugUpdate`,
just run `PlugUpgrade` after `PlugUpdate`.

```vim
PlugUpdate | PlugUpgrade
```

You can save some keystrokes by defining a custom command like follows:

```vim
command! PU PlugUpdate | PlugUpgrade
```

If you really, really want to use `PlugUpdate` only, you can set up vim-plug like follows:

```sh
# Manually clone vim-plug and symlink plug.vim to ~/.vim/autoload
mkdir -p ~/.vim/{autoload,plugged}
git clone https://github.com/junegunn/vim-plug.git ~/.vim/plugged/vim-plug
ln -s ~/.vim/plugged/vim-plug/plug.vim ~/.vim/autoload
```

and in your .vimrc:

```vim
call plug#begin('~/.vim/plugged')
Plug 'junegunn/vim-plug'
" ...
call plug#end()
" The caveat is that you should *never* use PlugUpgrade
delc PlugUpgrade
```

Unlike `PlugUpgrade`, you'll have to restart Vim after vim-plug is updated.

### Managing dependencies

vim-plug no longer handles [dependencies between plugins](https://github.com/junegunn/vim-plug/wiki/plugfile) and it's up to the user to manually specify `Plug` commands for dependent plugins.

```vim
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'
```

Some users prefer to use `|` separators or arbitrary indentation to express plugin dependencies in their configuration files.

```vim
" Vim script allows you to write multiple statements in a row using `|` separators
" But it's just a stylistic convention. If dependent plugins are written in a single line,
" it's easier to delete or comment out the line when you no longer need them.
Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
Plug 'junegunn/fzf', { 'do': './install --all' } | Plug 'junegunn/fzf.vim'

" Using manual indentation to express dependency
Plug 'kana/vim-textobj-user'
  Plug 'nelstrom/vim-textobj-rubyblock'
  Plug 'whatyouhide/vim-textobj-xmlattr'
  Plug 'reedes/vim-textobj-sentence'
```

- Ordering of plugins only matters when overriding an earlier plugin's commands or mappings, so putting the dependency next to the plugin that depends on it or next to other plugins' dependencies are both okay.
- In the rare case where plugins do overwrite commands or mappings, vim-plug requires you to manually reorder your plugins.

### What's the deal with `git::@` in the URL?
git::@是作者整出来的, 不是git或github的语法

When vim-plug clones a repository,
    it injects `git::@` into the URL (e.g.  `https://git::@github.com/junegunn/seoul256.vim.git`)
    which can be an issue 
    when you want to push some changes back to the remote.
So why? 
    It's a ¿little hack¿ to avoid username/password prompt from git 
        when the repository ¿doesn't exist¿.
            Such thing can happen when there's a typo in the argument,
            or when the repository is removed from GitHub.
    It looks kind of silly,
    but doing so is the only way I know that
    works on various versions of git.
However,
    Git 2.3.0 introduced `$GIT_TERMINAL_PROMPT` which can be used to  suppress user prompt,
    and vim-plug takes advantage of it and
    removes `git::@` when Git 2.3.0 or  above is found.

Also, there are two ways to override the default URL pattern:

1. Using full git url: `Plug 'https://github.com/junegunn/seoul256.vim.git'`
2. Or define `g:plug_url_format` for the plugins that you need to ¿work on¿. 
```vim
let g:plug_url_format = 'git@github.com:%s.git'
Plug 'junegunn/vim-easy-align'
Plug 'junegunn/seoul256.vim'

unlet g:plug_url_format
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
```

See [#168](https://github.com/junegunn/vim-plug/issues/168), [#161](https://github.com/junegunn/vim-plug/issues/161), [#133](https://github.com/junegunn/vim-plug/issues/133), [#109](https://github.com/junegunn/vim-plug/issues/109), [#56](https://github.com/junegunn/vim-plug/issues/56) for more details.

### I'm getting `Cannot find color scheme '...'. Does vim-plug support color schemes?

Yes, color schemes are not any different from other plugins. A common mistake is to put `:colorscheme NAME` before `call plug#end()`. Plugins are not activated before `plug#end()`, so make sure to load your color scheme after it.

## Troubleshooting

### Plugins are not installed/updated in parallel

Parallel installer is only enabled when at least one of the following conditions is met:

1. Vim with Ruby support: `has('ruby')` / Ruby 1.8.7 or above
1. Vim with Python support: `has('python') or has('python3')` / Python 2.6 or above
1. Neovim with job control: `exists('*jobwait')`

For more help, see the [requirements](https://github.com/junegunn/vim-plug/wiki/requirements).

### Vim: Caught deadly signal SEGV

If your Vim crashes with the above message, first check if its Ruby interface is
working correctly with the following command:

```vim
:ruby puts RUBY_VERSION
```

If Vim crashes even with this command, it is likely that Ruby interface is
broken, and you have to rebuild Vim with a working version of Ruby.
(`brew reinstall vim` or `./configure && make ...`)

If you're on OS X, one possibility is that you had installed Vim with
[Homebrew](http://brew.sh/) while using a Ruby installed with
[RVM](http://rvm.io/) or [rbenv](https://github.com/sstephenson/rbenv) and later
removed that version of Ruby. Thus, it is safer to build Vim with system ruby.

```sh
rvm use system
brew reinstall vim
```

If you're on Windows using cygwin and the above ruby command fails with:
`cannot load such file -- rubygems.rb (LoadError)`.
It means cygwin is missing the `rubygems` package.
Install it using the setup.exe that came with cygwin.

[Please let me know](https://github.com/junegunn/vim-plug/issues) if you can't
resolve the problem. In the meantime, you can put `let g:plug_threads = 1` in your vimrc, to disable the parallel installers.

### Python 2.7.11 Windows Registry Bug

Due to a [bug](https://bugs.python.org/issue25824) that slipped into this release, the registry entries and python.dll do not align. A simple work around is explained [here](https://github.com/k-takata/vim/commit/435be6dc61347d92029768f1678fdfdb9a543005).

### YouCompleteMe timeout

[YouCompleteMe (YCM)](https://github.com/Valloric/YouCompleteMe) is a huge project and you might run into timeouts when trying to install/update it with vim-plug.

The parallel installer of vim-plug (ruby or python) times out only when the stdout of the process is not updated for the designated seconds (default 60). Which means even if the whole process takes much longer than 60 seconds to complete, if the process is constantly printing the progress to stdout (`10%`, `11%`, ...) it should never time out. Nevertheless, we still experience problems when installing YCM :(

Workarounds are as follows:
- Increase `g:plug_timeout`
- Install YCM exclusively with `:PlugInstall YouCompleteMe`
    - In this case single-threaded vimscript installer, which never times out, is used
- Asynchronous Neovim installer does not implement timeout.

### Installing YouCompleteMe manually

[YouCompleteMe](https://github.com/Valloric/YouCompleteMe) is an exceptionally large plugin that can take a very long time to download and compile. For this reason, one may want to download and update YouCompleteMe manually only when it is needed. Install it on any directory you prefer and pass the name of the directory to the `Plug` command.

```vim
" Assuming that you have installed (or will install) YCM
" in ~/.vim/plugged/YouCompleteMe
Plug '~/.vim/plugged/YouCompleteMe'
```

vim-plug will load the plugin, but it will not try to install or update YouCompleteMe.

### fatal: dumb http transport does not support --depth

Apparently the git option `--depth 1` requires SSL on the remote Git server. It is now default, to reduce download size. To get around this, you can:

**Disable Shallow Cloning**

Add `let g:plug_shallow = 0` to your .vimrc.

**Mirror the repository on a Git server with https (i.e. Github or BitBucket).**

Then just add it normally with the new URI.

**Mark the plugin as local/unmanaged**

a) Clone it locally to `~/.vim/plugged/plugin_name`

b) Add to the vimrc with `Plug '~/.vim/plugged/plugin_name'`.

The leading tilda tells vim-plug not to do anything other than rtp for plugin_name.

### Windows System Error E484
There are two possible causes we've encountered.

1. Bad escaping. ~~On Windows, if you use '<', '>' or '|' in the file path, vim-plug is known to fail. Any other chars should be fine.~~ vim-plug supports the user's `&shell` since https://github.com/junegunn/vim-plug/commit/8a44109329757e29c4956162e3353df367ecdb71 was merged. It uses custom `shellescape` to support the following shells: cmd.exe, sh, powershell. Please report if this happens. 

1. System changes due to AutoRun commands executed on cmd.exe startup. See [docs](https://technet.microsoft.com/en-us/library/cc779439%28v=ws.10%29.aspx).

To see if your system suffers this second problem, run these reg queries. If either one returns a path to a bat file, you should carefully read it. You may have to edit/disable it to get vim-plug working.
```batch
REG QUERY "HKCU\Software\Microsoft\Command Processor" /v AutoRun
REG QUERY "HKLM\Software\Microsoft\Command Processor" /v AutoRun
```

### Filepath issues with Cygwin/MinGW Vim and Windows Git

Windows Git must be upgraded to support mixed paths (ie. `C:/Users/foo/.vim/plugged`).
Modify your vimrc to use `g:plug_home` instead of passing a filepath to `plug#begin` so that vim-plug does not convert it back to Unix paths (ie. `/home/foo/.vim/plugged`) and break when passing filepaths to Windows Git. Use `cygpath -m` command to convert a filepath to mixed paths. Plugins that define `dir` to install the plugin in some directory must use mixed paths as well.

```vim
function! s:fix_plug_path(path)
  if has('win32unix')
  \ && executable('cygpath')
  \ && executable('git')
  \ && split(system('git --version'))[2] =~# 'windows'
    return substitute(system('cygpath -m ' . a:path), '\r*\n\+$', '', '')
  endif
  return a:path
endfunction
let g:plug_home = s:fix_plug_path($HOME . '/.vim/plugged')
call plug#begin()
call plug#('junegunn/fzf', { 'dir': s:fix_plug_path($HOME . '/.fzf'), 'do': './install --all' })
```

Details at https://github.com/junegunn/vim-plug/issues/896

### cmd.exe console and garbled unicode characters

Options:

- update your terminal settings to use a font that supports unicode characters.
- Use powershell as your shell
- DO NOT SET/UNSET `chcp` (see issues listed in https://github.com/junegunn/vim-plug/issues?utf8=%E2%9C%93&q=is%3Aissue+chcp+ for details)
     - Reference: https://dev.to/mattn/please-stop-hack-chcp-65001-27db

### Errors on fish shell

If vim-plug doesn't work correctly on fish shell, you might need to add `set
shell=/bin/sh` to your `.vimrc`.

Refer to the following links for the details:
- http://badsimplicity.com/vim-fish-e484-cant-open-file-tmpvrdnvqe0-error/
- https://github.com/junegunn/vim-plug/issues/12
