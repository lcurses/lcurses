--[[
 Curses binding for Lua 5.1, 5.2, 5.3, 5.4 & 5.5
 Copyright (C) 2013-2026 Gary V. Vaughan
]]
--- Matchers for what a virtual terminal shows.
--
-- Requiring this module adds matchers that take an `lvterm` terminal as the
-- subject of an `expect`:
--
--     expect(term).to_show_row(0, 'hello')
--     expect(term).to_have_cursor_at(0, 5)
--     expect(term).to_show_cell(0, 0, {bold = true})
--     expect(term).to_look_like [[
--        +---+
--        |hi |
--        +---+
--     ]]
--
-- Trailing spaces are not significant in what a row shows.
--
-- @module screen

local matchers = require 'specl.matchers'

local Matcher, reformat, stringify =
   matchers.Matcher, matchers.reformat, matchers.stringify


local function rtrim(s)
   return (s:gsub('%s+$', ''))
end


-- Whether SUBJECT is a terminal that can be asked what it shows.
local function usable(subject)
   return type(subject) == 'table' and type(subject.lines) == 'function'
end


-- The rows of TERM without trailing spaces, down to the last that shows
-- anything.
local function rows(term)
   local lines, last = {}, 0
   for i, line in ipairs(term:lines()) do
      lines[i] = rtrim(line)
      if lines[i] ~= '' then
         last = i
      end
   end

   local shown = {}
   for i = 1, last do
      shown[i] = lines[i]
   end
   return shown
end


-- How the screen of SUBJECT looks, for a message.
local function show(subject)
   if not usable(subject) then
      return stringify(subject)
   end
   local row, col = subject:cursor()
   local lines = rows(subject)
   lines[#lines + 1] = string.format('(cursor at %d,%d)', row, col)
   return table.concat(lines, '\n')
end


-- The lines of PICTURE, without the blank lines at the end of it, nor the
-- indentation of the last line, if that is only spaces, as it is when the
-- closing delimiter of a long string is on a line of its own.
local function lines_of(picture)
   local lines = {}
   for line in (picture .. '\n'):gmatch '(.-)\n' do
      lines[#lines + 1] = line
   end

   local indent = 0
   if lines[#lines] and lines[#lines]:match '^ *$' then
      indent = #lines[#lines]
   end
   while #lines > 0 and lines[#lines]:match '^%s*$' do
      table.remove(lines)
   end

   for i, line in ipairs(lines) do
      lines[i] = rtrim(line:sub(indent + 1))
   end
   return lines
end


-- Whether ACTUAL, a field of a cell, is the same as WANT.
local function same(actual, want)
   if type(want) == 'table' then
      return type(actual) == 'table' and actual.red == want.red and
         actual.green == want.green and actual.blue == want.blue
   end
   return actual == want
end


-- The fields of CELL that FIELDS has, for a message.
local function describe(cell, fields)
   local keys = {}
   for key in pairs(fields) do
      keys[#keys + 1] = key
   end
   table.sort(keys)

   local items = {}
   for _, key in ipairs(keys) do
      local value = cell and cell[key]
      if type(value) == 'table' then
         value = string.format('{red=%s, green=%s, blue=%s}',
                               value.red, value.green, value.blue)
      end
      items[#items + 1] = key .. '=' .. tostring(value)
   end
   return table.concat(items, ', ')
end


-- The cell at ROW and COL of TERM, or nil if it is off the screen.
local function cell_at(term, row, col)
   local ok, cell = pcall(term.cell, term, row, col)
   return ok and cell or nil
end


local registry = matchers.matchers


--- The row of the screen shows some text.
-- @function to_show_row
-- @int row line to look at, from 0
-- @string text what it shows, without trailing spaces
registry.show_row = Matcher {
   function(self, actual, expected)
      if not usable(actual) then
         return false
      end
      local ok, shown = pcall(actual.row, actual, expected[1])
      return ok and rtrim(shown) == rtrim(expected[2])
   end,

   format_expect = function(self, expected)
      return string.format(' row %d to show:', expected[1]) ..
         reformat(expected[2])
   end,

   format_actual = function(self, actual)
      return ' this screen:' .. reformat(show(actual))
   end,
}


--- The cursor is at a position.
-- @function to_have_cursor_at
-- @int row line of the cursor, from 0
-- @int col column of the cursor, from 0
registry.have_cursor_at = Matcher {
   function(self, actual, expected)
      if not usable(actual) then
         return false
      end
      local row, col = actual:cursor()
      return row == expected[1] and col == expected[2]
   end,

   format_expect = function(self, expected)
      return string.format(' the cursor at %d,%d', expected[1], expected[2])
   end,

   format_actual = function(self, actual)
      if not usable(actual) then
         return ' ' .. stringify(actual)
      end
      return string.format(' the cursor at %d,%d', actual:cursor())
   end,
}


--- A cell has the attributes asked for.
-- @function to_show_cell
-- @int row line of the cell, from 0
-- @int col column of the cell, from 0
-- @tparam table fields the fields of `lvterm`'s `cell` that must be the
--   same, such as `{text = 'x', bold = true, fg = 1}`
registry.show_cell = Matcher {
   function(self, actual, expected)
      if not usable(actual) then
         return false
      end
      local row, col, fields = expected[1], expected[2], expected[3]
      local cell = cell_at(actual, row, col)
      if cell == nil then
         return false
      end
      for key, want in pairs(fields) do
         if not same(cell[key], want) then
            return false
         end
      end
      return true
   end,

   format_expect = function(self, expected)
      local row, col, fields = expected[1], expected[2], expected[3]
      return string.format(' cell %d,%d to have: ', row, col) ..
         describe(fields, fields)
   end,

   format_actual = function(self, actual, expected)
      if not usable(actual) then
         return ' ' .. stringify(actual)
      end
      local row, col, fields = expected[1], expected[2], expected[3]
      return ' ' .. describe(cell_at(actual, row, col), fields)
   end,
}


--- The screen looks like a picture, with nothing else on it.
-- The picture can be a multi-line string, which loses the blank lines
-- at the end of it, and the indentation of the line that the closing
-- delimiter is on, so a picture lines up with its `]]`, and any further
-- indentation is columns on the screen.  Blank lines at the start are the
-- rows at the top of the screen that are empty.
-- @function to_look_like
-- @string picture the rows of the screen, from the top
registry.look_like = Matcher {
   function(self, actual, picture)
      if not usable(actual) then
         return false
      end
      local want, have = lines_of(picture), rows(actual)
      if #want ~= #have then
         return false
      end
      for i = 1, #want do
         if want[i] ~= have[i] then
            return false
         end
      end
      return true
   end,

   format_expect = function(self, picture)
      return ' a screen like:' .. reformat(table.concat(lines_of(picture), '\n'))
   end,

   format_actual = function(self, actual)
      return ' this screen:' .. reformat(show(actual))
   end,
}


return {}
