--- This file (`nodetree.lua`) is part of the LuaTeX package
--- 'nodetree'.
---
---`nodetree` uses the annotation system of the
---[lua-language-server](https://github.com/LuaLS/lua-language-server/wiki/Annotations).
---Install the [type definitions for LuaTeX](https://github.com/Josef-Friedrich/LuaTeX_Lua-API)
---or the [Visual Studio Code Extension](https://marketplace.visualstudio.com/items?itemName=JosefFriedrich.luatex).
---
---The LDoc support is deprecated.
---
---Nodes in LuaTeX are connected. The nodetree view distinguishes
---between *list* and *field* connections.
---
---* list: Nodes that are doubly connected by `next` and `previous`
---  fields.
---* field: Connections to nodes by other fields than `next` and
---  `previous` fields, e.g., `head`, `pre`.
---@module nodetree

---luacheck: globals node lang tex luatexbase lfs
---luacheck: globals callback os unicode status modules

---
---@alias ColorName 'black'|'red' |'green'|'yellow'|'blue'|'magenta'|'cyan'|'white'|'reset'
---@alias ColorMode 'bright'|'dim'|''
---
---@alias ConnectionType 'list'|'field' # A string literal,
---  which can be either 'list' or 'field'.
---@alias ConnectionState 'stop'|'continue' # A literal, which can
---  be either `continue` or `stop`.

if not modules then modules = {} end modules ['nodetree'] = {
  version   = '2.3.0',
  comment   = 'nodetree',
  author    = 'Josef Friedrich',
  copyright = 'Josef Friedrich',
  license   = 'The LaTeX Project Public License Version 1.3c 2008-05-04'
}

local direct            = node.direct
local todirect          = direct.todirect
local getchar           = direct.getchar
---Lua 5.1 does not have the utf8 library (Lua 5.1 is the default
---version in LuajitTeX). LuaJitTeX does include the slnunicode library.
local utf8              = utf8 or unicode.utf8
local utfchar           = utf8.char
local properties        = direct.get_properties_table()

---A counter for the compiled TeX examples. Some TeX code snippets
---a written into files, wrapped with some TeX boilerplate code.
---These written files are compiled later on.
local example_counter = 0

---A flag to indicate that something has been emitted by nodetree.
local have_output = false

--- The default options.
local default_options = {
  callback = 'post_linebreak_filter',
  channel = 'term',
  color = 'colored',
  decimalplaces = 2,
  unit = 'pt',
  verbosity = 0,
  firstline = 1,
  lastline = -1,
}

--- The current options.
local options = {}
for key, value in pairs(default_options) do
  options[key] = value
end

--- The previous options.
---We need this for functions `push_options` and `pop_options` so that
---the effects of the `\setkeys` commands in `nodetree-embed.sty`
---(which directly manipulates the `options` table) stay local.
local prev_options = {}
local option_level = 0

---File descriptor.
local output_file

--- The state values of the current tree item.
---
---`tree_state`:
---
---* `1` (level):
---  * `list`: `continue`
---  * `field`: `stop`
---* `2`:
---  * `list`: `continue`
---  * `field`: `stop`
---
---...
local tree_state = {}

--- Format functions.
---
---Low-level template functions.
---
---@section format

local format = {
  ---@function format.underscore
  ---
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

  ---@function format.escape
  ---
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

  ---@function format.function
  ---
  ---@param input number
  ---
  ---@return number
  number = function(input)
    local mult = 10^(options.decimalplaces or 0)
    return math.floor(input * mult + 0.5) / mult
  end,

  ---@function format.whitespace
  ---
  ---@param count? number # How many spaces should be output.
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

  ---@function format.color_code
  ---
  ---@param code number
  ---
  ---@return string
  color_code = function(code)
    return string.char(27) .. '[' .. tostring(code) .. 'm'
  end,

  ---@function format.color_tex
  ---
  ---@param color string
  ---@param mode? string
  ---
  ---@return string
  color_tex = function(color, mode)
    if not mode then mode = '' end
    return 'NTE' .. color .. mode
  end,

  ---@function format.node_begin
  ---
  ---@return string
  node_begin = function()
    if options.channel == 'tex' then
      return '\\mbox{'
    else
      return ''
    end
  end,

  ---@function format.node_end
  ---
  ---@return string
  node_end = function()
    if options.channel == 'tex' then
      return '}'
    else
      return ''
    end
  end,

  ---@function format.new_line
  ---
  ---@param count? number # How many new lines should be output.
  ---
  ---@return string
  new_line = function(count)
    local output = ''
    if not count then
      count = 1
    end
    local new_line
    if options.channel == 'tex' then
      new_line = '\\par\n'
    else
      new_line = '\n'
    end

    for _ = 1, count do
      output = output .. new_line
    end
    return output
  end,

  ---@function format.type_id
  ---
  ---@param id number
  ---
  ---@return string
  type_id = function(id)
    return '[' .. tostring(id) .. ']'
  end
}

--- Print the output to stdout or write it into a file (`output_file`).
---New text is appended.
---
---@param text string # A text string.
local function nodetree_print(text)
  if options.channel == 'log' or options.channel == 'tex' then
    output_file:write(text)
  else
    io.write(text)
  end
end

--- Template functions.
---
---@section template

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

  -- Field name abbreviations for verbosity level 0. A second field
  -- limits the abbreviation to this node type.
  --
  -- Entry '' means to omit the key, printing only the value. Entry
  -- '()' means the same, but the value gets printed in parentheses.
  field_abbrevs = {
    char = {''},
    depth = {'dp'},
    dir = {'()', 'dir'},
    height = {'ht'},
    kern = {''},
    mark = {''},
    penalty = {'', 'penalty'},
    shrink = {'minus'},
    stretch = {'plus'},
    style = {''},
    subtype = {'()'},
    width = {'wd'},
  },

  --- [SGR (Select Graphic Rendition)
  -- parameters](https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters).
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
  ---@function template.color
  ---
  ---@param color ColorName # A color name.
  ---@param mode? ColorMode
  ---@param background? boolean # If set, colorize the background instead of the text.
  ---
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
  -- corresponds with the number stored in the `char` field.
  --
  -- LuaTeX’s `node.char` values are not really characters; they are font glyph indices
  -- which sometimes happen to match valid Unicode characters. HarfBuzz shapers
  -- differentiate between glyph IDs and characters by adding to 0x120000 to
  -- glyph IDs.
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
  ---@function template.char
  --
  ---@param head Node # The head node of a node list.
  ---
  ---@return string # A textual representation of the `char` number.
  char = function(head)
    local node_id = todirect(head) -- Convert to node id.
    local props = properties[node_id]
    local info = props and props.glyph_info
    local textual
    local character_index = getchar(node_id)

    if info then
      textual = info
    elseif character_index == 0 then
      textual = '^^@'
    elseif character_index <= 31 or (character_index >= 127 and character_index <= 159) then
      -- The C0 range [c-zero] contains characters from U+0000 to U+001F
      -- (decimal 0-31) and U+007F (decimal 127), the C1 range covers
      -- characters from U+0080 to U+009F (decimal 128-159).
      textual = '???'
    elseif character_index ~= nil and character_index < 0x110000 then
      textual = utfchar(character_index)
    else
      textual = string.format('^^^^^^%06X', character_index)
    end

    if options.verbosity == 0 then
      if textual == '???' then
        return character_index
      else
        return "'" .. textual .. "'"
      end
    elseif options.verbosity <= 2 then
      return character_index .. " ('" .. textual .. "')"
    else
      return character_index
        .. ' ('
        .. string.format('0x%x', character_index)
        .. ", '"
        .. textual
        .. "')"
    end
  end,

  ---@function template.line
  ---
  ---@param length string # If `long`, emit a longer line.
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

  ---@function template.branch
  ---
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
---
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
---
---@param text string # A text string.
---@param color ColorName # A color name.
---@param mode? ColorMode
---@param background? boolean # If set, colorize the background instead of the text.
---
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
--- `1cm`)
---
---@param input number
---
---@return string
function template.length(input)
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
---
---Properties will reside in a metatable if nodes were copied using an
---operation like box copy: (\copy). The LuaTeX manual states this: “If
---the second argument of `set_properties_mode` is true, then a
---metatable approach is chosen: the copy gets its own table with the
---original table as metatable.”
---
---Source: [StackOverflow](https://stackoverflow.com/a/5639667) – this
---works if `__index` returns a table, which it should as per LuaTeX
---manual.
---
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

  -- Get table’s metatable, or exit if not existing.
  local metatable = getmetatable(data)
  if type(metatable) ~= 'table' then
    return output
  end

  -- Get the `__index` from metatable, or exit if not table.
  local index = metatable.__index
  if type(index) ~= 'table' then
    return output
  end

  -- Include the data from index into data recursively and return.
  return get_all_table_data(index, output)
end

--- Convert a Lua table into a format string.
---
---@param table table # A table to generate an inline view of.
---
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

--- Format a key-value pair (`key: value, `).
---
---@param key string # A key.
---@param value string|number # A value.
---@param typ? string # A node type. Had to be named typ to avoid conflict with the type() function.
---@param color? ColorName # A color name.
---
---@return string
function template.key_value(key, value, typ, color)
  if type(color) ~= 'string' then
    color = 'yellow'
  end
  key = format.underscore(key)

  local output = ''
  local abbrev = nil
  local separator = ':'

  if options.verbosity == 0 then
    if template.field_abbrevs[key] then
      local only_this_type = template.field_abbrevs[key][2]
      if not only_this_type or not typ or only_this_type == typ then
        abbrev = template.field_abbrevs[key][1]
      end
    end
    separator = ''
  end

  if abbrev == nil then
    output = template.colored_string(key .. separator, color)
  elseif abbrev ~= '' and abbrev ~= '()' then
    output = template.colored_string(abbrev, color)
  end

  if value then
    if abbrev == '()' then
      -- Printing '(unused)' is confusing.
      if value ~= 'unused' then
        output = output .. '(' .. value .. ') '
      end
    elseif abbrev == '' then
      output = output .. value .. ', '
    else
      output = output .. ' ' .. value .. ', '
    end
  end
  return output
end

---@param type string
---@param id number
---
---@return string
function template.type(type, id)
  local output
  output = format.underscore(type)
  output = string.upper(output)
  if options.verbosity > 1 then
    output = output .. format.type_id(id)
  end
  return template.colored_string(
    output,
    template.node_colors[type][1],
    template.node_colors[type][2]
  )
end

---@param callback_name string
---@param variables table|nil
---@param where 'before'|'after' # `'before'` or `'after'`
function template.callback(callback_name, variables, where)
  if options.channel == 'term' or have_output == true then
    nodetree_print(format.new_line(2))
  end

  have_output = true

  nodetree_print(
    where .. ' callback ' ..
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
          format.underscore(tostring(value)) ..
          format.new_line()
        )
      end
    end
  end
  nodetree_print(template.line('long'))
end

--- Format the branching tree for one output line.
---
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
---Format the last branches
  if connection_type == 'list' then
    output = output .. template.branch('list', tree_state[level]['list'], true)
  else
    output = output .. template.branch('list', tree_state[level]['list'], false)
    output = output .. template.branch('field', tree_state[level]['field'], true)
  end
  return output
end

--- Node library extensions.
---
---@section node_extended

local node_extended = {}

--- Get the ID of a node.
---
---We have to convert the node into a string and then to extract
---the ID from this string using a regular expression. If you convert a
---node into a string it looks like: `<node    nil <    172 >    nil :
---hlist 2>`.
---
---@param n Node # A node.
---
---@return string
function node_extended.node_id(n)
  local result = string.gsub(tostring(n), '^<node%s+%S+%s+<%s+(%d+).*', '%1')
  return result
end

--- A table of all node subtype names.
---
---__Nodes without subtypes:__
---
---* `ins` (3)
---* `local_par` (9)
---* `penalty` (14)
---* `unset` (15)
---* `style` (16)
---* `choice` (17)
---* `fraction` (20)
---* `math_char` (23)
---* `sub_box` (24)
---* `sub_mlist` (25)
---* `math_text_char` (26)
---* `delim` (27)
---* `margin_kern` (28)
---* `align_record` (30)
---* `pseudo_file` (31)
---* `pseudo_line` (32)
---* `page_insert` (33)
---* `split_insert` (34)
---* `expr_stack` (35)
---* `nested_list` (36)
---* `span` (37)
---* `attribute` (38)
---* `glue_spec` (39)
---* `attribute_list` (40)
---* `temp` (41)
---* `align_stack` (42)
---* `movement_stack` (43)
---* `if_stack` (44)
---* `unhyphenated` (45)
---* `hyphenated` (46)
---* `delta` (47)
---* `passive` (48)
---* `shape` (49)
---
---@return table
local function get_node_subtypes()
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
    -- mark (4)
    -- The subtype is not used.
    mark = {
      [0] = 'unused',
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
    disc = {
      [0] = 'discretionary',
      [1] = 'explicit',
      [2] = 'automatic',
      [3] = 'regular',
      [4] = 'first',
      [5] = 'second',
    },
    -- dir (10)
    -- This is an internal detail, see luatex source code file
    -- `texnodes.h`.
    -- dir = {
    --   [0] = 'normal_dir',
    --   [1] = 'cancel_dir',
    -- },
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
    -- The subtype for this node is a bit field, not an enumeration;
    -- bit 0 gets handled separately.
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
      -- Only handle the lowest five bits.
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

--- Node tree building functions.
---
---@section tree

local tree = {}

---
---@param head Node # The head node of a node list.
---@param field string
---
---@return string
function tree.format_field(head, field)
  local output
  local typ = node.type(head.id)

  -- Print subtypes also for nodes with ID=0. However, suppress the
  -- internal 'subtype' field for 'dir' nodes.
  if field == 'subtype' then
    if typ == 'dir' then
      return ''
    elseif head[field] ~= nil then
      return template.key_value(field,
                                format.underscore(node_extended.subtype(head)))
    end
  end

  -- Character 0 should be printed in a tree because the corresponding slot
  -- zero in a TeX font usually contains a symbol.
  if head[field] == nil or (head[field] == 0 and field ~= 'char') then
    return ''
  end

  if options.verbosity < 2 and
    -- glyph
    field == 'left' or
    field == 'right' or
    field == 'uchyph' or
    -- hlist
    -- Don't drop the 'dir' field of the 'dir' node.
    (field == 'dir' and typ ~= 'dir') or
    field == 'glue_order' or
    field == 'glue_sign' or
    field == 'glue_set' or
    -- glue
    field == 'stretch_order' then
    return ''
  elseif options.verbosity < 3 and
    field == 'prev' or
    field == 'next' or
    field == 'id' then
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
    -- Surround strings with single quotes except values of fields
    -- that get potentially abbreviated (and thus don't really need
    -- quotes).
    if type(head[field]) == 'string' and not template.field_abbrevs[field] then
      output = template.colored_string("'", 'yellow') ..
        head[field] ..
        template.colored_string("'", 'yellow')
    elseif type(head[field]) == 'table' then
      output = '<table>'
    else
      output = tostring(head[field])
    end
  end

  return template.key_value(field, output, node.type(head.id))
end

---
---Attributes are key-value number pairs. They are printed as an inline
---list. The attribute `0` with the value `0` is skipped because this
---attribute is in every node by default.
---
---@param head Node # The head node of a node list.
---
---@return string
function tree.format_attributes(head)
  if not head then
    return ''
  end
  local space = ''
  local output = ''
  local attr = head.next --[[@as AttributeNode]]
  while attr do
    if attr.number ~= 0 or (attr.number == 0 and attr.value ~= 0) then
      output = output .. space .. tostring(attr.number) .. '=' .. tostring(attr.value)
      space = ' '
    end
    attr = attr.next --[[@as AttributeNode]]
  end
  return output
end

---
---@param level number # `level` is an integer beginning with 1.
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
---@param level number # The current recursion level.
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
---@param level number # The current recursion level.
function tree.analyze_node(head, level)
  local connection_state
  local output
  local need_whitespace = true
  if head.next then
    connection_state = 'continue'
  else
    connection_state = 'stop'
  end
  tree.set_state(level, 'list', connection_state)
  output = template.branches(level, 'list')
    .. template.type(node.type(head.id), head.id)
  if options.verbosity > 1 then
    output = output ..
      format.whitespace() ..
      template.key_value('no', node_extended.node_id(head))
    need_whitespace = false
  end

  -- We store the attributes output so that we can append it to the field
  -- list later on.
  local attributes

  -- We store fields which are nodes for later treatment.
  local fields = {}

  -- Inline fields, for example: char: 'm', width: 25pt, height: 13.33pt.
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
    if need_whitespace == true then
      output = output .. format.whitespace()
      need_whitespace = false
    end
    output = output .. output_fields
  end

  -- Append the attributes output if available.
  if attributes and attributes ~= '' then
    if need_whitespace == true then
      output = output .. format.whitespace()
    end
    output = output .. template.key_value('attr', attributes, nil, 'blue')
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
    local props
    if options.verbosity == 0 then
      props = 'props'
    else
      props = 'properties:'
    end

    -- Print attributes in a separate line.
    nodetree_print(
      format.node_begin() ..
      template.branches(level, 'field') ..
      '  ' ..
      template.colored_string(props, 'blue') .. ' ' ..
      template.table_inline(property) ..
      format.node_end() ..
      format.new_line()
    )
  end

  tree.analyze_fields(fields, level)
end

--- Recurse over the current node list.
---
---@param head Node # The head node of a node list.
---@param level number # The current recursion level.
function tree.analyze_list(head, level)
  while head do
    tree.analyze_node(head, level)
    head = head.next
  end
end

--- The top-level internal entry point.
---
---@param head Node # The head node of a node list.
function tree.analyze_callback(head)
  tree.analyze_list(head, 1)
  nodetree_print(template.line('short'))
end

local orig_callbacks = {}
local orig_descriptions = {}

local print_positions = {}
local callback_has_default_action = {
  hyphenate = true,
  ligaturing = true,
  kerning = true,
  mlist_to_hlist = true
}

--- Callback wrappers.
---
---Nodetree uses luatexbase's functions to manage callbacks if
---available. Otherwise a simplistic approach is taken by prepending
---or appending nodetree's diagnostic callbacks to the existing ones
---(and also removing them again if requested).
---
---Each function in the `callback_wrappers` table consists of three
---parts:
---
---* before-callback inspection
---* original callback or default function call
---* after-callback inspection
---
---The actual callback functions are stored in the `callbacks` table.
---
---@section callbacks

local callback_wrappers = {
  ---@function callbacks.contribute_filter
  ---
  ---@param extrainfo string
  ---@param where string
  contribute_filter = function(extrainfo, where)
    local cb = 'contribute_filter'
    local before, after = template.get_print_position(where)

    if before then
      template.callback(cb, {extrainfo = extrainfo}, before)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        orig_callbacks[cb](extrainfo)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {extrainfo = extrainfo}, after)
    end
  end,

  ---@function callbacks.buildpage_filter
  ---
  ---@param extrainfo string
  ---@param where string
  buildpage_filter = function(extrainfo, where)
    local cb = 'buildpage_filter'
    local before, after = template.get_print_position(where)

    if before then
      template.callback(cb, {extrainfo = extrainfo}, before)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        orig_callbacks[cb](extrainfo)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {extrainfo = extrainfo}, after)
    end
  end,

  ---@function callbacks.build_page_insert
  ---
  ---@param n string
  ---@param i string
  ---
  ---@return number
  build_page_insert = function(n, i)
    local cb = 'build_page_insert'
    local before, after = template.get_print_position(cb)
    local retval = 0

    if before then
      template.callback(cb, {n = n, i = i}, before)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        retval = orig_callbacks[cb](n, i)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {n = n, i = i}, after)
    end

    return retval
  end,

  ---@function callbacks.pre_linebreak_filter
  ---
  ---@param head Node # The head node of a node list.
  ---@param groupcode string
  ---@param where string
  ---
  ---@return boolean
  pre_linebreak_filter = function(head, groupcode, where)
    local cb = 'pre_linebreak_filter'
    local before, after = template.get_print_position(where)
    local retval = true

    if before then
      template.callback(cb, {groupcode = groupcode}, before)
      tree.analyze_callback(head)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        retval = orig_callbacks[cb](head, groupcode)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {groupcode = groupcode}, after)
      tree.analyze_callback(head)
    end

    return retval
  end,

  ---@function callbacks.linebreak_filter
  ---
  ---@param head Node # The head node of a node list.
  ---@param is_display boolean
  ---
  ---@return boolean
  linebreak_filter = function(head, is_display)
    local cb = 'linebreak_filter'
    local before, after = template.get_print_position(cb)
    local retval = true

    if before then
      template.callback(cb, {is_display = is_display}, before)
      tree.analyze_callback(head)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        retval = orig_callbacks[cb](head, is_display)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {is_display = is_display}, after)
      tree.analyze_callback(head)
    end

    return retval
  end,

  ---@function callbacks.append_to_vlist_filter
  ---
  ---@param box Node
  ---@param locationcode string
  ---@param prevdepth number
  ---@param mirrored boolean
  ---
  ---@return Node
  ---@return number
  append_to_vlist_filter = function(box, locationcode, prevdepth, mirrored)
    local cb = 'append_to_vlist_filter'
    local before, after = template.get_print_position(cb)

    if before then
      template.callback(cb, {locationcode = locationcode,
                             prevdepth = prevdepth,
                             mirrored = mirrored}, before)
      tree.analyze_callback(box)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        box, prevdepth = orig_callbacks[cb](box, locationcode,
                                            prevdepth, mirrored)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {locationcode = locationcode,
                             prevdepth = prevdepth,
                             mirrored = mirrored}, after)
      tree.analyze_callback(box)
    end

    return box, prevdepth
  end,

  ---@function callbacks.post_linebreak_filter
  ---
  ---@param head Node # The head node of a node list.
  ---@param groupcode string
  ---@param where string
  ---
  ---@return boolean
  post_linebreak_filter = function(head, groupcode, where)
    local cb = 'post_linebreak_filter'
    local before, after = template.get_print_position(where)
    local retval = true

    if before then
      template.callback(cb, {groupcode = groupcode}, before)
      tree.analyze_callback(head)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        retval = orig_callbacks[cb](head, groupcode)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {groupcode = groupcode}, after)
      tree.analyze_callback(head)
    end

    return retval
  end,

  ---@function callbacks.hpack_filter
  ---
  ---@param head Node # The head node of a node list.
  ---@param groupcode string
  ---@param size number
  ---@param packtype string
  ---@param direction string
  ---@param attributelist Node
  ---@param where string
  ---
  ---@return boolean
  hpack_filter = function(head, groupcode, size, packtype,
                          direction, attributelist, where)
    local cb = 'hpack_filter'
    local before, after = template.get_print_position(where)
    local retval = true

    if before then
      template.callback(cb, {groupcode = groupcode,
                             size = size,
                             packtype = packtype,
                             direction = direction,
                             attributelist = attributelist}, before)
      tree.analyze_callback(head)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        retval = orig_callbacks[cb](head, groupcode, size,
                                    packtype, direction,
                                    attributelist)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {groupcode = groupcode,
                             size = size,
                             packtype = packtype,
                             direction = direction,
                             attributelist = attributelist}, after)
      tree.analyze_callback(head)
    end

    return retval
  end,

  ---@function callbacks.vpack_filter
  ---
  ---@param head Node # The head node of a node list.
  ---@param groupcode string
  ---@param size number
  ---@param packtype string
  ---@param maxdepth number
  ---@param direction string
  ---@param attributelist Node
  ---@param where string
  ---
  ---@return boolean
  vpack_filter = function(head, groupcode, size, packtype,
                          maxdepth, direction, attributelist, where)
    local cb = 'vpack_filter'
    local before, after = template.get_print_position(where)
    local retval = true

    if before then
      template.callback(cb, {groupcode = groupcode,
                             size = size,
                             packtype = packtype,
                             maxdepth = template.length(maxdepth),
                             direction = direction,
                             attributelist = attributelist}, before)
      tree.analyze_callback(head)
      tree.analyze_callback(attributelist)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        retval = orig_callbacks[cb](head, groupcode, size, packtype,
                                    maxdepth, direction,
                                    attributelist)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {groupcode = groupcode,
                             size = size,
                             packtype = packtype,
                             maxdepth = template.length(maxdepth),
                             direction = direction,
                             attributelist = attributelist}, after)
      tree.analyze_callback(head)
      tree.analyze_callback(attributelist)
    end

    return retval
  end,

  ---@function callbacks.hpack_quality
  ---
  ---@param incident string
  ---@param detail number
  ---@param head Node # The head node of a node list.
  ---@param first number
  ---@param last number
  ---
  ---@return Node
  hpack_quality = function(incident, detail, head, first, last)
    local cb = 'hpack_quality'
    local before, after = template.get_print_position(cb)
    local retval = nil

    if before then
      template.callback(cb, {incident = incident,
                             detail = detail,
                             first = first,
                             last = last}, before)
      tree.analyze_callback(head)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        retval = orig_callbacks[cb](incident, detail, head, first, last)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {incident = incident,
                             detail = detail,
                             first = first,
                             last = last}, after)
      tree.analyze_callback(head)
    end

    return retval
  end,

  ---@function callbacks.vpack_quality
  ---
  ---@param incident string
  ---@param detail number
  ---@param head Node # The head node of a node list.
  ---@param first number
  ---@param last number
  vpack_quality = function(incident, detail, head, first, last)
    local cb = 'vpack_quality'
    local before, after = template.get_print_position(cb)

    if before then
      template.callback(cb, {incident = incident,
                             detail = detail,
                             first = first,
                             last = last}, before)
      tree.analyze_callback(head)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        orig_callbacks[cb](incident, detail, head, first, last)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {incident = incident,
                             detail = detail,
                             first = first,
                             last = last}, after)
      tree.analyze_callback(head)
    end
  end,

  ---@function callbacks.process_rule
  ---
  ---@param head Node # The head node of a node list.
  ---@param width number
  ---@param height number
  process_rule = function(head, width, height)
    local cb = 'process_rule'
    local before, after = template.get_print_position(cb)

    if before then
      template.callback(cb, {width = width, height = height}, before)
      tree.analyze_callback(head)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        orig_callbacks[cb](head, width, height)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {width = width, height = height}, after)
      tree.analyze_callback(head)
    end
  end,

  ---@function callbacks.pre_output_filter
  ---
  ---@param head Node # The head node of a node list.
  ---@param groupcode string
  ---@param size number
  ---@param packtype string
  ---@param maxdepth number
  ---@param direction string
  ---@param where string
  ---
  ---@return boolean
  pre_output_filter = function(head, groupcode, size, packtype,
                               maxdepth, direction, where)
    local cb = 'pre_output_filter'
    local before, after = template.get_print_position(where)
    local retval = true

    if before then
      template.callback(cb, {groupcode = groupcode,
                             size = size,
                             packtype = packtype,
                             maxdepth = maxdepth,
                             direction = direction}, before)
      tree.analyze_callback(head)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        retval = orig_callbacks[cb](head, groupcode, size,
                                    packtype, maxdepth,
                                    direction)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {groupcode = groupcode,
                             size = size,
                             packtype = packtype,
                             maxdepth = maxdepth,
                             direction = direction}, after)
      tree.analyze_callback(head)
    end

    return retval
  end,

  ---@function callbacks.hyphenate
  ---
  ---@param head Node # The head node of a node list.
  ---@param tail Node
  ---@param where string
  hyphenate = function(head, tail, where)
    local cb = 'hyphenate'
    local before, after = template.get_print_position(where)

    if before then
      template.callback(cb, nil, before)
      nodetree_print('head:' .. format.new_line())
      tree.analyze_callback(head)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        orig_callbacks[cb](head, tail)
      end
    else
      template.no_callback(cb, true)
      lang.hyphenate(head, tail)
    end
    if after then
      template.callback(cb, nil, after)
      nodetree_print('head:' .. format.new_line())
      tree.analyze_callback(head)
    end
  end,

  ---@function callbacks.ligaturing
  ---
  ---@param head Node # The head node of a node list.
  ---@param tail Node
  ---@param where string
  ligaturing = function(head, tail, where)
    local cb = 'ligaturing'
    local before, after = template.get_print_position(where)

    if before then
      template.callback(cb, nil, before)
      nodetree_print('head:' .. format.new_line())
      tree.analyze_callback(head)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        orig_callbacks[cb](head, tail)
      end
    else
      template.no_callback(cb, true)
      node.ligaturing(head, tail)
    end
    if after then
      template.callback(cb, nil, after)
      nodetree_print('head:' .. format.new_line())
      tree.analyze_callback(head)
    end
  end,

  ---@function callbacks.kerning
  ---
  ---@param head Node # The head node of a node list.
  ---@param tail Node
  ---@param where string
  kerning = function(head, tail, where)
    local cb = 'kerning'
    local before, after = template.get_print_position(where)

    if before then
      template.callback(cb, nil, before)
      nodetree_print('head:' .. format.new_line())
      tree.analyze_callback(head)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        orig_callbacks[cb](head, tail)
      end
    else
      template.no_callback(cb, true)
      node.kerning(head, tail)
    end
    if after then
      template.callback(cb, nil, after)
      nodetree_print('head:' .. format.new_line())
      tree.analyze_callback(head)
    end
  end,

  ---@function callbacks.insert_local_par
  ---
  ---@param local_par Node
  ---@param location string
  ---@param where string
  insert_local_par = function(local_par, location, where)
    local cb = 'insert_local_par'
    local before, after = template.get_print_position(where)

    if before then
      template.callback(cb, {location = location}, before)
      tree.analyze_callback(local_par)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        orig_callbacks[cb](local_par, location)
      end
    else
      template.no_callback(cb)
    end
    if after then
      template.callback(cb, {location = location}, after)
      tree.analyze_callback(local_par)
    end
  end,

  ---@function callbacks.mlist_to_hlist
  ---
  ---@param head Node # The head node of a node list.
  ---@param display_type string
  ---@param need_penalties boolean
  ---
  ---@return Node
  mlist_to_hlist = function(head, display_type, need_penalties)
    local cb = 'mlist_to_hlist'
    local before, after = template.get_print_position(cb)
    local retval

    if before then
      template.callback(cb, {display_type = display_type,
                             need_penalties = need_penalties}, before)
      tree.analyze_callback(head)
    end
    if orig_callbacks[cb] then
      if orig_callbacks[cb] ~= '' then
        retval = orig_callbacks[cb](head, display_type, need_penalties)
      end
    else
      template.no_callback(cb, true)
      retval = node.mlist_to_hlist(head, display_type, need_penalties)
    end
    if after then
      template.callback(cb, {display_type = display_type,
                             need_penalties = need_penalties}, after)
      tree.analyze_callback(head)
    end

    return retval
  end
}

