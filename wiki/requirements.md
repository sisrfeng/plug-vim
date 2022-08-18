## Requirements
 
#### Git

However, installing plugins with tags is [known to fail](https://github.com/junegunn/vim-plug/issues/174) if Git is older than 1.7.10.
Git 1.8 or greater is recommended.


## Parallel installer

#### Vim 8 / Neovim

vim-plug starts non-blocking,
parallel installer on Vim 8 and  Neovim.
You can append `--sync` flag to `PlugInstall` or `PlugUpdate` command to make the installer block the control until
completion.

