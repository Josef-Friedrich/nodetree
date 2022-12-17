--- The nodetree package.
--
-- Nodetree uses [LDoc](https://github.com/stevedonovan/ldoc) for the
--  source code documentation. The supported tags are described on in
--  the [wiki](https://github.com/stevedonovan/LDoc/wiki).
--
-- Nodes in LuaTeX are connected. The nodetree view distinguishs
-- between the `list` and `field` connections.
--
-- * `list`: Nodes, which are double connected by `next` and
--   `previous` fields.
-- * `field`: Connections to nodes by other fields than `next` and
--   `previous` fields, e. g. `head`, `pre`.
-- @module nodetree

-- luacheck: globals node tex luatexbase lfs callback os unicode status modules

---@class Node
---@field next Node|nil # the next node in a list, or nil
---@field id number # the node’s type (id) number
---@field subtype number # the node subtype identifier

---@alias ColorName `black` | `red` | `green` | `yellow` | `blue` | `magenta` | `cyan` | `white`
---@alias ColorMode `bright` | `dim`

---@alias ConnectionType `list` | `field` # A literal
--   is a string, which can be either `list` or `field`.
---@alias ConnectionState `stop` | `continue` # A literal which can
--   be either `continue` or `stop`.

if not modules then modules = { } end modules ['nodetree'] = {
  version   = '2.2.1',
  comment   = 'nodetree',
  author    = 'Josef Friedrich',
  copyright = 'Josef Friedrich',
  license   = 'The LaTeX Project Public License Version 1.3c 2008-05-04'
}

local direct            = node.direct
local todirect          = direct.todirect
local getchar           = direct.getchar
--- Lua 5.1 does not have the utf8 library (Lua 5.1 is the default
-- version in LuajitTeX). LuaJitTeX does include the slnunicode library.
local utf8              = utf8 or unicode.utf8
local utfchar           = utf8.char
local properties        = direct.get_properties_table()

--- A counter for the compiled TeX examples. Some TeX code snippets
-- a written into file, wrapped with some TeX boilerplate code.
-- This written files are compiled.
local example_counter = 0

--- The default options
local default_options = {
  callback = 'post_linebreak_filter',
  channel = 'term',
  color = 'colored',
  decimalplaces = 2,
  unit = 'pt',
  verbosity = 1,
}

--- The current options
-- They are changed very often.
local options = {}
for key, value in pairs(default_options) do
  options[key] = value
end

--- File descriptor
local output_file

--- The lua table named `tree_state` holds state values of the current
-- tree item.
--
-- `tree_state`:
--
-- * `1` (level):
--   * `list`: `continue`
--   * `field`: `stop`
-- * `2`:
--   * `list`: `continue`
--   * `field`: `stop`
-- @table
local tree_state = {}

--- Format functions.
--
-- Low level template functions.
--
-- @section format

local format = {
  ---@param input string
  ---
  ---@return string
  underscore = function(input)
    if options.channel == 'tex' then
      local result = input.gsub(input, '_', '\\_')
      return result
    else
      return input
    end
  end,

  ---@param input string
  ---
  ---@return string
  escape = function(input)
    if options.channel == 'tex' then
      local result = input.gsub(input, [[\]], [[\string\]])
      return result
    else
      return input
    end
  end,

  ---@param input number
  ---
  ---@return number
  number = function(input)
    local mult = 10^(options.decimalplaces or 0)
    return math.floor(input * mult + 0.5) / mult
  end,

  ---@param count? number # how many spaces should be output
  ---
  ---@return string
  whitespace = function(count)
    local whitespace
    local output = ''
    if options.channel == 'tex' then
      whitespace = '\\hspace{0.5em}'
    else
      whitespace = ' '
    end
    if not count then
      count = 1
    end
    for _ = 1, count do
      output = output .. whitespace
    end
    return output
  end,

  ---@param code number
  ---
  ---@return string
  color_code = function(code)
    return string.char(27) .. '[' .. tostring(code) .. 'm'
  end,

  ---
  ---@return string
  color_tex = function(color, mode)
    if not mode then mode = '' end
    return 'NTE' .. color .. mode
  end,

  ---
  ---@return string
  node_begin = function()
    if options.channel == 'tex' then
      return '\\mbox{'
    else
      return ''
    end
  end,

  ---
  ---@return string
  node_end = function()
    if options.channel == 'tex' then
      return '}'
    else
      return ''
    end
  end,

  ---@param count? number # how many new lines should be output
  ---
  ---@return string
  new_line = function(count)
    local output = ''
    if not count then
      count = 1
    end
    local new_line
    if options.channel == 'tex' then
      new_line = '\\par{}'
    else
      new_line = '\n'
    end

    for _ = 1, count do
      output = output .. new_line
    end
    return output
  end,

  ---@param id number
  ---
  ---@return string
  type_id = function(id)
    return '[' .. tostring(id) .. ']'
  end
}

--- Print the output to stdout or write it into a file (`output_file`).
-- New text is appended.
--
---@param text string # A text string.
local function nodetree_print(text)
  if options.channel == 'log' or options.channel == 'tex' then
    output_file:write(text)
  else
    io.write(text)
  end
end

--- Template functions.
-- @section template

local template = {
  node_colors = {
    hlist = {'red', 'bright'},
    vlist = {'green', 'bright'},
    rule = {'blue', 'bright'},
    ins = {'blue'},
    mark = {'magenta'},
    adjust = {'cyan'},
    boundary = {'red', 'bright'},
    disc = {'green', 'bright'},
    whatsit = {'yellow', 'bright'},
    local_par = {'blue', 'bright'},
    dir = {'magenta', 'bright'},
    math = {'cyan', 'bright'},
    glue = {'magenta', 'bright'},
    kern = {'green', 'bright'},
    penalty = {'yellow', 'bright'},
    unset = {'blue'},
    style = {'magenta'},
    choice = {'cyan'},
    noad = {'red'},
    radical = {'green'},
    fraction = {'yellow'},
    accent = {'blue'},
    fence = {'magenta'},
    math_char = {'cyan'},
    sub_box = {'red', 'bright'},
    sub_mlist = {'green', 'bright'},
    math_text_char = {'yellow', 'bright'},
    delim = {'blue', 'bright'},
    margin_kern = {'magenta', 'bright'},
    glyph = {'cyan', 'bright'},
    align_record = {'red'},
    pseudo_file = {'green'},
    pseudo_line = {'yellow'},
    page_insert = {'blue'},
    split_insert = {'magenta'},
    expr_stack = {'cyan'},
    nested_list = {'red'},
    span = {'green'},
    attribute = {'yellow'},
    glue_spec = {'magenta'},
    attribute_list = {'cyan'},
    temp = {'magenta'},
    align_stack = {'red', 'bright'},
    movement_stack = {'green', 'bright'},
    if_stack = {'yellow', 'bright'},
    unhyphenated = {'magenta', 'bright'},
    hyphenated = {'cyan', 'bright'},
    delta = {'red'},
    passive = {'green'},
    shape = {'yellow'},
  },

  ---
  -- [SGR (Select Graphic Rendition) Parameters](https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters)
  --
  -- __attributes__
  --
  -- | color      |code|
  -- |------------|----|
  -- | reset      |  0 |
  -- | clear      |  0 |
  -- | bright     |  1 |
  -- | dim        |  2 |
  -- | underscore |  4 |
  -- | blink      |  5 |
  -- | reverse    |  7 |
  -- | hidden     |  8 |
  --
  -- __foreground__
  --
  -- | color      |code|
  -- |------------|----|
  -- | black      | 30 |
  -- | red        | 31 |
  -- | green      | 32 |
  -- | yellow     | 33 |
  -- | blue       | 34 |
  -- | magenta    | 35 |
  -- | cyan       | 36 |
  -- | white      | 37 |
  --
  -- __background__
  --
  -- | color      |code|
  -- |------------|----|
  -- | onblack    | 40 |
  -- | onred      | 41 |
  -- | ongreen    | 42 |
  -- | onyellow   | 43 |
  -- | onblue     | 44 |
  -- | onmagenta  | 45 |
  -- | oncyan     | 46 |
  -- | onwhite    | 47 |
  --
  ---@param color ColorName # A color name.
  ---@param mode? ColorMode
  ---@param background? boolean # Colorize the background not the text.
  --
  ---@return string
  color = function(color, mode, background)
    if options.color ~= 'colored' then
      return ''
    end

    local output = ''
    local code

    if mode == 'bright' then
      output = format.color_code(1)
    elseif mode == 'dim' then
      output = format.color_code(2)
    end

    if not background then
      if color == 'reset' then code = 0
      elseif color == 'red' then code = 31
      elseif color == 'green' then code = 32
      elseif color == 'yellow' then code = 33
      elseif color == 'blue' then code = 34
      elseif color == 'magenta' then code = 35
      elseif color == 'cyan' then code = 36
      else code = 37 end
    else
      if color == 'black' then code = 40
      elseif color == 'red' then code = 41
      elseif color == 'green' then code = 42
      elseif color == 'yellow' then code = 43
      elseif color == 'blue' then code = 44
      elseif color == 'magenta' then code = 45
      elseif color == 'cyan' then code = 46
      elseif color == 'white' then code = 47
      else code = 40 end
    end
    return output .. format.color_code(code)
  end,

  --- Format the char field of a node. Try to find a textual representation that
  -- corresponds with the number stored into the `char` field.
  --
  -- LuaTeX’s `node.char` are not really characters, they are font glyph indices
  -- which sometimes happen to match valid Unicode characters. HarfBuzz shapers
  -- differentiates between glyph IDs and characters by adding to 0x120000 to
  -- glyph ID.
  --
  -- The code of this function is borrowed from the [function
  -- `get_glyph_info(n)`](https://github.com/latex3/luaotfload/blob/4c09fe264c1644792d95182280be259449e7da02/src/luaotfload-harf-plug.lua#L1018-L1031)
  -- of the luaotfload package. The harfbuzz mode in luaotfload uses this
  -- function to embed text in a PDF file and for messages that show textual
  -- representation of the nodes like over/underfull messages. It will not
  -- result in an error in other modes, but it might not give proper text
  -- representation, but that is a limitation of these modes.
  --
  -- It should be understood what the glyph nodes represent. Before
  -- processing by luaotfload they represent one-to-one mapping of the
  -- input characters. After processing, they represent font glyphs with
  -- potentially complicated relationship with input characters.
  --
  -- Relation between input characters and output glyphs are many-to-many.
  -- An input character may be represented by one or more glyphs, and
  -- output glyph might represent one or more input characters, and in
  -- some cases (e.g. when there is reordering) a group of input
  -- characters are represented by a group of output glyphs. In the 2nd
  -- and 3rd cases, the first glyph node will have a `glyph_info` property
  -- with all the characters of the group, and subsequent glyph nodes in
  -- the group will have empty `glyph_info` properties.
  --
  -- It should also noted that this mapping is not unique, the same glyph
  -- can represent different characters in different context.
  --
  ---@param head Node # The head node of a node list.
  ---
  ---@return string # A textual representation of the `char` number. In verbosity level 2 or great suffixed with `[char number]`
  char = function(head)
    -- See Issues #6 and #9
    local node_id = todirect(head) -- Convert to node id
    local props = properties[node_id]
    local info = props and props.glyph_info
    local textual
    local character_index = getchar(node_id)
    if info then
      textual = info
    elseif character_index == 0 then
      textual = '^^@'
    elseif character_index <= 31 or (character_index >= 127 and character_index <= 159) then
      -- The C0 range [c-zero] is the characters from U+0000 to U+001F
      -- (decimal 0-31) and U+007F (decimal 127), the C1 range is the
      -- characters from U+0080 to U+009F (decimal 128-159).
      textual = '???'
    elseif character_index < 0x110000 then
      textual = utfchar(character_index)
    else
      textual = string.format("^^^^^^%06X", character_index)
    end
    return character_index .. ' (' .. string.format('0x%x', character_index) .. ', \''.. textual .. '\')'
  end,

  ---@param length? `long`
  ---
  ---@return string
  line = function(length)
    local output
    if length == 'long' then
      output = '------------------------------------------'
    else
      output = '-----------------------'
    end
      return output .. format.new_line()
  end,

  ---@param connection_type ConnectionType
  ---@param connection_state ConnectionState
  ---@param last boolean
  ---
  ---@return string
  branch = function(connection_type, connection_state, last)
    local c = connection_type
    local s = connection_state
    local l = last
    if c == 'list' and s == 'stop' and l == false then
      return format.whitespace(2)
    elseif c == 'field' and s == 'stop' and l == false then
      return format.whitespace(2)
    elseif c == 'list' and s == 'continue' and l == false then
      return '│' .. format.whitespace()
    elseif c == 'field' and s == 'continue' and l == false then
      return '║' .. format.whitespace()
    elseif c == 'list' and s == 'continue' and l == true then
      return '├─'
    elseif c == 'field' and s == 'continue' and l == true then
      return '╠═'
    elseif c == 'list' and s == 'stop' and l == true then
      return '└─'
    elseif c == 'field' and s == 'stop' and l == true then
      return '╚═'
    end
    return ''
  end,
}

---@param number number
---@param order number
---@param field string
--
---@return string
function template.fill(number, order, field)
  local output
  if order ~= nil and order ~= 0 then
    if field == 'stretch' then
      output = '+'
    else
      output = '-'
    end
    return output .. string.format(
      '%g%s', number / 2^16,
      template.colored_string(
        'fi' .. string.rep('l', order - 1),
        'white',
        'dim'
      )
    )
  else
    return template.length(number)
  end
end

--- Colorize a text string.
--
---@param text string A text string.
---@param color ColorName A color name.
---@param mode ColorMode
---@param background? boolean # Colorize the background not the text.
--
---@return string
function template.colored_string(text, color, mode, background)
  if options.channel == 'tex' then
    if mode == 'dim' then
      mode = ''
    end
    return '\\textcolor{' ..
      format.color_tex(color, mode) ..
      '}{' ..
      text ..
      '}'
  else
   return template.color(color, mode, background) .. text .. template.color('reset')
  end
end

--- Format a scaled point input value into dimension string (`12pt`,
--  `1cm`)
--
---@param input number
--
---@return string
function template.length (input)
  local i = tonumber(input)
  if i ~= nil then
    input = i / tex.sp('1' .. options.unit)
  end
  return string.format(
    '%g%s',
    format.number(input),
    template.colored_string(options.unit, 'white', 'dim')
  )
end

--- Get all data from a table including metatables.
--
-- Properties will reside in a metatable, if nodes were copied using an
-- operation like box copy: (\copy). The LuaTeX manual states this: “If
-- the second argument of `set_properties_mode` is true, then a
-- metatable approach is chosen: the copy gets its own table with the
-- original table as metatable.”
--
-- Source: https://stackoverflow.com/a/5639667 Works if __index returns
-- table, which it should as per luatex manual
--
---@param data table # A Lua table.
---@param previous_data? table # The data of a Lua table of a previous recursive call.
---
---@return table # A merged table.
local function get_all_table_data(data, previous_data)
  -- If previous_data is nil, start empty, otherwise start with previous_data.
  local output = previous_data or {}

  -- Copy all the attributes from the table.
  for key, value in pairs(data) do
    output[key] = output[key] or value
  end

  -- Get table’s metatable, or exit if not existing
  local metatable = getmetatable(data)
  if type(metatable) ~= 'table' then
    return output
  end

  -- Get the `__index` from metatable, or exit if not table.
  local index = metatable.__index
  if type(index) ~= 'table' then
    return output
  end

  -- Include the data from index into data, recursively, and return.
  return get_all_table_data(index, output)
end

--- Convert a Lua table into a format string.
--
---@param table table A table to generate a inline view of.
--
---@return string
function template.table_inline(table)
  local tex_escape = ''
  if options.channel == 'tex' then
    tex_escape = '\\'
  end
  if type(table) == 'table' then
    table = get_all_table_data(table)
    local output = tex_escape .. '{'
    local kv_list = ''
    for key, value in pairs(table) do
        if type(key) ~= 'numbers' then
          key = '\'' ..
            template.colored_string(key, 'cyan', 'dim') .. '\''
        end
        kv_list = kv_list .. '[' .. key .. '] = ' ..
          template.table_inline(value) .. ', '
    end
    output = output .. kv_list:gsub(', $', '')
    return output .. tex_escape .. '}'
  else
    return tostring(table)
  end
end

--- Format a key value pair (`key: value, `).
--
---@param key string # A key.
---@param value string|number # A value.
---@param color? ColorName # A color name.
--
---@return string
function template.key_value(key, value, color)
  if type(color) ~= 'string' then
    color = 'yellow'
  end
  if options.channel == 'tex' then
    key = format.underscore(key)
  end
  local output = template.colored_string(key .. ':', color)
  if value then
    output = output .. ' ' .. value .. ', '
  end
  return output
end

---@param type string
---@param id number
---
---@return string
function template.type(type, id)
  local output
  if options.channel == 'tex' then
    output = format.underscore(type)
  else
    output = type
  end
  output = string.upper(output)
  if options.verbosity > 1 then
    output = output .. format.type_id(id)
  end
  return template.colored_string(
    output .. format.whitespace(),
    template.node_colors[type][1],
    template.node_colors[type][2]
  )
end

---@param callback_name string
---@param variables? table
---
---@return string
function template.callback(callback_name, variables)
  nodetree_print(
    format.new_line(2) ..
    'Callback: ' ..
    template.colored_string(format.underscore(callback_name), 'red', '', true) ..
    format.new_line()
  )
  if variables then
    for name, value in pairs(variables) do
      if value ~= nil and value ~= '' then
        nodetree_print(
          '- ' ..
          format.underscore(name) ..
          ': ' ..
          tostring(value) ..
          format.new_line()
        )
      end
    end
  end
  nodetree_print(template.line('long'))
end

---@param level number
---@param connection_type ConnectionType
---
---@return string
function template.branches(level, connection_type)
  local output = ''
  for i = 1, level - 1  do
    output = output .. template.branch('list', tree_state[i]['list'], false)
    output = output .. template.branch('field', tree_state[i]['field'], false)
  end
-- Format the last branches
  if connection_type == 'list' then
    output = output .. template.branch('list', tree_state[level]['list'], true)
  else
    output = output .. template.branch('list', tree_state[level]['list'], false)
    output = output .. template.branch('field', tree_state[level]['field'], true)
  end
  return output
end

--- Extend the node library
-- @section node_extended

local node_extended = {}

--- Get the ID of a node.
--
-- We have to convert the node into a string and than have to extract
-- the ID from this string using a regular expression. If you convert a
-- node into a string it looks like: `<node    nil <    172 >    nil :
-- hlist 2>`.
--
---@param n Node # A node.
--
---@return string
function node_extended.node_id(n)
  local result = string.gsub(tostring(n), '^<node%s+%S+%s+<%s+(%d+).*', '%1')
  return result
end

--- A table of all node subtype names.
--
-- __Nodes without subtypes:__
--
-- * `ins` (3)
-- * `mark` (4)
-- * `whatsit` (8)
-- * `local_par` (9)
-- * `dir` (10)
-- * `penalty` (14)
-- * `unset` (15)
-- * `style` (16)
-- * `choice` (17)
-- * `fraction` (20)
-- * `math_char` (23)
-- * `sub_box` (24)
-- * `sub_mlist` (25)
-- * `math_text_char` (26)
-- * `delim` (27)
-- * `margin_kern` (28)
-- * `align_record` (30)
-- * `pseudo_file` (31)
-- * `pseudo_line` (32)
-- * `page_insert` (33)
-- * `split_insert` (34)
-- * `expr_stack` (35)
-- * `nested_list` (36)
-- * `span` (37)
-- * `attribute` (38)
-- * `glue_spec` (39)
-- * `attribute_list` (40)
-- * `temp` (41)
-- * `align_stack` (42)
-- * `movement_stack` (43)
-- * `if_stack` (44)
-- * `unhyphenated` (45)
-- * `hyphenated` (46)
-- * `delta` (47)
-- * `passive` (48)
-- * `shape` (49)
--
---@return table
local function get_node_subtypes ()
    local subtypes = {
    -- hlist (0)
    hlist = {
      [0] = 'unknown',
      [1] = 'line',
      [2] = 'box',
      [3] = 'indent',
      [4] = 'alignment',
      [5] = 'cell',
      [6] = 'equation',
      [7] = 'equationnumber',
      [8] = 'math',
      [9] = 'mathchar',
      [10] = 'hextensible',
      [11] = 'vextensible',
      [12] = 'hdelimiter',
      [13] = 'vdelimiter',
      [14] = 'overdelimiter',
      [15] = 'underdelimiter',
      [16] = 'numerator',
      [17] = 'denominator',
      [18] = 'limits',
      [19] = 'fraction',
      [20] = 'nucleus',
      [21] = 'sup',
      [22] = 'sub',
      [23] = 'degree',
      [24] = 'scripts',
      [25] = 'over',
      [26] = 'under',
      [27] = 'accent',
      [28] = 'radical',
    },
    -- vlist (1)
    vlist = {
      [0] = 'unknown',
      [4] = 'alignment',
      [5] = 'cell',
    },
    -- rule (2)
    rule = {
      [0] = 'normal',
      [1] = 'box',
      [2] = 'image',
      [3] = 'empty',
      [4] = 'user',
      [5] = 'over',
      [6] = 'under',
      [7] = 'fraction',
      [8] = 'radical',
      [9] = 'outline',
    },
    -- adjust (5)
    adjust = {
      [0] = 'normal',
      [1] = 'pre',
    },
    -- boundary (6)
    boundary = {
      [0] = 'cancel',
      [1] = 'user',
      [2] = 'protrusion',
      [3] = 'word',
    },
    -- disc (7)
    disc  = {
      [0] = 'discretionary',
      [1] = 'explicit',
      [2] = 'automatic',
      [3] = 'regular',
      [4] = 'first',
      [5] = 'second',
    },
    -- math (11)
    math = {
      [0] = 'beginmath',
      [1] = 'endmath',
    },
    -- glue (12)
    glue = {
      [0]   = 'userskip',
      [1]   = 'lineskip',
      [2]   = 'baselineskip',
      [3]   = 'parskip',
      [4]   = 'abovedisplayskip',
      [5]   = 'belowdisplayskip',
      [6]   = 'abovedisplayshortskip',
      [7]   = 'belowdisplayshortskip',
      [8]   = 'leftskip',
      [9]   = 'rightskip',
      [10]  = 'topskip',
      [11]  = 'splittopskip',
      [12]  = 'tabskip',
      [13]  = 'spaceskip',
      [14]  = 'xspaceskip',
      [15]  = 'parfillskip',
      [16]  = 'mathskip',
      [17]  = 'thinmuskip',
      [18]  = 'medmuskip',
      [19]  = 'thickmuskip',
      [98]  = 'conditionalmathskip',
      [99]  = 'muglue',
      [100] = 'leaders',
      [101] = 'cleaders',
      [102] = 'xleaders',
      [103] = 'gleaders',
    },
    -- kern (13)
    kern = {
      [0] = 'fontkern',
      [1] = 'userkern',
      [2] = 'accentkern',
      [3] = 'italiccorrection',
    },
    -- penalty (14)
    penalty = {
      [0] = 'userpenalty',
      [1] = 'linebreakpenalty',
      [2] = 'linepenalty',
      [3] = 'wordpenalty',
      [4] = 'finalpenalty',
      [5] = 'noadpenalty',
      [6] = 'beforedisplaypenalty',
      [7] = 'afterdisplaypenalty',
      [8] = 'equationnumberpenalty',
    },
    noad = {
      [0] = 'ord',
      [1] = 'opdisplaylimits',
      [2] = 'oplimits',
      [3] = 'opnolimits',
      [4] = 'bin',
      [5] = 'rel',
      [6] = 'open',
      [7] = 'close',
      [8] = 'punct',
      [9] = 'inner',
      [10] = 'under',
      [11] = 'over',
      [12] = 'vcenter',
    },
    -- radical (19)
    radical = {
      [0] = 'radical',
      [1] = 'uradical',
      [2] = 'uroot',
      [3] = 'uunderdelimiter',
      [4] = 'uoverdelimiter',
      [5] = 'udelimiterunder',
      [6] = 'udelimiterover',
    },
    -- accent (21)
    accent = {
      [0] = 'bothflexible',
      [1] = 'fixedtop',
      [2] = 'fixedbottom',
      [3] = 'fixedboth',
    },
    -- fence (22)
    fence = {
      [0] = 'unset',
      [1] = 'left',
      [2] = 'middle',
      [3] = 'right',
      [4] = 'no',
    },
    -- margin_kern (28)
    margin_kern = {
      [0] = 'left',
      [1] = 'right',
    },
    -- glyph (29)
    -- the subtype for this node is a bit field, not an enumeration;
    -- bit 0 gets handled separately
    glyph = {
      [1] = 'ligature',
      [2] = 'ghost',
      [3] = 'left',
      [4] = 'right',
    },
  }
  subtypes.whatsit = node.whatsits()
  return subtypes
end

---@param n Node
---
---@return string
function node_extended.subtype(n)
  local typ = node.type(n.id)
  local subtypes = get_node_subtypes()
  local output = ''
  if subtypes[typ] then
    if typ == 'glyph' then
      -- only handle the lowest five bits
      if n.subtype & 1 == 0 then
        output = output .. 'glyph'
      else
        output = output .. 'character'
      end
      local mask = 2
      for i = 1,4,1 do
        if n.subtype & mask ~= 0 then
          output = output .. ' ' .. subtypes[typ][i]
        end
        mask = mask << 1
      end
    else
      if subtypes[typ][n.subtype] then
        output = subtypes[typ][n.subtype]
      else
        return tostring(n.subtype)
      end
    end

    if options.verbosity > 1 then
      output = output .. format.type_id(n.subtype)
    end
    return output
  else
    return tostring(n.subtype)
  end
end

--- Build the node tree.
-- @section tree

local tree = {}

---
---@param head Node # The head node of a node list.
---@param field string
--
---@return string
function tree.format_field(head, field)
  local output

  -- subtypes with IDs 0 are were not printed, see #12
  if head[field] ~= nil and field == "subtype" then
    return template.key_value(field, format.underscore(node_extended.subtype(head)))
  end

  -- Character "0" should be printed in a tree, because in TeX fonts the
  -- 0 slot usually has a symbol.
  if head[field] == nil or (head[field] == 0 and field ~= "char") then
    return ''
  end

  if options.verbosity < 2 and
    -- glyph
    field == 'font' or
    field == 'left' or
    field == 'right' or
    field == 'uchyph' or
    -- hlist
    field == 'dir' or
    field == 'glue_order' or
    field == 'glue_sign' or
    field == 'glue_set' or
    -- glue
    field == 'stretch_order' then
    return ''
  elseif options.verbosity < 3 and
    field == 'prev' or
    field == 'next' or
    field == 'id'
  then
    return ''
  end

  if field == 'prev' or field == 'next' then
    output = node_extended.node_id(head[field])
  elseif
    field == 'width' or
    field == 'height' or
    field == 'depth' or
    field == 'kern' or
    field == 'shift' then
    output = template.length(head[field])
  elseif field == 'char' then
    output = template.char(head)
  elseif field == 'glue_set' then
    output = format.number(head[field])
  elseif field == 'stretch' or field == 'shrink' then
    output = template.fill(head[field], head[field .. '_order'], field)
  else
    output = tostring(head[field])
  end

  return template.key_value(field, output)
end

---
-- Attributes are key/value number pairs. They are printed as an inline
-- list. The attribute `0` with the value `0` is skipped because this
-- attribute is in every node by default.
--
---@param head Node # The head node of a node list.
--
---@return string
function tree.format_attributes(head)
  if not head then
    return ''
  end
  local output = ''
  local attr = head.next
  while attr do
    if attr.number ~= 0 or (attr.number == 0 and attr.value ~= 0) then
      output = output .. tostring(attr.number) .. '=' .. tostring(attr.value) .. ' '
    end
    attr = attr.next
  end
  return output
end

---
---@param level number # `level` is a integer beginning with 1.
---@param connection_type ConnectionType
---@param connection_state ConnectionState
function tree.set_state(level, connection_type, connection_state)
  if not tree_state[level] then
    tree_state[level] = {}
  end
  tree_state[level][connection_type] = connection_state
end

---
---@param fields table
---@param level number
function tree.analyze_fields(fields, level)
  local max = 0
  local connection_state
  for _ in pairs(fields) do
    max = max + 1
  end
  local count = 0
  for field_name, recursion_node in pairs(fields) do
    count = count + 1
    if count == max then
      connection_state = 'stop'
    else
      connection_state = 'continue'
    end
    tree.set_state(level, 'field', connection_state)
    nodetree_print(
      format.node_begin() ..
      template.branches(level, 'field') ..
      template.key_value(field_name) ..
      format.node_end() ..
      format.new_line()
    )
    tree.analyze_list(recursion_node, level + 1)
  end
end

---
---@param head Node # The head node of a node list.
---@param level number
function tree.analyze_node(head, level)
  local connection_state
  local output
  if head.next then
    connection_state = 'continue'
  else
    connection_state = 'stop'
  end
  tree.set_state(level, 'list', connection_state)
  output = template.branches(level, 'list')
    .. template.type(node.type(head.id), head.id)
  if options.verbosity > 1 then
    output = output .. template.key_value('no', node_extended.node_id(head))
  end

  -- We store the attributes output to append it to the field list.
  local attributes

  -- We store fields which are nodes for later treatment.
  local fields = {}

  -- Inline fields, for example: char: 'm', width: 25pt, height: 13.33pt,
  local output_fields = ''
  for _, field_name in pairs(node.fields(head.id, head.subtype)) do
    if field_name == 'attr' then
      attributes = tree.format_attributes(head.attr)
    elseif field_name ~= 'next' and field_name ~= 'prev' and
      node.is_node(head[field_name]) then
      fields[field_name] = head[field_name]
    else
      output_fields = output_fields .. tree.format_field(head, field_name)
    end
  end
  if output_fields ~= '' then
    output = output .. output_fields
  end

  -- Append the attributes output if available
  if attributes ~= '' then
    output = output .. template.key_value('attr', attributes, 'blue')
  end

  output = output:gsub(', $', '')

  nodetree_print(
    format.node_begin() ..
    output ..
    format.node_end() ..
    format.new_line()
  )

  local property = node.getproperty(head)
  if property then
    nodetree_print(
      format.node_begin() ..
      template.branches(level, 'field') ..
      '  ' ..
      template.colored_string('properties:', 'blue') .. ' ' ..
      template.table_inline(property) ..
      format.node_end() ..
      format.new_line()
    )
  end

  tree.analyze_fields(fields, level)
end

---
---@param head Node # The head node of a node list.
---@param level number
function tree.analyze_list(head, level)
  while head do
    tree.analyze_node(head, level)
    head = head.next
  end
end

---
---@param head Node # The head node of a node list.
function tree.analyze_callback(head)
  tree.analyze_list(head, 1)
  nodetree_print(template.line('short') .. format.new_line())
end

--- Callback wrapper.
-- @section callbacks

local callbacks = {

  ---
  ---@param extrainfo string
  ---
  ---@return boolean
  contribute_filter = function(extrainfo)
    template.callback('contribute_filter', {extrainfo = extrainfo})
    return true
  end,

  ---
  ---@param extrainfo string
  ---
  ---@return boolean
  buildpage_filter = function(extrainfo)
    template.callback('buildpage_filter', {extrainfo = extrainfo})
    return true
  end,

  ---
  ---@param n string
  ---@param i string
  ---
  ---@return number
  build_page_insert = function(n, i)
    template.callback('build_page_insert', {n = n, i = i})
    return 0
  end,

  ---
  ---@param head Node # The head node of a node list.
  ---@param groupcode string
  ---
  ---@return boolean
  pre_linebreak_filter = function(head, groupcode)
    template.callback('pre_linebreak_filter', {groupcode = groupcode})
    tree.analyze_callback(head)
    return true
  end,

  ---
  ---@param head Node # The head node of a node list.
  ---@param is_display boolean
  ---
  ---@return boolean
  linebreak_filter = function(head, is_display)
    template.callback('linebreak_filter', {is_display = is_display})
    tree.analyze_callback(head)
    return true
  end,

  ---
  ---@param box Node
  ---@param locationcode string
  ---@param prevdepth number
  ---@param mirrored boolean
  append_to_vlist_filter = function(box, locationcode, prevdepth, mirrored)
    local variables = {
      locationcode = locationcode,
      prevdepth = prevdepth,
      mirrored = mirrored,
    }
    template.callback('append_to_vlist_filter', variables)
    tree.analyze_callback(box)
    return box
  end,

  ---
  ---@param head Node # The head node of a node list.
  ---@param groupcode string
  ---
  ---@return boolean
  post_linebreak_filter = function(head, groupcode)
    template.callback('post_linebreak_filter', {groupcode = groupcode})
    tree.analyze_callback(head)
    return true
  end,

  ---
  ---@param head Node # The head node of a node list.
  ---@param groupcode string
  ---@param size number
  ---@param packtype string
  ---@param direction string
  ---@param attributelist Node
  ---
  ---@return boolean
  hpack_filter = function(head, groupcode, size, packtype, direction, attributelist)
    local variables = {
      groupcode = groupcode,
      size = size,
      packtype = packtype,
      direction = direction,
      attributelist = attributelist,
    }
    template.callback('hpack_filter', variables)
    tree.analyze_callback(head)
    return true
  end,

  ---
  ---@param head Node # The head node of a node list.
  ---@param groupcode string
  ---@param size number
  ---@param packtype string
  ---@param maxdepth number
  ---@param direction string
  ---@param attributelist Node
  ---
  ---@return boolean
  vpack_filter = function(head, groupcode, size, packtype, maxdepth, direction, attributelist)
    local variables = {
      groupcode = groupcode,
      size = size,
      packtype = packtype,
      maxdepth = template.length(maxdepth),
      direction = direction,
      attributelist = attributelist,
    }
    template.callback('vpack_filter', variables)
    tree.analyze_callback(head)
    return true
  end,

  ---
  ---@param incident string
  ---@param detail number
  ---@param head Node # The head node of a node list.
  ---@param first number
  ---@param last number
  hpack_quality = function(incident, detail, head, first, last)
    local variables = {
      incident = incident,
      detail = detail,
      first = first,
      last = last,
    }
    template.callback('hpack_quality', variables)
    tree.analyze_callback(head)
  end,

  ---
  ---@param incident string
  ---@param detail number
  ---@param head Node # The head node of a node list.
  ---@param first number
  ---@param last number
  vpack_quality = function(incident, detail, head, first, last)
    local variables = {
      incident = incident,
      detail = detail,
      first = first,
      last = last,
    }
    template.callback('vpack_quality', variables)
    tree.analyze_callback(head)
  end,

  ---
  ---@param head Node # The head node of a node list.
  ---@param width number
  ---@param height number
  ---
  ---@return boolean
  process_rule = function(head, width, height)
    local variables = {
      width = width,
      height = height,
    }
    template.callback('process_rule', variables)
    tree.analyze_callback(head)
    return true
  end,

  ---
  ---@param head Node # The head node of a node list.
  ---@param groupcode string
  ---@param size number
  ---@param packtype string
  ---@param maxdepth number
  ---@param direction string
  ---
  ---@return boolean
  pre_output_filter = function(head, groupcode, size, packtype, maxdepth, direction)
    local variables = {
      groupcode = groupcode,
      size = size,
      packtype = packtype,
      maxdepth = maxdepth,
      direction = direction,
    }
    template.callback('pre_output_filter', variables)
    tree.analyze_callback(head)
    return true
  end,

  ---
  ---@param head Node # The head node of a node list.
  ---@param tail Node
  hyphenate = function(head, tail)
    template.callback('hyphenate')
    nodetree_print('head:' .. format.new_line())
    tree.analyze_callback(head)
    nodetree_print('tail:' .. format.new_line())
    tree.analyze_callback(tail)
  end,

  ---
  ---@param head Node # The head node of a node list.
  ---@param tail Node
  ligaturing = function(head, tail)
    template.callback('ligaturing')
    nodetree_print('head:' .. format.new_line())
    tree.analyze_callback(head)
    nodetree_print('tail:' .. format.new_line())
    tree.analyze_callback(tail)
  end,

  ---
  ---@param head Node # The head node of a node list.
  ---@param tail Node
  kerning = function(head, tail)
    template.callback('kerning')
    nodetree_print('head:' .. format.new_line())
    tree.analyze_callback(head)
    nodetree_print('tail:' .. format.new_line())
    tree.analyze_callback(tail)
  end,

  ---
  ---@param local_par Node
  ---@param location string
  ---
  ---@return boolean
  insert_local_par = function(local_par, location)
    template.callback('insert_local_par', {location = location})
    tree.analyze_callback(local_par)
    return true
  end,

  ---
  ---@param head Node # The head node of a node list.
  ---@param display_type string
  ---@param need_penalties boolean
  mlist_to_hlist = function(head, display_type, need_penalties)
    local variables = {
      display_type = display_type,
      need_penalties = need_penalties,
    }
    template.callback('mlist_to_hlist', variables)
    tree.analyze_callback(head)
    return node.mlist_to_hlist(head, display_type, need_penalties)
  end,
}

--- Set a single option key value pair.
--
---@param key string # The key of the option pair.
---@param value number|string # The value of the option pair.
local function set_option(key, value)
  if not options then
    options = {}
  end
  if key == 'verbosity' or key == 'decimalplaces' then
    options[key] = tonumber(value)
  else
    options[key] = value
  end
end

--- Set multiple key value pairs using a table.
--
---@param opts table # Options
local function set_options(opts)
  if not options then
    options = {}
  end
  for key, value in pairs(opts) do
    set_option(key, value)
  end
end

--- Check if the given callback name exists.
--
-- Throw an error if it doen’t.
--
---@param callback_name string # The name of a callback to check.
--
---@return string # The unchanged input of the function.
local function check_callback_name(callback_name)
  local info = callback.list()
  if info[callback_name] == nil then
    tex.error(
      'Package "nodetree": Unkown callback name or callback alias: "' ..
      callback_name ..
      '"'
    )
  end
  return callback_name
end

--- Get the real callback name from an alias string.
--
---@param alias string The alias of a callback name or the callback
-- name itself.
--
---@return string # The real callback name.
local function get_callback_name(alias)
  local callback_name
  -- Listed as in the LuaTeX reference manual.
  if alias == 'contribute' or alias == 'contributefilter' then
    callback_name = 'contribute_filter'

  -- Formerly called buildpage, now there is a build_page_insert.
  elseif alias == 'buildfilter' or alias == 'buildpagefilter' then
    callback_name = 'buildpage_filter'

  -- Untested: I don’t know how to invoke this filter.
  elseif alias == 'buildinsert' or alias == 'buildpageinsert' then
    callback_name = 'build_page_insert'

  elseif alias == 'preline' or alias == 'prelinebreakfilter' then
    callback_name = 'pre_linebreak_filter'

  elseif alias == 'line' or alias == 'linebreakfilter' then
    callback_name = 'linebreak_filter'

  elseif alias == 'append' or alias == 'appendtovlistfilter' then
    callback_name = 'append_to_vlist_filter'

  -- postlinebreak is not documented.
  elseif alias == 'postline' or alias == 'postlinebreak' or alias == 'postlinebreakfilter' then
    callback_name = 'post_linebreak_filter'

  elseif alias == 'hpack' or alias == 'hpackfilter' then
    callback_name = 'hpack_filter'

  elseif alias == 'vpack' or alias == 'vpackfilter' then
    callback_name = 'vpack_filter'

  elseif alias == 'hpackq' or alias == 'hpackquality' then
    callback_name = 'hpack_quality'

  elseif alias == 'vpackq' or alias == 'vpackquality' then
    callback_name = 'vpack_quality'

  elseif alias == 'process' or alias == 'processrule' then
    callback_name = 'process_rule'

  elseif alias == 'preout' or alias == 'preoutputfilter' then
    callback_name = 'pre_output_filter'

  elseif alias == 'hyph' or alias == 'hyphenate' then
    callback_name = 'hyphenate'

  elseif alias == 'liga' or alias == 'ligaturing' then
    callback_name = 'ligaturing'

  elseif alias == 'kern' or alias == 'kerning' then
    callback_name = 'kerning'

  elseif alias == 'insert' or alias == 'insertlocalpar' then
    callback_name = 'insert_local_par'

  elseif alias == 'mhlist' or alias == 'mlisttohlist' then
    callback_name = 'mlist_to_hlist'

  else
    callback_name = alias
  end
  return check_callback_name(callback_name)
end

--- Register a callback.
--
---@param cb string # The name of a callback.
local function register_callback(cb)
  if luatexbase then
    luatexbase.add_to_callback(cb, callbacks[cb], 'nodetree')
  else
    callback.register(cb, callbacks[cb])
  end
end

--- Unregister a callback.
--
---@param cb string # The name of a callback.
local function unregister_callback(cb)
  if luatexbase then
    luatexbase.remove_from_callback(cb, 'nodetree')
  else
    register_callback(cb, nil)
  end
end

--- Exported functions.
-- @section export

local export = {
  set_option = set_option,
  set_options = set_options,

  ---
  register_callbacks = function()
    if options.channel == 'log' or options.channel == 'tex' then
      -- nt = nodetree
      -- jobname.nttex
      -- jobname.ntlog
      local file_name = tex.jobname .. '.nt' .. options.channel
      io.open(file_name, 'w'):close() -- Clear former content
      output_file = io.open(file_name, 'a')
    end
    for alias in string.gmatch(options.callback, '([^,]+)') do
      register_callback(get_callback_name(alias))
    end
  end,

  ---
  unregister_callbacks = function()
    for alias in string.gmatch(options.callback, '([^,]+)') do
      unregister_callback(get_callback_name(alias))
    end
  end,

  --- Compile a TeX snippet.
  --
  -- Write some TeX snippets into a temporary LaTeX file, compile this
  -- file using `latexmk` and read the generated `*.nttex` file and
  -- return its content.
  --
  ---@param tex_markup string
  --
  ---@return string
  compile_include = function(tex_markup)
    -- Generate a subfolder for all tempory files: _nodetree-jobname.
    local parent_path = lfs.currentdir() .. '/' .. '_nodetree-' .. tex.jobname
    lfs.mkdir(parent_path)

    -- Generate the temporary LuaTeX or LuaLaTeX file.
    example_counter = example_counter + 1
    local filename_tex = example_counter .. '.tex'
    local absolute_path_tex = parent_path .. '/' .. filename_tex
    output_file = io.open(absolute_path_tex, 'w')

    local format_option = function (key, value)
      return '\\NodetreeSetOption[' .. key .. ']{' .. value .. '}' .. '\n'
    end

    -- Process the options
    local options =
      format_option('channel', 'tex') ..
      format_option('verbosity', options.verbosity) ..
      format_option('unit', options.unit) ..
      format_option('decimalplaces', options.decimalplaces) ..
      '\\NodetreeUnregisterCallback{post_linebreak_filter}'  .. '\n' ..
      '\\NodetreeRegisterCallback{' .. options.callback .. '}'

    local prefix = '%!TEX program = lualatex\n' ..
                  '\\documentclass{article}\n' ..
                  '\\usepackage{nodetree}\n' ..
                  options .. '\n' ..
                  '\\begin{document}\n'
    local suffix = '\n\\end{document}'
    output_file:write(prefix .. tex_markup .. suffix)
    output_file:close()

    -- Compile the temporary LuaTeX or LuaLaTeX file.
    os.spawn({ 'latexmk', '-cd', '-pdflua', absolute_path_tex })
    local include_file = assert(io.open(parent_path .. '/' .. example_counter .. '.nttex', 'rb'))
    local include_content = include_file:read("*all")
    include_file:close()
    include_content = include_content:gsub('[\r\n]', '')
    tex.print(include_content)
  end,

  --- Check for `--shell-escape`
  --
  check_shell_escape = function()
    local info = status.list()
    if info.shell_escape == 0 then
      tex.error('Package "nodetree-embed": You have to use the --shell-escape option')
    end
  end,

  --- Print a node tree.
  ---
  ---@param head Node # The head node of a node list.
  ---@param opts table # Options as a table.
  print = function(head, opts)
    if opts and type(opts) == 'table' then
      set_options(opts)
    end
    nodetree_print(format.new_line())
    tree.analyze_list(head, 1)
  end,

  --- Format a scaled point value into a formated string.
  --
  ---@param sp number # A scaled point value
  --
  ---@return string
  format_dim = function(sp)
    return template.length(sp)
  end,

  --- Get a default option that is not changed.
  ---@param key string # The key of the option.
  --
  ---@return string|number|boolean
  get_default_option = function(key)
    return default_options[key]
  end
}

--- Use export.print
--
---@param head Node # The head node of a node list.
export.analyze = export.print

return export