-- The actual callback functions. The `*_before` and `*_after`
-- variants are needed for luatexbase. For 'exclusive' callbacks we
-- directly use the corresponding functions from the
-- `callback_wrappers` table.

local callbacks = {
  contribute_filter = function(extrainfo)
    callback_wrappers.contribute_filter(extrainfo, 'contribute_filter')
  end,
  contribute_filter_before = function(extrainfo)
    callback_wrappers.contribute_filter(extrainfo, 'before')
  end,
  contribute_filter_after = function(extrainfo)
    callback_wrappers.contribute_filter(extrainfo, 'after')
  end,

  buildpage_filter = function(extrainfo)
    callback_wrappers.buildpage_filter(extrainfo, 'buildpage_filter')
  end,
  buildpage_filter_before = function(extrainfo)
    callback_wrappers.buildpage_filter(extrainfo, 'before')
  end,
  buildpage_filter_after = function(extrainfo)
    callback_wrappers.buildpage_filter(extrainfo, 'after')
  end,

  build_page_insert = callback_wrappers.build_page_insert,

  pre_linebreak_filter = function(head, groupcode)
    return callback_wrappers.pre_linebreak_filter(head, groupcode,
                                                  'pre_linebreak_filter')
  end,
  pre_linebreak_filter_before = function(head, groupcode)
    return callback_wrappers.pre_linebreak_filter(head, groupcode, 'before')
  end,
  pre_linebreak_filter_after = function(head, groupcode)
    return callback_wrappers.pre_linebreak_filter(head, groupcode, 'after')
  end,

  linebreak_filter = callback_wrappers.linebreak_filter,
  append_to_vlist_filter = callback_wrappers.append_to_vlist_filter,

  post_linebreak_filter = function(head, groupcode)
    return callback_wrappers.post_linebreak_filter(head, groupcode,
                                                   'post_linebreak_filter')
  end,
  post_linebreak_filter_before = function(head, groupcode)
    return callback_wrappers.post_linebreak_filter(head, groupcode, 'before')
  end,
  post_linebreak_filter_after = function(head, groupcode)
    return callback_wrappers.post_linebreak_filter(head, groupcode, 'after')
  end,

  hpack_filter = function(head, groupcode, size, packtype,
                          direction, attributelist)
    return callback_wrappers.hpack_filter(head, groupcode, size, packtype,
                                          direction, attributelist,
                                          'hpack_filter')
  end,
  hpack_filter_before = function(head, groupcode, size, packtype,
                                 direction, attributelist)
    return callback_wrappers.hpack_filter(head, groupcode, size, packtype,
                                          direction, attributelist, 'before')
  end,
  hpack_filter_after = function(head, groupcode, size, packtype,
                                direction, attributelist)
    return callback_wrappers.hpack_filter(head, groupcode, size, packtype,
                                          direction, attributelist, 'after')
  end,

  vpack_filter = function(head, groupcode, size, packtype,
                          maxdepth, direction, attributelist)
    return callback_wrappers.vpack_filter(head, groupcode, size, packtype,
                                          maxdepth, direction, attributelist,
                                          'vpack_filter')
  end,
  vpack_filter_before = function(head, groupcode, size, packtype,
                                 maxdepth, direction, attributelist)
    return callback_wrappers.vpack_filter(head, groupcode, size, packtype,
                                          maxdepth, direction, attributelist,
                                          'before')
  end,
  vpack_filter_after = function(head, groupcode, size, packtype,
                                maxdepth, direction, attributelist)
    callback_wrappers.vpack_filter(head, groupcode, size, packtype,
                                   maxdepth, direction, attributelist,
                                   'after')
  end,

  hpack_quality = callback_wrappers.hpack_quality,
  vpack_quality = callback_wrappers.vpack_quality,
  process_rule = callback_wrappers.process_rule,

  pre_output_filter = function(head, groupcode, size, packtype,
                               maxdepth, direction)
    return callback_wrappers.pre_output_filter(head, groupcode, size,
                                               packtype, maxdepth, direction,
                                               'pre_output_filter')
  end,
  pre_output_filter_before = function(head, groupcode, size, packtype,
                                      maxdepth, direction)
    return callback_wrappers.pre_output_filter(head, groupcode, size,
                                               packtype, maxdepth, direction,
                                               'before')
  end,
  pre_output_filter_after = function(head, groupcode, size, packtype,
                                     maxdepth, direction)
    return callback_wrappers.pre_output_filter(head, groupcode, size,
                                               packtype, maxdepth, direction,
                                               'after')
  end,

  hyphenate = function(head, tail)
    callback_wrappers.hyphenate(head, tail, 'hyphenate')
  end,
  hyphenate_before = function(head, tail)
    callback_wrappers.hyphenate(head, tail, 'before')
  end,
  hyphenate_after = function(head, tail)
    callback_wrappers.hyphenate(head, tail, 'after')
  end,

  ligaturing = function(head, tail)
    callback_wrappers.ligaturing(head, tail, 'ligaturing')
  end,
  ligaturing_before = function(head, tail)
    callback_wrappers.ligaturing(head, tail, 'before')
  end,
  ligaturing_after = function(head, tail)
    callback_wrappers.ligaturing(head, tail, 'after')
  end,

  kerning = function(head, tail)
    callback_wrappers.kerning(head, tail, 'kerning')
  end,
  kerning_before = function(head, tail)
    callback_wrappers.kerning(head, tail, 'before')
  end,
  kerning_after = function(head, tail)
    callback_wrappers.kerning(head, tail, 'after')
  end,

  insert_local_par = function(head, tail)
    callback_wrappers.insert_local_par(head, tail, 'insert_local_par')
  end,
  insert_local_par_before = function(head, tail)
    callback_wrappers.insert_local_par(head, tail, 'before')
  end,
  insert_local_par_after = function(head, tail)
    callback_wrappers.insert_local_par(head, tail, 'after')
  end,

  mlist_to_hlist = callback_wrappers.mlist_to_hlist
}

