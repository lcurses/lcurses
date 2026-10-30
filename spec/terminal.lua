--[[
 Curses binding for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2013-2026 Gary V. Vaughan
]]
--- Run Lua functions with a pseudo-terminal for a terminal.
--
-- Programs that draw on a terminal, or read from one, need a terminal to
-- be tested.  `terminal.run` forks a child process that has a new
-- pseudo-terminal for its standard input, output and error, runs a
-- function there, and returns what the function returned, and what it
-- wrote to the terminal.  The function can have what it reads typed at the
-- terminal for it.
--
-- The child shares the state of the process that forked it, so the
-- function can use whatever has been loaded already, and the code it runs
-- is covered by `luacov`.
--
-- @module terminal

local posix = require 'posix'

local fcntl, poll, signal, stdlib, unistd, wait =
   posix.fcntl, posix.poll, posix.signal, posix.stdlib, posix.unistd,
   posix.sys.wait

-- Allow use of bare 'pack' and 'unpack' even in Lua > 5.2.
local pack = table.pack or function(...) return {n = select('#', ...), ...} end
local unpack = table.unpack or unpack


local defaults = {
   term    = 'xterm',
   lines   = 24,
   columns = 80,
   timeout = 10000,  -- milliseconds that the child may take
}


-- Write the whole of STR to FD.
local function writeall(fd, str)
   while #str > 0 do
      str = str:sub(unistd.write(fd, str) + 1)
   end
end


-- Lua source for a chunk that returns the number of VALUES, which are
-- numbers, strings, booleans or nils, followed by the values themselves.
local function serialize(values)
   local t = {tostring(values.n)}
   for i = 1, values.n do
      local v = values[i]
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


-- The values that a chunk made by `serialize` returns, with their count in
-- the `n` field.
local function deserialize(source)
   local packed = pack(assert(load(source, 'child results'))())
   return {n = packed[1], unpack(packed, 2, packed.n)}
end


-- Open a pseudo-terminal, and return the descriptor of its master side, and
-- the name of its slave side.
local function open_pty()
   local master = assert(stdlib.openpt(fcntl.O_RDWR + fcntl.O_NOCTTY))
   assert(stdlib.grantpt(master))
   assert(stdlib.unlockpt(master))
   return master, assert(stdlib.ptsname(master))
end


-- Save the lines run in this process, as `luacov` only does when the
-- process that started it exits normally, which the child must not.
local function save_coverage()
   local loaded = debug.getregistry()._LOADED
   local runner = loaded and loaded['luacov.runner']
   if runner and runner.initialized then
      runner.save_stats()
   end
end


-- What the child does, until it exits: make the slave side of the
-- pseudo-terminal its terminal, run F, send what F returned down the pipe
-- WR, or an error, and say through CTL_WR when F calls `ready`.
local function run_child(f, options, slave, wr, ctl_wr)
   -- Opening the pseudo-terminal in a new session makes it ours.
   unistd.setpid('s')
   local tty = assert(fcntl.open(slave, fcntl.O_RDWR))
   for fd = 0, 2 do
      unistd.dup2(tty, fd)
   end
   unistd.close(tty)

   stdlib.setenv('TERM', options.term)
   stdlib.setenv('LINES', tostring(options.lines))
   stdlib.setenv('COLUMNS', tostring(options.columns))

   local results = pack(pcall(f, function()
      unistd.write(ctl_wr, 'r')
   end))

   -- Leaving without closing the Lua state doesn't flush what's buffered.
   io.stdout:flush()
   io.stderr:flush()

   if results[1] then
      writeall(wr, serialize{n = results.n - 1, unpack(results, 2, results.n)})
   else
      writeall(wr, string.format('error(%q, 0)', tostring(results[2])))
   end
   unistd.close(wr)

   save_coverage()
   unistd._exit(0)
end


-- Read what the child process PID says on the descriptors MASTER (the
-- terminal), RD (its results) and CTL (when it is ready for input), until
-- the results are complete, typing INPUT at the terminal once the child
-- is ready for it.  Return the results and the terminal output.
local function converse(pid, master, rd, ctl, input, timeout)
   local said = {[master] = {}, [rd] = {}, [ctl] = {}}
   local open = {[master] = true, [rd] = true, [ctl] = true}

   while open[rd] do
      local fds = {}
      for fd in pairs(open) do
         fds[fd] = {events = {IN = true}}
      end

      if poll.poll(fds, timeout) == 0 then
         signal.kill(pid, signal.SIGKILL)
         wait.wait(pid)
         error('timed out waiting for the child process', 0)
      end

      for fd, status in pairs(fds) do
         if status.revents.IN or status.revents.HUP then
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


local M = {}


--- Run a function with a pseudo-terminal for its terminal.
-- @func f function to run in a child process, which is passed `ready`,
--   a function it can call to have the `input` typed at the terminal
-- @tparam[opt] table options
-- @tparam[opt] string options.input what to type at the terminal, after
--   `f` calls `ready`
-- @tparam[opt='xterm'] string options.term the `TERM` of the terminal
-- @tparam[opt=24] int options.lines height of the terminal
-- @tparam[opt=80] int options.columns width of the terminal
-- @tparam[opt=10000] int options.timeout milliseconds to wait for `f`
--   to return before giving up and raising an error
-- @treturn table the numbers, strings, booleans and nils that `f`
--   returned, with their count in `n`; an error in `f` is raised here
-- @treturn string what `f` wrote to the terminal
function M.run(f, options)
   options = setmetatable(options or {}, {__index = defaults})

   local master, slave = open_pty()
   local rd, wr = unistd.pipe()
   local ctl_rd, ctl_wr = unistd.pipe()

   -- The child must not repeat what is waiting to be written here.
   io.stdout:flush()
   io.stderr:flush()
   local pid = assert(unistd.fork())

   if pid == 0 then
      unistd.close(master)
      unistd.close(rd)
      unistd.close(ctl_rd)
      run_child(f, options, slave, wr, ctl_wr)
   end

   unistd.close(wr)
   unistd.close(ctl_wr)
   local data, output = converse(
      pid, master, rd, ctl_rd, options.input, options.timeout
   )
   unistd.close(rd)
   unistd.close(ctl_rd)

   -- Closing the master hangs up the child, which has to finish first.
   wait.wait(pid)
   unistd.close(master)

   return deserialize(data), output
end


return M
