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

-- Allow use of bare 'pack' and 'unpack' even in Lua > 5.2.
local pack = table.pack or function(...) return {n = select('#', ...), ...} end
local unpack = table.unpack or unpack


--- Run a function in a curses session on a pseudo-terminal.
-- Curses is initialized, with `cbreak` and no `echo`, before the function
-- runs, and ended after it returns.
-- @func f function to run, passed the live `curses` module, `stdscr` and
--   `ready`; examples have a copy of the module from before `initscr`
--   defined its constants, so they must use the one that they are given
-- @string[opt] input what to type at the terminal after `f` calls `ready`
-- @treturn table what `f` returned, with its count in `n`
-- @treturn string what was written to the terminal
-- @see terminal.run
function session(f, input)
   local curses = require 'curses'

   return terminal.run(function(ready)
      local stdscr = curses.initscr()
      curses.cbreak()
      curses.echo(false)

      local results = pack(f(curses, stdscr, ready))
      curses.endwin()
      return unpack(results, 1, results.n)
   end, {input = input})
end