--- Messages, options
---
---@section messages

--- Emit a warning or error message.
---
---This works for plain TeX, Texinfo, and LaTeX (for plain TeX and
---Texinfo we make the message look identical to the LaTeX case).
---Note that a full stop gets appended to `what`.
---
---@param why string # `'error'` or `'warning'`.
---@param where string # In which package the error happened.
---@param what string # The warning message to emit.
---@param help? string # Additional help text for errors.
local function message(why, where, what, help)
  local msg

  what = string.gsub(what, '\n', '\\MessageBreak ')

  if why == 'error' then
    if not help then
      help = ''
    end

    msg = {
      '\\ifx\\mbox\\undefined',
      '  \\errhelp{' .. help .. '}%',
      '  \\begingroup',
      '    \\newlinechar`\\^^J%',
      '    \\def\\MessageBreak{^^J(' .. where .. ')' .. string.rep('\\space', 16) .. '}%',
      '    \\errmessage{Package ' .. where .. ' Error: ' .. what .. '}%',
      '  \\endgroup',
      '\\else',
      '  \\PackageError{' .. where .. '}{' .. what .. '}{' .. help .. '}%',
      '\\fi'
    }
  else
    msg = {
      '\\ifx\\mbox\\undefined',
      '  \\begingroup',
      '    \\newlinechar`\\^^J%',
      '    \\def\\MessageBreak{^^J(' .. where .. ')' .. string.rep('\\space', 16) .. '}%',
      '    \\message{Package ' .. where .. ' Warning: ' .. what .. '}%',
      '  \\endgroup',
      '\\else',
      '  \\PackageWarning{' .. where .. '}{' .. what .. '}%',
      '\\fi'
    }
  end

  if tex.escapechar == utf8.codepoint('@') then
    table.insert(msg, 1, '@tex')
    table.insert(msg, '@end tex')
  end

  tex.print(msg)
