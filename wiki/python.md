## Installing Vim with Python 2.7 support

### Requirements & Version Checking

POSIX OS, so Linux, BSD or OSX. No plans for Windows support.

Python 2 version >= 2.7, check with: ``` python --version ```

Vim/GVim with +python support. To check on command line
``` vim --version | grep +python ```
Alternatively, inside vim execute `:version`.

If you don't have the requirements see below.

### Ubuntu
If your distribution of Ubuntu comes with python 2.7 (like most recent), the packaged vim should be all that is needed. If it isn't installed then run:
```
sudo apt-get install vim
```

If you are on an older Ubuntu machine with 2.6 or older, see compiling instructions below to get latest python and/or vim compiled. Alternatively, you can try to find a PPA with 2.7, but I can't recommend one.

### Compiling From Source On POSIX
The following shell script should build python/vim assuming build requirements are met, just change the apt-get line to whatever your package manager uses. The DIR variable specifies install location for python & vim.

IMPORTANT: To use these daily, make sure your `.bashrc` or other init file updates PATH so that $DIR/bin is on it. So for BASH, in your `.bashrc` append `export PATH=/usr/local/bin:$PATH`.

```sh
#!/usr/bin/env bash
PYTHON_URL=https://www.python.org/ftp/python/2.7.9/Python-2.7.9.tar.xz                                                                
# This is where python & vim will be installed to
DIR=/usr/local

# List of dependencies on Ubuntu, bare minimum excluding GTK/GNOME support
sudo apt-get install build-essential autoconf libncurses5-dev xz-utils curl mercurial libncurses5-dev 

# Build python 2.7, install to $DIR
PYARC=python.tar.xz
curl -fLo $PYARC $PYTHON_URL
xzcat $PYARC | tar xvf -
cd Python*
./configure --prefix=$DIR
make && sudo make install
cd -
\rm -rf Python* $PYARC

# Build vim with +python, install to $DIR
hg clone https://code.google.com/p/vim/
cd vim
vi_cv_path_python=$DIR/bin/python ./configure --prefix=$DIR --with-features=huge --enable-pythoninterp
PATH=$DIR/bin:$PATH make && sudo make install
cd -      
\rm -rf vim
```

Script tested on vagrant Ubuntu Lucid with python 2.6 in system. Correctly built latest vim with Python 2.7 support.