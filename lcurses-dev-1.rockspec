local _MODREV, _SPECREV = 'dev', '-1'

rockspec_format = '3.0'
package = 'lcurses'
version = _MODREV .. _SPECREV

description = {
   summary  = 'Lua bindings for curses',
   detailed = 'lcurses is a C library for Lua that wraps the curses API.',
   homepage = 'https://github.com/lcurses/lcurses/',
   license  = 'MIT/X11',
}

source = {
   url = 'https://github.com/lcurses/lcurses/archive/v' .. _MODREV .. '.zip',
   dir = 'lcurses-' .. _MODREV,
}

dependencies = {
   'lua >= 5.1, < 5.6',
}

build_dependencies = {
   'luarocks-build-luke >= 0.3',
}

build = {
   type = 'luke',

   defines  = {
      {PACKAGE = '"$package"'},
      {VERSION = '"$version"'},
      'NDEBUG',
      '_FORTIFY_SOURCE=2',
      platforms   = {
         aix      = {'_ALL_SOURCE'},
         bsd      = {'_BSD_SOURCE'},
         freebsd  = {'__BSD_VISIBLE'},
         macosx   = {'_DARWIN_C_SOURCE'},
      },
   },

   incdirs  = {
      'ext',
      'ext/include',
      '$LUA_INCDIR',
   },

   modules  = {
      {['curses_c'] = {
         defines   = {
            -- Whichever of the curses headers the host has, widest first.
            {HAVE_NCURSESW_CURSES_H = {checkheader='ncursesw/curses.h'}},
            {HAVE_NCURSESW_H        = {checkheader='ncursesw.h'}},
            {HAVE_NCURSES_CURSES_H  = {checkheader='ncurses/curses.h'}},
            {HAVE_NCURSES_H         = {checkheader='ncurses.h'}},
            {HAVE_CURSES_H          = {checkheader='curses.h'}},
            -- Both run with the curses library linked.
            {HAVE_RESIZETERM        = {checkfunc='resizeterm'}},
            {HAVE_STRLCPY           = {checkfunc='strlcpy'}},
         },
         libraries = {
            {checksymbol='initscr', libraries={'ncursesw', 'ncurses', 'curses'}},
         },
         sources   = 'ext/curses.c',
      }},

      {['curses'] = 'lib/curses.lua'},
   },

   -- A release commits its LDocs to install.
   copy_directories = {'doc'},
}

test_dependencies = {
   'ansicolors',
   'luacov',
   'specl >= 16',
}

test = {
   type = 'command',
   command = 'specl -vfreport --coverage spec/*_spec.yaml',
}

if _MODREV == 'dev' then
   -- Only a release builds LDocs, which `luke release` commits, but
   -- `check_dependencies` finds an ldoc here.  luarocks.org's ldoc fails
   -- on Lua 5.5; gvvaughan's works.
   build_dependencies[#build_dependencies + 1] = 'gvvaughan/ldoc'

   build.copy_directories = nil

   source = {
      url = 'git+https://github.com/lcurses/lcurses.git',
   }
end