end

--- Set a single-option key-value pair.
---
---@param key string # The key of the option pair.
---@param value number|string # The value of the option pair.
local function set_option(key, value)
  if not default_options[key] then
    message(
      'warning',
      'nodetree',
      "Ignoring unknown option '" .. key .. "'"
    )
    return
  end
  if not options then
    options = {}
  end
  if key == 'verbosity' then
    options[key] = tonumber(value) or default_options.verbosity
  elseif key == 'decimalplaces' then
    options[key] = tonumber(value) or default_options.decimalplaces
  elseif key == 'firstline' then
    options[key] = tonumber(value) or default_options.firstline
  elseif key == 'lastline' then
    options[key] = tonumber(value) or default_options.lastline
  else
    options[key] = value
  end
end

--- Set multiple key-value option pairs using a table.
---
---@param opts table # Options.
local function set_options(opts)
  if not options then
    options = {}
  end
  for key, value in pairs(opts) do
    set_option(key, value)
  end
end

--- Callback management
---
---@section callback_management

---
---@param what? string|'before'|'after' # The name of a callback, or either the string `before` or `after`.
---
---@return 'before'|nil # 'before'` or `nil`.
---@return 'after'|nil # `'after'` or `nil`.
function template.get_print_position(what)
  local before, after

  if what == 'before' then
    before = what
    after = nil
  elseif what == 'after' then
    before = nil
    after = what
  else
    before = print_positions[what][1]
    after = print_positions[what][2]
  end

  return before, after
