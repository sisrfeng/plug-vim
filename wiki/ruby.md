## Installing Vim with Ruby support

### OS X

The current version of OS X already ships with Ruby-enabled Vim. :smiley:

If you wish to install a newer version (recommended), you can use [Homebrew](http://brew.sh/).

```sh
# If you use RVM, it's safer to build Vim with the system default Ruby
rvm use system
brew install vim
```

### Ubuntu

```
sudo apt-get install vim-nox
```

### Arch Linux

```
sudo pacman -S gvim
```

### Centos

You can build the recent version of Vim from source.

```sh
# Install prerequisites
sudo yum install -y ruby ruby-devel ncurses-devel

# Clone Vim repository
hg clone https://code.google.com/p/vim/

# Compile with Ruby interpreter and install
cd vim
./configure --with-features=huge --enable-rubyinterp
make -j $(nprocs)
sudo make install
```

### Windows

#### [msys2](http://sourceforge.net/projects/msys2/)

```sh
pacman -S ruby vim
```

#### GVim

Parallel installer on Windows GVim requires Python support.