lcurses
=======

Copyright (C) 2004-2026 lcurses authors

[![License](https://img.shields.io/:license-mit-blue.svg)](https://mit-license.org)
[![workflow status](https://github.com/lcurses/lcurses/actions/workflows/spec.yml/badge.svg?branch=master)](https://github.com/lcurses/lcurses/actions)
[![codecov.io](https://codecov.io/github/lcurses/lcurses/coverage.svg?branch=master)](https://codecov.io/github/lcurses/lcurses?branch=master)

lcurses is a curses binding for [Lua][] 5.1 (including LuaJIT), 5.2, 5.3,
5.4 and 5.5.  Like many Lua modules it simply binds to the C APIs of the
curses library, so it won't build unless you have the headers and
libraries to compile and link against an installed curses library
already on your system.  However, in the past it has been tested against
pdcurses, ncurses and a few proprietary curses implementations.

For a while, lcurses was shipped inside [luaposix][], but now it has its
own repository and release schedule again.

Documentation is generated via [LDoc][] and is available at:

  https://lcurses.github.io/lcurses/

lcurses is released under the [MIT license][mit] (the same license as
Lua itself).  There is no warranty.


Installation
------------

The simplest and best way to install lcurses is with [LuaRocks][]. To
install the latest release (recommended):

```bash
    luarocks install lcurses
```

To install current git master (for testing):

```bash
    luarocks install https://raw.githubusercontent.com/lcurses/lcurses/master/lcurses-dev-1.rockspec
```

To install into a tree of your own from a clone of the [repository][github],
and run the specs:

```bash
    cd lcurses
    luarocks --tree LCURSES-INSTALL-TREE make lcurses-dev-1.rockspec
    luarocks --tree LCURSES-INSTALL-TREE test
```

LuaRocks builds lcurses with [luarocks-build-luke][], which it installs
for the build, so there is no build without LuaRocks.  The build looks
for the first of the `ncursesw`, `ncurses` and `curses` libraries that
the host has, and for the headers that go with it.

The dependencies are listed in the `dependencies` entry of the file
[rockspec][L19].


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


[github]: https://github.com/lcurses/lcurses "lcurses repository"
[issues]: https://github.com/lcurses/lcurses/issues "lcurses issues"
[L19]: https://github.com/lcurses/lcurses/blob/master/lcurses-dev-1.rockspec#L19
[LDoc]: https://github.com/lunarmodules/LDoc "Lua documentation generator"
[lua]: https://www.lua.org/ "The Lua Project"
[luarocks]: https://luarocks.org "Lua package manager"
[luarocks-build-luke]: https://luarocks.org/modules/gvvaughan/luarocks-build-luke
[luaposix]: https://github.com/luaposix/luaposix "luaposix repository"
[mit]: https://mit-license.org "MIT license"