end

---
---@param name string
---@param internal? string|boolean
function template.no_callback(name, internal)
  local more = ''
  if internal == true then
    more = ',' .. format.new_line() ..
      ' LuaTeX uses internal function instead'
  end
  nodetree_print(
    format.new_line() ..
    "<no registered function for '" ..
    format.underscore(name) .. "' callback" .. more .. ">")
end

--- Check whether the given callback name exists.
---
---Throw an error if it doesn’t.
---
---@param callback_name string # The name of a callback to check.
---
---@return string # The unchanged input of the function.
local function check_callback_name(callback_name)
  local info = callback.list()
  if info[callback_name] == nil then
    message(
      'error',
      'nodetree',
      'Unknown callback name or callback alias\n'
      .. "'" .. callback_name .. "'"
    )
  end
  return callback_name
end

--- Get the real callback name from an alias string.
---
---@param alias string # The alias of a callback name or the callback name itself.
---
---@return string # The real callback name.
local function get_callback_name(alias)
  local callback_name
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
---
--- Doing this for plain TeX is simple; we have access to LuaTeX's
--- base function `callback.register` and thus can easily add our
--- callback wrapper, which in turn calls nodetree's functions at the
--- very beginning and/or at the very end.
---
--- Enter LaTeX. It comes with its own callback management that can
--- register multiple callbacks, also taking care of the calling
--- order. Unfortunately, however, it is also more restrictive: for
--- example, some callbacks like `linebreak_filter` are tagged as
--- 'exclusive', only accepting a single callback. While this makes
--- sense for the end user, it complicates the situation for nodetree
--- to install its non-intrusive, observing-only callbacks.
---
--- We thus take the following route.
---
--- * If there is no function for callback `<foo>` installed, register
---   `callbacks.<foo>`.
---
--- * If there is a (single) function for callback `<foo>` of type
---   three ('exclusive'), remove it, wrap it into `callbacks.<foo>`
---   (via `orig_callbacks`) and install `callbacks.<foo>`.
---
--- * Otherwise register `callbacks.<foo>_{before,after}` as
---   necessary.
---
---@param cb string # The name of a callback.
local function register_callback(cb)
  if luatexbase then
    local descriptions = luatexbase.callback_descriptions(cb)

    if #descriptions == 0 then
      -- No callback installed. If there is no default action
      -- (according to the LuaTeX manual), use only `before`, ignoring
      -- the position requested by the user.
      if not callback_has_default_action[cb] then
        print_positions[cb] = { 'before', nil }
      end
      luatexbase.add_to_callback(cb, callbacks[cb], 'nodetree')
    elseif luatexbase.callbacktypes[cb] == 3 then
      -- A single, 'exclusive' callback.
      orig_callbacks[cb], orig_descriptions[cb] =
        luatexbase.remove_from_callback(cb, descriptions[1])
      luatexbase.add_to_callback(cb, callbacks[cb], 'nodetree')
    else
      -- All other callback types.
      local funcs = {}
      local descr = {}
      local before, after = template.get_print_position(cb)

      -- XXX Is this correct for 'reverselist' callback type?

      -- This makes the callback wrapper call neither the old nor the
      -- new function.
      orig_callbacks[cb] = ''

      for i, description in ipairs(descriptions) do
        funcs[i], descr[i] = luatexbase.remove_from_callback(cb, description)
      end

      if before then
        luatexbase.add_to_callback(cb, callbacks[cb .. '_before'],
                                   'nodetree before')
      end
      for i, _ in ipairs(funcs) do
        luatexbase.add_to_callback(cb, funcs[i], descr[i])
      end
      if after then
        luatexbase.add_to_callback(cb, callbacks[cb .. '_after'],
                                   'nodetree after')
      end
    end
  else
    orig_callbacks[cb] = callback.find(cb)
    callback.register(cb, callbacks[cb])
  end
