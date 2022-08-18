Tutorial
========

What is a Vim plugin and why would I need a plugin manger?
-----------------------------------------------------------

A Vim plugin is a set of Vimscript files that are laid out in a certain
directory structure. Before plugin managers became popular, Vim plugins were
usually distributed as tarballs. Users would manually download the file and
extract it in a single directory called `~/.vim`, and Vim would load the files
under the directory during startup.

This simplistic "download & unzip" method might work for a tiny number of
plugins but the effectiveness of it degenerates quickly as the number of
plugins grows. All the files from different plugins share the same directory
structure and you can't easily tell which file is from which plugin of which
version. The directory becomes a mess, and it's really hard to update or
remove a certain plugin.

vim-plug, a modern Vim plugin manager, downloads plugins into separate
directories for you and makes sure that they are loaded correctly. It allows
you to easily update the plugins, review (and optionally revert) the changes,
and remove the plugins that are no longer used.

Setting up
----------

vim-plug is distributed as [a single Vimscript file][plug.vim].
All you have to do is to download the file in a directory so that Vim can load it.

[plug.vim]: https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

```sh
# Vim (~/.vim/autoload)
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Neovim (~/.local/share/nvim/site/autoload)
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```

Installing plugins
------------------

With vim-plug, you declare the list of plugins you want to use in your
Vim configuration file. It's `~/.vimrc` for ordinary Vim, and
`~/.config/nvim/init.vim` for Neovim. The list should start with
`call plug#begin(PLUGIN_DIRECTORY)` and end with `call plug#end()`.
`PLUGIN_DIRECTORY` is a placeholder for vim-plug's plugin directory.
Please do not set it to a directory from `runtimepath` option.
Do NOT set it to the `autoload/` directory where `plug.vim` is.

```vim
" Plugins will be downloaded under the specified directory.
call plug#begin(has('nvim') ? stdpath('data') . '/plugged' : '~/.vim/plugged')

" Declare the list of plugins.
Plug 'tpope/vim-sensible'
Plug 'junegunn/seoul256.vim'

" List ends here. Plugins become visible to Vim after this call.
call plug#end()
```

After adding the above to the top of your Vim configuration file, reload it
(`:source ~/.vimrc`) or restart Vim. Now run `:PlugInstall` to install the
plugins.

Updating plugins
----------------

Run `:PlugUpdate` to update the plugins. After the update is finished, you can
review the changes by pressing `D` in the window. Or you can do it later by
running `:PlugDiff`.

Reviewing the changes
---------------------

Updated plugins may have new bugs and no longer work correctly. With
`:PlugDiff` command you can review the changes from the last `:PlugUpdate` and
roll each plugin back to the previous state before the update by pressing `X`
on each paragraph.

Removing plugins
----------------

1. Delete or comment out `Plug` commands for the plugins you want to remove.
2. Reload vimrc (`:source ~/.vimrc`) or restart Vim
3. Run `:PlugClean`. It will detect and remove undeclared plugins.