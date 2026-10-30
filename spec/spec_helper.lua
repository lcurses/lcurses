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
      package.path
   )
end

local posix = require 'posix'

local fcntl, poll, signal, stdlib, unistd, wait =
   posix.fcntl, posix.poll, posix.signal, posix.stdlib, posix.unistd,
   posix.sys.wait

-- Allow use of bare 'pack' and 'unpack' even in Lua > 5.2.
local pack = table.pack or function(...) return {n = select('#', ...), ...} end
local unpack = table.unpack or unpack

local TIMEOUT = 10000  -- milliseconds that a child may take


-- Write the whole of STR to FD.
local function writeall(fd, str)
   while #str > 0 do
      local n = unistd.write(fd, str)
      str = str:sub(n + 1)
   end
end


-- Serialize the values after the status of `pcall` in the table RESULTS,
-- which may be numbers, strings, booleans and nils, as Lua source for a
-- chunk that returns how many there are, followed by the values.
local function serialize(results)
   local t = {tostring(results.n - 1)}
   for i = 2, results.n do
      local v = results[i]
      if type(v) == 'number' then
         t[#t + 1] = string.format('%.17g', v)
      elseif type(v) == 'string' then
         t[#t + 1] = string.format('%q', v)
      else
         t[#t + 1] = tostring(v)
      end
   end
   return 'return ' .. table.concat(t, ', ')
end


-- Read from the FDS that have something to say until `rd` is closed,
-- and send INPUT to `master` once `ctl` says that the child is ready.
-- Return what each of them said.
local function converse(master, rd, ctl, input, pid)
   local said = {[master] = {}, [rd] = {}, [ctl] = {}}
   local open = {[master] = true, [rd] = true, [ctl] = true}

   while open[rd] do
      local fds = {}
      for fd in pairs(open) do
         fds[fd] = {events = {IN = true}}
      end

      local n = poll.poll(fds, TIMEOUT)
      if n == 0 then
         signal.kill(pid, signal.SIGKILL)
         wait.wait(pid)
         error('timed out waiting for the child process', 3)
      end

      for fd in pairs(fds) do
         if fds[fd].revents.IN or fds[fd].revents.HUP then
            local data = unistd.read(fd, 4096)
            if data == nil or #data == 0 then
               open[fd] = nil
            else
               said[fd][#said[fd] + 1] = data
               if fd == ctl and input then
                  writeall(master, input)
                  input = nil
               end
            end
         end
      end
   end

   return table.concat(said[rd]), table.concat(said[master])
end


--- Run a function with a pseudo-terminal for its terminal.
-- The function runs in a child process, with its standard input,
-- output and error connected to a new pseudo-terminal, which looks like
-- an `xterm` of 24 lines and 80 columns, and can call `ready()` when it
-- is time for the *input* to arrive at the terminal.
-- @func f function to run, which is passed `ready`
-- @string[opt] input what to type at the terminal after `f` calls `ready`
-- @treturn table what `f` returned, with its count in `n`
-- @treturn string what `f` wrote to the terminal
function inpty(f, input)
   local master = assert(stdlib.openpt(fcntl.O_RDWR + fcntl.O_NOCTTY))
   assert(stdlib.grantpt(master))
   assert(stdlib.unlockpt(master))
   local slave = assert(stdlib.ptsname(master))

   local rd, wr = unistd.pipe()
   local ctl_rd, ctl_wr = unistd.pipe()

   io.stdout:flush()
   io.stderr:flush()
   local pid = assert(unistd.fork())

   if pid == 0 then
      unistd.close(master)
      unistd.close(rd)
      unistd.close(ctl_rd)

      -- Opening the pseudo-terminal in a new session makes it ours.
      unistd.setpid('s')
      local tty = assert(fcntl.open(slave, fcntl.O_RDWR))
      for fd = 0, 2 do
         unistd.dup2(tty, fd)
      end
      unistd.close(tty)

      stdlib.setenv('TERM', 'xterm')
      stdlib.setenv('LINES', '24')
      stdlib.setenv('COLUMNS', '80')

      local results = pack(pcall(f, function()
         unistd.write(ctl_wr, 'r')
      end))
      if results[1] then
         writeall(wr, serialize(results))
      else
         writeall(wr, 'error(' .. string.format('%q', tostring(results[2])) .. ', 0)')
      end
      unistd.close(wr)

      -- Count what the child ran, as `luacov` only saves its counts when
      -- the process that started it exits normally, and this one must not.
      local loaded = debug.getregistry()._LOADED
      local runner = loaded and loaded['luacov.runner']
      if runner and runner.initialized then
         runner.save_stats()
      end

      unistd._exit(0)
   end

   unistd.close(wr)
   unistd.close(ctl_wr)
   local data, screen = converse(master, rd, ctl_rd, input, pid)
   unistd.close(rd)
   unistd.close(ctl_rd)

   -- Closing the master hangs up the child, which has to finish first.
   wait.wait(pid)
   unistd.close(master)

   local values = pack(assert(load(data, 'child results'))())
   return {n = values[1], unpack(values, 2, values.n)}, screen
end


--- Run a function in a curses session on a pseudo-terminal.
-- Curses is initialized, with `cbreak` and no `echo`, before the function
-- runs, and ended after it returns.
-- @func f function to run, passed the live `curses` module, `stdscr` and
--   `ready`; examples have a copy of the module from before `initscr`
--   defined its constants, so they must use the one that they are given
-- @string[opt] input what to type at the terminal after `f` calls `ready`
-- @treturn table what `f` returned, with its count in `n`
-- @treturn string what was written to the terminal
function session(f, input)
   local curses = require 'curses'

   return inpty(function(ready)
      local stdscr = curses.initscr()
      curses.cbreak()
      curses.echo(false)

      local results = pack(f(curses, stdscr, ready))
      curses.endwin()
      return unpack(results, 1, results.n)
   end, input)
end