end

--- Unregister a callback.
---
--- We follow the same logic as with `register_callback`.
---
---@param cb string # The name of a callback.
local function unregister_callback(cb)
  if luatexbase then
    local descriptions = luatexbase.callback_descriptions(cb)

    if #descriptions == 0 then
      return
    elseif #descriptions == 1 then
      luatexbase.remove_from_callback(cb, 'nodetree')
      if orig_callbacks[cb] then
        luatexbase.add_to_callback(cb,
                                   orig_callbacks[cb],
                                   orig_descriptions[cb])
      end
      orig_callbacks[cb] = nil
      orig_descriptions[cb] = nil
    else
      local funcs = {}
      local descr = {}

      local i = 1
      for _, description in ipairs(descriptions) do
        if description == 'nodetree before' or
          description == 'nodetree after' then
          luatexbase.remove_from_callback(cb, description)
        else
          funcs[i], descr[i] = luatexbase.remove_from_callback(cb,
                                                               description)
          i = i + 1
        end
      end

      for n, _ in ipairs(funcs) do
        luatexbase.add_to_callback(cb, funcs[n], descr[n])
      end
    end
  else
    callback.register(cb, nil)
    callback.register(cb, orig_callbacks[cb])
  end
end

--- Exported functions.
---
---@section export

