--- Nodetree uses [LDoc](https://github.com/stevedonovan/ldoc) for the
--  source code documentation. The supported tags are described on in
--  the [wiki](https://github.com/stevedonovan/LDoc/wiki).

if not modules then modules = { } end modules ['nodetree'] = {
  version   = '1.2',
  comment   = 'nodetree',
  author    = 'Josef Friedrich',
  copyright = 'Josef Friedrich',
  license   = 'The LaTeX Project Public License Version 1.3c 2008-05-04'
}

local node_extended = {}

local template = {}

local tree = {}

-- Nodes in Lua\TeX{} are connected. The nodetree view distinguishs
-- between the `list` and `field` connections.

-- \begin{itemize}
--  \item `list`: Nodes, which are double connected by `next` and
--        `previous` fields.
--  \item `field`: Connections to nodes by other fields than `next` and
--        `previous` fields, e. g. `head`, `pre`.
-- \end{itemize}

-- The lua table named `tree.state` holds state values of the current
-- tree item.

-- `tree.state`:
-- \begin{itemize}
-- * `1` (level):
-- \begin{itemize}
-- * `list`: `continue`
-- * `field`: `stop`
-- \end{itemize}
-- * `2`:
-- \begin{itemize}
-- * `list`: `continue`
-- * `field`: `stop`
-- \end{itemize}
-- \end{itemize}
tree.state = {}
-- A counter for the compiled TeX examples. Some TeX code snippets
-- a written into file, wrapped with some TeX boilerplate code.
-- This written files are compiled.
local example_counter = 0

local export = {}
-- The default options
local options = {
  verbosity = 1,
  callback = 'postlinebreak',
  engine = 'luatex',
  color = 'colored',
  decimalplaces = 2,
  unit = 'pt',
  channel = 'term',
}
-- File descriptor
local output_file

--- Format functions.
--
-- Low level template functions.
--
-- @section format

local format = {
  ---
  -- @treturn string
  underscore = function(string)
    if options.channel == 'tex' then
      return string.gsub(string, '_', '\\_')
    else
      return string
    end
  end,

  ---
  -- @treturn string
  escape = function(string)
    if options.channel == 'tex' then
      return string.gsub(string, [[\]], [[\string\]])
    else
      return string
    end
  end,

  -- @treturn number
  number = function(number)
    local mult = 10^(options.decimalplaces or 0)
    return math.floor(number * mult + 0.5) / mult
  end,

  ---
  -- @treturn string
  whitespace = function(count)
    local whitespace, out = '', ''
    if options.channel == 'tex' then
      whitespace = '\\hspace{0.5em}'
    else
      whitespace = ' '
    end
    if not count then
      count = 1
    end
    for i = 1, count do
      out = out .. whitespace
    end
    return out
  end,

  ---
  -- @treturn string
  color_code = function(code)
    return string.char(27) .. '[' .. tostring(code) .. 'm'
  end,

  ---
  -- @treturn string
  color_tex = function(color, mode, background)
    if not mode then mode = '' end
    return 'NT' .. color .. mode
  end,

  ---
  -- @treturn string
  node_begin = function()
    if options.channel == 'tex' then
      return '\\mbox{'
    else
      return ''
    end
  end,

  ---
  -- @treturn string
  node_end = function()
    if options.channel == 'tex' then
      return '}'
    else
      return ''
    end
  end,

  ---
  -- @treturn string
  new_line = function(count)
    local out = ''
    if not count then
      count = 1
    end
    local new_line
    if options.channel == 'tex' then
      new_line = '\\par\n'
    else
      new_line = '\n'
    end

    for i = 1, count do
      out = out .. new_line
    end
    return out
  end,

  ---
  -- @treturn string
  type_id = function(id)
    return '[' .. tostring(id) .. ']'
  end
}

--- Template functions.
-- @section template

---
-- @treturn string
function template.fill(number, order, field)
  local out
  if order ~= nil and order ~= 0 then
    if field == 'stretch' then
      out = '+'
    else
      out = '-'
    end
    return out .. string.format(
      '%gfi%s', number / 2^16,
      string.rep('l', order - 1)
    )
  else
    return template.length(number)
  end
end

---
template.node_colors = {
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
}

--
-- \href{https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters}
-- {SGR (Select Graphic Rendition) Parameters}

-- \paragraph{attributes}

-- \begin{tabular}{ll}
-- reset & 0 \\
-- clear & 0 \\
-- bright & 1 \\
-- dim & 2 \\
-- underscore & 4 \\
-- blink & 5 \\
-- reverse & 7 \\
-- hidden & 8 \\
-- \end{tabular}

-- \paragraph{foreground}

-- \begin{tabular}{ll}
-- black & 30 \\
-- red & 31 \\
-- green & 32 \\
-- yellow & 33 \\
-- blue & 34 \\
-- magenta & 35 \\
-- cyan & 36 \\
-- white & 37 \\
-- \end{tabular}

-- \paragraph{background}

-- \begin{tabular}{ll}
-- onblack & 40 \\
-- onred & 41 \\
-- ongreen & 42 \\
-- onyellow & 43 \\
-- onblue & 44 \\
-- onmagenta & 45 \\
-- oncyan & 46 \\
-- onwhite & 47 \\
-- \end{tabular}

-- @treturn string
function template.color(color, mode, background)
  if options.color ~= 'colored' then
    return ''
  end

  local out = ''
  local code = ''

  if mode == 'bright' then
    out = format.color_code(1)
  elseif mode == 'dim' then
    out = format.color_code(2)
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
  return out .. format.color_code(code)
end

---
-- @treturn string
function template.colored_string(string, color, mode, background)
  if options.channel == 'tex' then
    return '\\textcolor{' ..
      format.color_tex(color, mode, background) ..
      '}{' ..
      string ..
      '}'
  else
   return template.color(color, mode, background) .. string .. template.color('reset')
  end
end

--- Format a scaled point input value into dimension string (`12pt`,
--  `1cm`)
--
-- @tparam number input
--
-- @treturn string
function template.length (input)
  input = tonumber(input)
  input = input / tex.sp('1' .. options.unit)
  return string.format('%g%s', format.number(input), options.unit)
end

---
-- @treturn string
function template.table_inline(o)
  local tex_escape = ''
  if options.channel == 'tex' then
    tex_escape = '\\'
  end
  if type(o) == 'table' then
    local s = tex_escape .. '{ '
    for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. template.table_inline(v) .. ', '
    end
    return s .. tex_escape .. '} '
  else
    return tostring(o)
  end
end

---
-- @treturn string
function template.key_value(key, value, color)
  if type(color) ~= 'string' then
    color = 'yellow'
  end
  if options.channel == 'tex' then
    key = format.underscore(key)
  end
  local out = template.colored_string(key .. ':', color)
  if value then
    out = out .. ' ' .. value .. '; '
  end
  return out
end

---
-- @treturn string
function template.char(input)
  input = string.format('%q', unicode.utf8.char(input))
  if options.channel == 'tex' then
    input = format.escape(input)
  end
  return input
end

---
-- @treturn string
function template.type(type, id)
  local out = ''
  if options.channel == 'tex' then
    out = format.underscore(type)
  else
    out = type
  end
  out = string.upper(out)
  if options.verbosity > 1 then
    out = out .. format.type_id(id)
  end
  return template.colored_string(
    out .. format.whitespace(),
    template.node_colors[type][1],
    template.node_colors[type][2]
  )
end

---
-- @treturn string
function template.line(length)
  local out = ''
  if length == 'long' then
    out = '------------------------------------------'
  else
    out = '-----------------------'
  end
    return out .. format.new_line()
end

---
-- @treturn string
function template.callback(callback_name, variables)
  template.print(
    format.new_line(2) ..
    'Callback: ' ..
    template.colored_string(format.underscore(callback_name), 'red', '', true) ..
    format.new_line()
  )
  if variables then
    for name, value in pairs(variables) do
      if value ~= nil and value ~= '' then
        template.print(
          '- ' ..
          format.underscore(name) ..
          ': ' ..
          tostring(value) ..
          format.new_line()
        )
      end
    end
  end
  template.print(template.line('long'))
end

---
-- @treturn string
function template.branch(connection_type, connection_state, last)
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
end

---
-- @treturn string
function template.branches(level, connection_type)
  local out = ''
  for i = 1, level - 1  do
    out = out .. template.branch('list', tree.state[i]['list'], false)
    out = out .. template.branch('field', tree.state[i]['field'], false)
  end
-- Format the last branches
  if connection_type == 'list' then
    out = out .. template.branch('list', tree.state[level]['list'], true)
  else
    out = out .. template.branch('list', tree.state[level]['list'], false)
    out = out .. template.branch('field', tree.state[level]['field'], true)
  end
  return out
end

---
-- @treturn string
function template.print(text)
  if options.channel == 'log' or options.channel == 'tex' then
    output_file:write(text)
  else
    io.write(text)
  end
end


--- Extend the node library
-- @section node_extended

--- Get the ID of a node.
--
-- We have to convert the node into a string and than have to extract
-- the ID from this string using a regular expression. If you convert a
-- node into a string it looks like: `<node    nil <    172 >    nil :
-- hlist 2>`.
--
-- @tparam node n A node.
--
-- @treturn string
function node_extended.node_id(n)
  return string.gsub(tostring(n), '^<node%s+%S+%s+<%s+(%d+).*', '%1')
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
-- @treturn table
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
    glyph = {
      [0] = 'character',
      [1] = 'ligature',
      [2] = 'ghost',
      [3] = 'left',
      [4] = 'right',
    },
  }
  subtypes.whatsit = node.whatsits()
  return subtypes
end

---
-- @treturn string
function node_extended.subtype(n)
  local typ = node.type(n.id)
  local subtypes = get_node_subtypes()

  local out = ''
  if subtypes[typ] and subtypes[typ][n.subtype] then
    out = subtypes[typ][n.subtype]
    if options.verbosity > 1 then
      out = out .. format.type_id(n.subtype)
    end
    return out
  else
    return tostring(n.subtype)
  end
  assert(false)
end

--- Build the node tree.
-- @section tree

---
-- @tparam node head
-- @tparam string field
--
-- @treturn string
function tree.format_field(head, field)
  local out = ''
-- Character "0" should be printed in a tree, because in TeX fonts the
-- 0 slot usually has a symbol.
  if not head[field] or (head[field] == 0 and field ~= "char") then
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
    out = node_extended.node_id(head[field])
  elseif field == 'subtype' then
    out = format.underscore(node_extended.subtype(head))
  elseif
    field == 'width' or
    field == 'height' or
    field == 'depth' or
    field == 'kern' or
    field == 'shift' then
    out = template.length(head[field])
  elseif field == 'char' then
    out = template.char(head[field])
  elseif field == 'glue_set' then
    out = format.number(head[field])
  elseif field == 'stretch' or field == 'shrink' then
    out = template.fill(head[field], head[field .. '_order'], field)
  else
    out = tostring(head[field])
  end

  return template.key_value(field, out)
end

---
-- Attributes are key/value number pairs. They are printed as an inline
-- list. The attribute `0` with the value `0` is skipped because this
-- attribute is in every node by default.
--
-- @tparam node head
--
-- @treturn string
function tree.format_attributes(head)
  if not head then
    return ''
  end
  local out = ''
  local attr = head.next
  while attr do
    if attr.number ~= 0 or (attr.number == 0 and attr.value ~= 0) then
      out = out .. tostring(attr.number) .. '=' .. tostring(attr.value) .. ' '
    end
    attr = attr.next
  end
  return out
end

---
-- @tparam number level `level` is a integer beginning with 1.
-- @tparam number connection_type The variable `connection_type`
--   is a string, which can be either `list` or `field`.
-- @tparam connection_state `connection_state` is a string, which can
--   be either `continue` or `stop`.
function tree.set_state(level, connection_type, connection_state)
  if not tree.state[level] then
    tree.state[level] = {}
  end
  tree.state[level][connection_type] = connection_state
end

---
-- @tparam table fields
-- @tparam number level
function tree.analyze_fields(fields, level)
  local max = 0
  local connection_state = ''
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
    template.print(
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
-- @tparam node head
-- @tparam number level
function tree.analyze_node(head, level)
  local connection_state
  local out = ''
  if head.next then
    connection_state = 'continue'
  else
    connection_state = 'stop'
  end
  tree.set_state(level, 'list', connection_state)
  out = template.branches(level, 'list')
    .. template.type(node.type(head.id), head.id)
  if options.verbosity > 1 then
    out = out .. template.key_value('no', node_extended.node_id(head))
  end
-- We store the attributes output to append it to the field list.
  local attributes
-- We store fields which are nodes for later treatment.
  local fields = {}
  for field_id, field_name in pairs(node.fields(head.id, head.subtype)) do
    if field_name == 'attr' then
      attributes = tree.format_attributes(head.attr)
    elseif field_name ~= 'next' and      field_name ~= 'prev' and
      node.is_node(head[field_name]) then
      fields[field_name] = head[field_name]
    else
      out = out .. tree.format_field(head, field_name)
    end
  end
-- Append the attributes output if available
  if attributes ~= '' then
    out = out .. template.key_value('attr', attributes, 'blue')
  end

  template.print(
    format.node_begin() ..
    out ..
    format.node_end() ..
    format.new_line()
  )

  local property = node.getproperty(head)
  if property then
    template.print(
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
-- @tparam node head
-- @tparam number level
function tree.analyze_list(head, level)
  while head do
    tree.analyze_node(head, level)
    head = head.next
  end
end

---
-- @tparam node head
function tree.analyze_callback(head)
  tree.analyze_list(head, 1)
  template.print(template.line('short') .. format.new_line())
end

--- Callback wrapper.
-- @section callbacks

local callbacks = {

  ---
  -- @tparam string extrainfo
  contribute_filter = function(extrainfo)
    template.callback('contribute_filter', {extrainfo = extrainfo})
    return true
  end,

  ---
  -- @tparam string extrainfo
  buildpage_filter = function(extrainfo)
    template.callback('buildpage_filter', {extrainfo = extrainfo})
    return true
  end,

  build_page_insert = false,

  ---
  -- @tparam node head
  -- @tparam string groupcode
  pre_linebreak_filter = function(head, groupcode)
    template.callback('pre_linebreak_filter', {groupcode = groupcode})
    tree.analyze_callback(head)
    return true
  end,

  ---
  -- @tparam node head
  -- @tparam boolean is_display
  linebreak_filter = function(head, is_display)
    template.callback('linebreak_filter', {is_display = is_display})
    tree.analyze_callback(head)
    return true
  end,

  ---
  -- TODO: Fix return values, page output
  -- @tparam node box
  -- @tparam string locationcode
  -- @tparam number prevdepth
  -- @tparam boolean mirrored
  append_to_vlist_filter = function(box, locationcode, prevdepth, mirrored)
    local variables = {
      locationcode = locationcode,
      prevdepth = prevdepth,
      mirrored = mirrored,
    }
    template.callback('append_to_vlist_filter', variables)
    tree.analyze_callback(box)
    return true
  end,

  ---
  -- @tparam node head
  -- @tparam string groupcode
  post_linebreak_filter = function(head, groupcode)
    template.callback('post_linebreak_filter', {groupcode = groupcode})
    tree.analyze_callback(head)
    return true
  end,

  ---
  -- @tparam node head
  -- @tparam string groupcode
  -- @tparam number size
  -- @tparam string packtype
  -- @tparam string direction
  -- @tparam node attributelist
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
  -- @tparam node head
  -- @tparam string groupcode
  -- @tparam number size
  -- @tparam string packtype
  -- @tparam number maxdepth
  -- @tparam string direction
  -- @tparam node attributelist
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
  -- @tparam string incident
  -- @tparam number detail
  -- @tparam node head
  -- @tparam number first
  -- @tparam number last
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
  -- @tparam string incident
  -- @tparam number detail
  -- @tparam node head
  -- @tparam number first
  -- @tparam number last
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
  -- @tparam node head
  -- @tparam number width
  -- @tparam number height
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
  -- @tparam node head
  -- @tparam string groupcode
  -- @tparam number size
  -- @tparam string packtype
  -- @tparam number maxdepth
  -- @tparam string direction
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
  -- @tparam node head
  -- @tparam node tail
  hyphenate = function(head, tail)
    template.callback('hyphenate')
    template.print('head:')
    tree.analyze_callback(head)
    template.print('tail:')
    tree.analyze_callback(tail)
  end,

  ---
  -- @tparam node head
  -- @tparam node tail
  ligaturing = function(head, tail)
    template.callback('ligaturing')
    template.print('head:')
    tree.analyze_callback(head)
    template.print('tail:')
    tree.analyze_callback(tail)
  end,

  ---
  -- @tparam node head
  -- @tparam node tail
  kerning = function(head, tail)
    template.callback('kerning')
    template.print('head:')
    tree.analyze_callback(head)
    template.print('tail:')
    tree.analyze_callback(tail)
  end,

  ---
  -- @tparam node local_par
  -- @tparam string location
  insert_local_par = function(local_par, location)
    template.callback('insert_local_par', {location = location})
    tree.analyze_callback(local_par)
    return true
  end,

  ---
  -- @tparam node head
  -- @tparam string display_type
  -- @tparam boolean need_penalties
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

--- Exported functions.
-- @section export

---
function export.set_option(key, value)
  if not options then
    options = {}
  end
  if key == 'verbosity' or key == 'decimalplaces' then
    options[key] = tonumber(value)
  else
    options[key] = value
  end
end

---
-- a table.
function export.set_options(opts)
  if not options then
    options = {}
  end
  for key, value in pairs(opts) do
    export.set_option(key, value)
  end
end

---
function export.get_option(key)
  if not options then
    options = {}
  end
  if options[key] then
    return options[key]
  end
end

---
function export.get_callback_name(alias)
  if alias == 'contribute' or alias == 'contributefilter' then
    return 'contribute_filter'

  elseif alias == 'buildpage' or alias == 'buildpagefilter' then
    return 'buildpage_filter'

  elseif alias == 'preline' or alias == 'prelinebreakfilter' then
    return 'pre_linebreak_filter'

  elseif alias == 'line' or alias == 'linebreakfilter' then
    return 'linebreak_filter'

  elseif alias == 'append' or alias == 'appendtovlistfilter' then
    return 'append_to_vlist_filter'

  elseif alias == 'postline' or alias == 'postlinebreakfilter' then
    return 'post_linebreak_filter'

  elseif alias == 'hpack' or alias == 'hpackfilter' then
    return 'hpack_filter'

  elseif alias == 'vpack' or alias == 'vpackfilter' then
    return 'vpack_filter'

  elseif alias == 'hpackq' or alias == 'hpackquality' then
    return 'hpack_quality'

  elseif alias == 'vpackq' or alias == 'vpackquality' then
    return 'vpack_quality'

  elseif alias == 'process' or alias == 'processrule' then
    return 'process_rule'

  elseif alias == 'preout' or alias == 'preoutputfilter' then
    return 'pre_output_filter'

  elseif alias == 'hyph' or alias == 'hyphenate' then
    return 'hyphenate'

  elseif alias == 'liga' or alias == 'ligaturing' then
    return 'ligaturing'

  elseif alias == 'kern' or alias == 'kerning' then
   return 'kerning'

  elseif alias == 'insert' or alias == 'insertlocalpar' then
    return 'insert_local_par'

  elseif alias == 'mhlist' or alias == 'mlisttohlist' then
    return 'mlist_to_hlist'

  else
    return 'post_linebreak_filter'
  end
end

---
function export.register(cb)
  if options.engine == 'lualatex' then
    luatexbase.add_to_callback(cb, callbacks[cb], 'nodetree')
  else
    id, error = callback.register(cb, callbacks[cb])
  end
end

---
function export.register_callbacks()
  if options.channel == 'log' or options.channel == 'tex' then
    output_file = io.open(tex.jobname .. '_nodetree.' .. options.channel, 'a')
  end
  for alias in string.gmatch(options.callback, '([^,]+)') do
    export.register(export.get_callback_name(alias))
  end
end

---
function export.unregister(cb)
  if options.engine == 'lualatex' then
    luatexbase.remove_from_callback(cb, 'nodetree')
  else
    id, error = callback.register(cb, nil)
  end
end

---
function export.unregister_callbacks()
  for alias in string.gmatch(options.callback, '([^,]+)') do
    export.unregister(export.get_callback_name(alias))
  end
end

---
function export.execute()
  local c = export.get_callback()
  if options.engine == 'lualatex' then
    luatexbase.add_to_callback(c, callbacks.post_linebreak_filter, 'nodetree')
  else
    id, error = callback.register(c, callbacks.post_linebreak_filter)
  end
end

---
function export.compile_include(tex_markup)
  example_counter = example_counter + 1
  local filename_tex = tex.jobname .. '_' .. example_counter .. '_nodetree.tex'
  output_file = io.open(filename_tex, 'w')
  local prefix = '%!TEX program = lualatex\n' ..
                 '\\documentclass{article}\n' ..
                 '\\usepackage[channel=tex]{nodetree}\n' ..
                 '\\begin{document}\n'
  local suffix = '\n\\end{document}'
  output_file:write(prefix .. tex_markup .. suffix)
  output_file:close()
  local status, error = os.spawn({ 'lualatex', filename_tex })
  print(status)
  print(error)
end

---
function export.analyze(head)
  template.print(format.new_line())
  tree.analyze_list(head, 1)
end

---
function export.print(head, opts)
  if opts and type(opts) == 'table' then
    export.set_options(opts)
  end
  template.print(format.new_line())
  tree.analyze_list(head, 1)
end

---
function export.format_dim(sp)
  return template.length(sp)
end

return export
