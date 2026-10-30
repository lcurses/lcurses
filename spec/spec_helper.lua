--[[
 Curses binding for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2013-2026 Gary V. Vaughan
]]

do
   local std = require 'specl.std'

   -- Run the Lua module from this tree, for coverage, and the C module
   -- from the rock that `luarocks make` installed.
   package.path = std.package.normalize(
      './lib/?.lua',
      './spec/?.lua',
      package.path
   )
end

local terminal = require 'terminal'

-- A virtual terminal, to look at what is drawn on the screen, is only
-- there where lvterm has a backend for this Lua, which is LuaJIT for now.
-- The matchers are always there, so that spec files that use them parse.
local ok, lvterm_module = pcall(require, 'lvterm')
lvterm = ok and lvterm_module or nil
require 'screen'


--- Run a function in a curses session on a pseudo-terminal.
-- Curses is initialized, with `cbreak` and no `echo`, before the function
-- runs.  It is not ended after, so that the screen shows what the function
-- drew, as `endwin` leaves the alternate screen.
-- @func f function to run, passed the live `curses` module, `stdscr` and
--   `ready`; examples have a copy of the module from before `initscr`
--   defined its constants, so they must use the one that they are given
-- @string[opt] input what to type at the terminal after `f` calls `ready`
-- @treturn table what `f` returned, with its count in `n`
-- @treturn string what was written to the terminal
-- @treturn lvterm.Terminal|nil what the terminal shows, if there is a
--   virtual terminal for this Lua
-- @see terminal.run
function session(f, input)
   local curses = require 'curses'

   local results, output = terminal.run(function(ready)
      local stdscr = curses.initscr()
      curses.cbreak()
      curses.echo(false)
      return f(curses, stdscr, ready)
   end, {input = input})

   return results, output, lvterm and lvterm.new(24, 80):write(output)
end