local export = {
  set_option = set_option,
  set_options = set_options,

  ---@function export.register_callbacks
  register_callbacks = function()
    if options.channel == 'log' or options.channel == 'tex' then
      -- nt = nodetree
      -- jobname.nttex
      -- jobname.ntlog
      local file_name = tex.jobname .. '.nt' .. options.channel
      io.open(file_name, 'w'):close() -- Clear former content.
      output_file = io.open(file_name, 'a')
    end

    -- Split string at ','.
    for alias in string.gmatch(options.callback, '([^,]+)') do
      -- Trim whitespace.
      alias = string.gsub(alias, '^%s*(.-)%s*$', '%1')

      -- Check where to position nodetree's inspection callback(s).
      local before, after
      if string.sub(alias, 1, 1) == ':' then
        before = 'before'
        alias = string.sub(alias, 2, -1)
      end
      if string.sub(alias, -1, -1) == ':' then
        after = 'after'
        alias = string.sub(alias, 1, -2)
      end
      if not before and not after then
        before = 'before'
      end
      local name = get_callback_name(alias)
      print_positions[name] = {before, after}
      register_callback(name)
    end
  end,

  ---@function export.unregister_callbacks
  unregister_callbacks = function()
    for alias in string.gmatch(options.callback, '([^,]+)') do
      -- Split string at ',', then trim whitespace. For symmetry with
      -- `register_callbacks`, also remove a leading and/or trailing
      -- ':' character.
      unregister_callback(
        get_callback_name(string.gsub(alias, '^%s*:?(.-):?%s*$', '%1'))
      )
    end
  end,

  --- Compile a TeX snippet.
  --
  -- Write some TeX snippets into a temporary LaTeX file, compile this
  -- file using `latexmk`, read the generated `*.nttex` file, and
  -- return its content.
  --
  ---@function export.compile_include
  --
  ---@param tex_markup string
  compile_include = function(tex_markup)
    -- Generate a subfolder for all tempory files: _nodetree-jobname.
    local parent_path = lfs.currentdir() .. '/' .. '_nodetree-' .. tex.jobname
    lfs.mkdir(parent_path)

    -- Generate the temporary LuaTeX or LuaLaTeX file.
    example_counter = example_counter + 1
    local filename_tex = example_counter .. '.tex'
    local absolute_path_tex = parent_path .. '/' .. filename_tex
    output_file = io.open(absolute_path_tex, 'w')

    local format_option = function(key, value)
      return '\\NodetreeSetOption[' .. key .. ']{' .. value .. '}' .. '\n'
    end

    -- Process the options.
    local option_lines =
      format_option('channel', 'tex') ..
      format_option('verbosity', options.verbosity) ..
      format_option('unit', options.unit) ..
      format_option('decimalplaces', options.decimalplaces) ..
      '\\NodetreeUnregisterCallback{post_linebreak_filter}'  .. '\n' ..
      '\\NodetreeRegisterCallback{' .. options.callback .. '}'

    local prefix = '%!TEX program = lualatex\n' ..
                  '\\documentclass{article}\n' ..
                  '\\usepackage{nodetree}\n' ..
                  option_lines .. '\n' ..
                  '\\begin{document}\n'
    local suffix = '\n\\end{document}'
    if output_file ~= nil then
      output_file:write(prefix .. tex_markup .. suffix)
      output_file:close()
    end

    -- Compile the temporary LuaTeX or LuaLaTeX file.
    os.spawn({ 'latexmk', '-cd', '-pdflua', absolute_path_tex })
    local include_file = assert(io.open(parent_path .. '/' .. example_counter .. '.nttex', 'r'))
    local include_content = include_file:read('*all')
    include_file:close()
    -- To make the newline character be handled properly by the TeX engine
    -- it would be necessary to set up its correct catcode. However, it is
    -- simpler to just replace all newlines with '{}'.
    include_content = include_content:gsub('[\r\n]', '{}')
    tex.print(include_content)
  end,

  --- Check for `\--shell-escape` within a command or environment.
  ---
  ---@function export.check_shell_escape
  ---
  ---@param what string # The name of the command or environment.
  ---@param is_command boolean # Set if `what` is a command.
  check_shell_escape = function(what, is_command)
    local info = status.list()
    if info ~= nil and info.shell_escape ~= 1 then
      local typ, stuff
      if is_command == true then
        typ = 'command'
        stuff = 'argument'
      else
        typ = 'environment'
        stuff = 'contents'
      end
      message(
        'error',
        'nodetree-embed',
        what .. ' needs option --shell-escape',
        "You must process this document with 'lualatex --shell-escape ...'\n"
        .. "so that 'latexmk' can be executed to generate the nodetree view\n"
        .. 'for the ' .. stuff .. ' of this ' .. typ .. '.'
      )
    end
  end,

  --- Print a node tree.
  ---
  ---@function export.print
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

  --- Format a scaled point value as a formatted string.
  --
  ---@function export.format_dim
  ---
  ---@param sp number # A scaled point value.
  --
  ---@return string
  format_dim = function(sp)
    return template.length(sp)
  end,

  --- Get a default option that is not changed.
  ---
  ---@function export.get_default_option
  ---
  ---@param key string # The key of the option.
  --
  ---@return string|number|boolean
  get_default_option = function(key)
    return default_options[key]
  end,

  --- Push current options.
  ---
  ---@function export.push_options
  push_options = function()
    prev_options[option_level] = {}
    for k, v in pairs(options) do
      prev_options[option_level][k] = v
    end
    option_level = option_level + 1
  end,

  --- Pop previous options.
  ---
  ---@function export.pop_options
  pop_options = function()
    if option_level > 0 then
      prev_options[option_level] = nil
      option_level = option_level - 1
      for k, v in pairs(prev_options[option_level]) do
        options[k] = v
      end
    end
  end,

  --- Read a LaTeX input file and emit it immediately, obeying options
  --- `firstline` and `lastline`.
  ---
  ---@function export.input
  ---
  ---@param filename string
  input = function(filename)
    local file = assert(io.open(filename, 'r'))
    local lines_in = {}
    for line in file:lines() do
      table.insert(lines_in, line)
    end

    local firstline = options.firstline
    local lastline = options.lastline

    -- Handle negative line numbers.
    if firstline < 0 then
      firstline = #lines_in + 1 + firstline
    elseif firstline == 0 then
      firstline = 1
    end
    if lastline < 0 then
      lastline = #lines_in + 1 + lastline
    elseif lastline == 0 then
      lastline = 1
    end

    -- Clamp values.
    if firstline < 1 then
      firstline = 1
    elseif firstline > #lines_in then
      firstline = #lines_in
    end
    if lastline < 1 then
      lastline = 1
    elseif lastline > #lines_in then
      lastline = #lines_in
    end

    if firstline > lastline then
      local tmp = firstline
      firstline = lastline
      lastline = tmp
    end

    local lines_out = {}
    for i, line in ipairs(lines_in) do
      if firstline <= i and i <= lastline then
        table.insert(lines_out, line)
      end
    end

    tex.print(lines_out)
  end
}

--- Set to `export.print`.
export.analyze = export.print

return export
