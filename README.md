lcurses
=======

By the [lcurses project][GitHub]

[![License](http://img.shields.io/:license-mit-blue.svg)](http://mit-license.org)
[![travis-ci status](https://secure.travis-ci.org/lcurses/lcurses.png?branche=master)](http://travis-ci.org/lcurses/lcurses/builds)
[![Stories in Ready](https://badge.waffle.io/lcurses/lcurses.png?label=ready&title=Ready)](https://waffle.io/lcurses/lcurses)


lcurses is a curses binding for LuaJIT, [Lua][] 5.1, 5.2 and 5.3; like many
Lua modules it simply binds to the C APIs of the curses library, so it won't
build unless you have the headers and libraries to compile and link against
an installed curses library already on your system.  However, in the past
it has been tested against pdcurses, ncurses and a few proprietary curses
implementations.

For a while, lcurses was shipped inside [luaposix][], but now it has its
own repository and release schedule again.

Documentation is generated via [LDoc][] and is available at:

  http://lcurses.github.io/lcurses/

lcurses is released under the [MIT license][mit] (the same license as
Lua itself).  There is no warranty.

[github]: https://github.com/lcurses/lcurses "lcurses repository"
[lua]: http://www.lua.org/ "The Lua Project"
[luaposix]: https://github.com/luaposix/luaposix "luaposix repository"
[mit]: http://mit-license.org "MIT license"


Installation
------------

The simplest and best way to install lcurses is with [LuaRocks][]. To
install the latest release (recommended):

```bash
    luarocks install lcurses
```

To install current git master (for testing):

```bash
    luarocks install https://raw.githubusercontent.com/lcurses/lcurses/master/lcurses-git-1.rockspec
```

To install without LuaRocks, check out the sources from the
[repository][GitHub] and run the following commands:

```bash
    cd lcurses
    ./bootstrap
    ./configure --prefix=INSTALLATION-ROOT-DIRECTORY
    make all check install
```

Dependencies are listed in the dependencies entry of the file
`rockspec.conf`. You will also need Autoconf and Automake.

See the Automake generated INSTALL file for `configure`
instructions, and use `configure --help` after a successful
`./bootstrap` for details of available command-line switches.


Bugs reports & patches
----------------------

Bug reports and patches are most welcome.  Please report bugs and make
suggestions by opening an issue on the [github tracker][issues].

There is no strict coding style, but please bear in mind the following
points when writing new code:

0. Follow existing code. There are a lot of useful patterns and
   avoided traps there.

1. 8-character indentation using TABs in C sources; 2-character
   indentation using SPACEs in Lua sources.


[issues]: https://github.com/lcurses/lcurses/issues "lcurses issues"
[LuaRocks]: http://www.luarocks.org "Lua package manager"
[LDoc]: https://github.com/stevedonovan/LDoc "Lua documentation generator"
