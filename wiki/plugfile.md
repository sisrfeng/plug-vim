## Dependency Resolution

### *Experimental support for dependency resolution has been deprecated and removed since vim-plug 0.5.0*

***

If a Vim plugin specifies its dependent plugins in `Plugfile` in its root
directory, vim-plug will automatically source it recursively during the
installation.

A `Plugfile` should contain a set of `Plug` commands for the dependent plugins.

I've created three dummy repositories with Plugfiles as an example to this
scheme.

- [junegunn/dummy1](https://github.com/junegunn/dummy1/blob/master/Plugfile)
  - Plugfile includes `Plug 'junegunn/dummy2'`
- [junegunn/dummy2](https://github.com/junegunn/dummy2/blob/master/Plugfile)
  - Plugfile includes `Plug 'junegunn/dummy3'`
- [junegunn/dummy3](https://github.com/junegunn/dummy3/blob/master/Plugfile)

If you put `Plug 'junegunn/dummy1'` in your configuration file, reload it, and
run `:PlugInstall`,

1. vim-plug first installs dummy1
2. And sees if the repository has Plugfile
3. Plugfile is loaded and vim-plug discovers dependent plugins
4. Dependent plugins are then installed as well, and their Plugfiles are
   examined and their dependencies are resolved recursively.

![](https://raw.github.com/junegunn/vim-plug/master/gif/Plugfile.gif)