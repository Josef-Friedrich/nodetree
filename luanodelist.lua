
local colors = require("ansicolors")

local nodex = {}
local template = {}
local process = {}
local guided = {}
local automatic = {}
local base = {}

local options

------------------------------------------------------------------------
-- nodex ; node extended
------------------------------------------------------------------------

-- Get the node id form <node    nil <    172 >    nil : hlist 2>
function nodex.is_node(n)
  return string.find(tostring(n), "^<node%s+%S+%s+<%s+(%d+).*","%1")
end

-- Get the node id form <node    nil <    172 >    nil : hlist 2>
function nodex.node_id(n)
  return string.gsub(tostring(n), "^<node%s+%S+%s+<%s+(%d+).*","%1")
end

function nodex.subtype(n)
  typ = node.type(n.id)
  local subtypes = {
    hlist = {
      [0] = "unknown origin",
      [1] = "created by linebreaking",
      [2] = "explicit box command",
      [3] = "parindent",
      [4] = "alignment column or row",
      [5] = "alignment cell",
    },
    glyph = {
      [0] = "character",
      [1] = "glyph",
      [2] = "ligature",
    },
    disc  = {
      [0] = "\\discretionary",
      [1] = "\\-",
      [2] = "- (auto)",
      [3] = "h&j (simple)",
      [4] = "h&j (hard, first item)",
      [5] = "h&j (hard, second item)",
    },
    glue = {
      [0]   = "skip",
      [1]   = "lineskip",
      [2]   = "baselineskip",
      [3]   = "parskip",
      [4]   = "abovedisplayskip",
      [5]   = "belowdisplayskip",
      [6]   = "abovedisplayshortskip",
      [7]   = "belowdisplayshortskip",
      [8]   = "leftskip",
      [9]   = "rightskip",
      [10]  = "topskip",
      [11]  = "splittopskip",
      [12]  = "tabskip",
      [13]  = "spaceskip",
      [14]  = "xspaceskip",
      [15]  = "parfillskip",
      [16]  = "thinmuskip",
      [17]  = "medmuskip",
      [18]  = "thickmuskip",
      [100] = "leaders",
      [101] = "cleaders",
      [102] = "xleaders",
      [103] = "gleaders"
    },
  }
  subtypes.whatsit = node.whatsits()
  if subtypes[typ] then
    return subtypes[typ][n.subtype] or tostring(n.subtype)
  else
    return tostring(n.subtype)
  end
  assert(false)
end

------------------------------------------------------------------------
-- template
------------------------------------------------------------------------

function template.key_value(key,value)
  return colors.yellow .. key .. ': ' .. colors.white .. value .. '; ' .. colors.reset
end

function template.heading(text)
  return '\n' .. template.line() .. '% ' .. text .. template.line() .. '\n'
end

function template.length(input)
	input = tonumber(input)
	input = input / 2^16
	input = math.floor((input * 10^2) + 0.5) / (10^2)
  return string.format("%gpt", input)
end

function template.char(input)
  return string.format("%q", unicode.utf8.char(input))
end

function template.line()
  return '\n%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n'
end

function template.frame(text,callback)
  local begin_text = "BEGIN nodelist debug (Callback: " .. tostring(callback) .. ")"
  local end_text = "END nodelist debug"
  return template.heading(begin_text) .. text .. template.heading(end_text)
end

-- t = type
function template.type(t)
  return template.type_color(t) .. string.upper(t) .. colors.reset  .. ' '
end

-- t = type
function template.type_color(t)

  if t == 'hlist' then
    return colors.red
  elseif t == 'vlist' then
    return colors.green
  elseif t == 'rule' then
    return colors.yellow
  elseif t == 'disc' then
    return colors.bright .. colors.blue
  elseif t == 'whatsit' then
    return colors.bright .. colors.magenta
  elseif t == 'math' then
    return colors.cyan
  elseif t == 'glue' then
    return colors.bright .. colors.red
  elseif t == 'kern' then
    return colors.bright .. colors.yellow
  elseif t == 'penalty' then
    return colors.blue
  elseif t == 'glyph' then
    return colors.bright .. colors.green
  else
    return colors.magenta
  end
end

function template.print(text)
  print(text)
end

------------------------------------------------------------------------
-- process
------------------------------------------------------------------------

---
-- Process fields which each node has.
---
function process.base(n)
  local out

  out = template.type(node.type(n.id))

  out = out .. template.key_value("subtype", nodex.subtype(n))

  if options.verbosity > 1 then
    out = out .. template.key_value("id", nodex.node_id(n))
  end

  if options.verbosity > 2 then
    out = out .. template.key_value("next", nodex.node_id(n.next))
    out = out .. template.key_value("previous", nodex.node_id(n.prev))
  end

  return out
end

---
-- glyph
---
function process.glyph(n)
  local out = process.base(n) ..
    template.key_value("char", string.format("%q", unicode.utf8.char(n.char))) ..
    template.key_value("lang", string.format("%d", n.lang)) ..
    template.key_value("font", string.format("%d", n.font)) ..
    template.key_value("width", template.length(n.width))
  if n.components then
    out = out .. guided.run_through(n.components)
  end

  return out
end

---
-- vlist
---
function process.vlist(n)
  local out = process.base(n)

  if n.width ~= 0 then
    out = out .. template.key_value('width', template.length(n.width))
  end
  if n.height ~= 0 then
    out = out .. template.key_value('height', template.length(n.height))
  end
  if n.depth ~= 0 then
    out = out .. template.key_value('depth', template.length(n.depth))
  end
  if n.glue_set ~= 0 then
    out = out .. template.key_value('glue_set', n.glue_set)
  end
  if n.glue_sign ~= 0 then
    out = out .. template.key_value('glue_sign', n.glue_sign)
  end
  if n.glue_order ~= 0 then
    out = out .. template.key_value('glue_order', n.glue_order)
  end
  if n.shift ~= 0 then
    out = out .. template.key_value('shift', template.length(n.shift))
  end
  if n.head then
    out = out .. guided.run_through(n.head)
  end

  return out
end

---
-- rule
---
function process.rule(n)
  local out = process.base(n)

  if n.width == -1073741824 then
    out = out .. template.key_value("width", "flexible")
  else
    out = out .. template.key_value("width", template.length(n.width))
  end

  if n.height == -1073741824 then
    out = out .. template.key_value("height", "flexible")
  else
    out = out .. template.key_value("height", template.length(n.height))
  end

  if n.depth == -1073741824 then
    out = out .. template.key_value("depth", "flexible")
  else
    out = out .. template.key_value("depth", template.length(n.depth))
  end

  return out
end

---
-- hlist
---
function process.hlist(n)
  local out = process.base(n)

  if n.width ~= 0 then
    out = out .. template.key_value("width", template.length(n.width))
  end

  if n.height ~= 0 then
    out = out .. template.key_value("height", template.length(n.height))
  end

  if n.depth ~= 0 then
    out = out .. template.key_value("depth", template.length(n.depth))
  end

  if n.glue_set ~= 0 then
    out = out .. template.key_value("glue_set", string.format("%d", n.glue_set))
  end

  if n.glue_sign ~= 0 then
    out = out .. template.key_value("glue_sign", string.format("%d", n.glue_sign))
  end

  if n.glue_order ~= 0 then
    out = out .. template.key_value("glue_order", string.format("%d", n.glue_order))
  end

  if n.shift ~= 0 then
    out = out .. template.key_value("shift", string.format("%d", n.shift))
  end

  out = out

  if n.head then
    out = out .. guided.run_through(n.head)
  end

  return out
end

---
-- penalty
---
function process.penalty(n)
  return process.base(n) .. template.key_value("penalty", n.penalty)
end

---
-- disc
---
function process.disc(n)
  local out = process.base(n)
  out = out .. template.key_value("subtype", nodex.subtype(n))

  if n.pre then
    out = out .. guided.run_through(n.pre)
  end

  if n.post then
    out = out .. guided.run_through(n.post)
  end

  if n.replace then
    out = out .. guided.run_through(n.replace)
  end

  return out
end

---
-- kern
---
function process.kern(n)
  return process.base(n) .. template.key_value("kern", template.length(n.kern))
end

---
-- glue
---
function process.glue(n)
  local subtype = nodex.subtype(n)
  local spec = string.format("%gpt", n.spec.width / 2^16)

  if n.spec.stretch ~= 0 then
    local stretch_order, shrink_order
    if n.spec.stretch_order == 0 then
      stretch_order = string.format(" + %gpt",n.spec.stretch / 2^16)
    else
      stretch_order = string.format(" + %g fi%s", n.spec.stretch  / 2^16, string.rep("l",n.spec.stretch_order - 1))
    end
    spec = spec .. stretch_order
  end
  if n.spec.shrink ~= 0 then
    if n.spec.shrink_order == 0 then
      shrink_order = string.format(" - %gpt",n.spec.shrink / 2^16)
    else
      shrink_order = string.format(" - %g fi%s", n.spec.shrink  / 2^16, string.rep("l",n.spec.shrink_order - 1))
    end

    spec = spec .. shrink_order
  end
  return process.base(n) .. template.key_value(subtype,spec)
end

---
-- whatsit colorstack
---
function process.whatsit_colorstack(n)
  return process.base(n) ..
    template.key_value("stack", string.format("%d", n.stack)) ..
    template.key_value("cmd", string.format("%s", n.cmd)) ..
    template.key_value("data", string.format("%s", n.data))
end

---
-- whatsit action
---
function process.whatsit_action(n)
  return process.base(n) ..
    template.key_value("width",template.length(n.width)) ..
    template.key_value("height", template.length(n.height)) ..
    template.key_value("depth",  template.length(n.depth)) ..
    template.key_value("objnum",n.objnum) ..
    template.key_value("action_type", tostring(n.action_type)) ..
    template.key_value("action_id",tostring(n.action_id)) ..
    template.key_value("named_id",tostring(n.named_id)) ..
    template.key_value("file",tostring(n.file)) ..
    template.key_value("new_window",tostring(n.new_window)) ..
    template.key_value("data",tostring(n.data):gsub(">","\\>"):gsub("<","\\<")) ..
    template.key_value("ref_count",tostring(n.ref_count))
end

---
-- whatsit action
---
function process.whatsit_user_definded(n)
  local types = {
    [97] = "attribute node list",
    [100] = "number",
    [110] = "node list",
    [115] = "string",
    [116] = "token list",
  }
  return process.base(n) ..
    template.key_value("user_id",tostring(n.user_id)) ..
    template.key_value("type",types[tonumber(n.type)]) ..
    template.key_value("value",tostring(n.value))
end

---
-- whatsit dir
---
function process.whatsit_dir(n)
  return process.base(n) ..
    template.key_value("dir", n.dir)
end

---
-- math
---
function process.math(n)
  return process.base(n) ..
    template.key_value("math", n.subtype == 0 and "on" or "off")
end

------------------------------------------------------------------------
-- guided
------------------------------------------------------------------------

---
--
---
function guided.run_through(head)
  local ret = {}
  local typ,nodename
  while head do
    typ = node.type(head.id)

    if typ == "hlist" then ret[#ret + 1] = process.hlist(head)
    elseif typ == "vlist" then ret[#ret + 1] = process.vlist(head)
    elseif typ == "glue" then ret[#ret + 1] = process.glue(head)
    elseif typ == "kern" then ret[#ret + 1] = process.kern(head)
    elseif typ == "rule" then ret[#ret + 1] = process.rule(head)
    elseif typ == "penalty" then ret[#ret + 1] = process.penalty(head)
    elseif typ == "disc" then ret[#ret + 1] = process.disc(head)
    elseif typ == "glyph" then ret[#ret + 1] = process.glyph(head)
    elseif typ == "math" then ret[#ret + 1] = process.math(head)
    elseif typ == "whatsit" and head.subtype == 7 then ret[#ret + 1] = process.whatsit_dir(head)
    elseif typ == "whatsit" and head.subtype == 16 then ret[#ret + 1] = process.whatsit_action(head)
    elseif typ == "whatsit" and head.subtype == 39 then ret[#ret + 1] = process.whatsit_colorstack(head)
    elseif typ == "whatsit" and head.subtype == 44 then ret[#ret + 1] = process.whatsit_user_definded(head)
    else
      ret[#ret + 1] = automatic.analayze_node(head)
    end

    head = head.next
  end
  return table.concat(ret, "\n")
end

---
--
---
function guided.get_nodes(head)
  local out = guided.run_through(head)
  print(template.frame(out,callback))

  return head
end

------------------------------------------------------------------------
-- automatic
------------------------------------------------------------------------

---
--
-- n = node
-- f = field
---
function automatic.format_field(n, f)
  local out = ''

  if not n[f] or n[f] == 0 then
    return ''
  end

  if options.verbosity < 2 and f == 'prev' or f == 'next' or f == 'id' or f == 'attr' then
    return ''
  end

  if f == 'prev' or f == 'next' or f == 'spec' or f == 'pre' or f == 'attr' then
    out = nodex.node_id(n[f])
  elseif f == 'subtype' then
    out = nodex.subtype(n)
  elseif f == 'width' or f == 'height' or f == 'depth' then
    out = template.length(n[f])
  elseif f == 'char' then
    out = template.char(n[f])
  else
    out = tostring(n[f])
  end

  return template.key_value(f, out)
end

---
-- n = node
---
function automatic.analayze_node(n)
  local out = {}

  out = template.type(node.type(n.id)) .. ' '

  if options.verbosity > 1 then
    out = out .. template.key_value('no', nodex.node_id(n))
  end

  local tmp = {}
  fields = node.fields(n.id, n.subtype)
  for field_id,field_name in pairs(fields) do
    tmp[#tmp + 1] = automatic.format_field(n,field_name)
  end

  return out .. table.concat(tmp, "")
end

---
--
---
function automatic.run_through(head)
  local out = {}
  while head do

    if head.id == 0 or head.id == 1 then
      out[#out + 1] = automatic.run_through(head.head)
    else
      out[#out + 1] = automatic.analayze_node(head)
    end

    head = head.next
  end

  return table.concat(out, "\n")
end

---
--
---
function automatic.get_nodes(head)
  local out = automatic.run_through(head)
  template.print(out)

  return head
end

------------------------------------------------------------------------
-- base
------------------------------------------------------------------------

function base.get_callback(key)
  if key == "prelinebreak" then callback = "pre_linebreak_filter"
  elseif key == "linebreak" then callback = "linebreak_filter"
  elseif key == "postlinebreak" then callback = "post_linebreak_filter"
  elseif key == "hpack" then callback = "hpack_filter"
  elseif key == "vpack" then callback = "vpack_filter"
  elseif key == "hyphenate" then callback = "hyphenate"
  elseif key == "ligaturing" then callback = "ligaturing"
  elseif key == "kerning" then callback = "kerning"
  elseif key == "mhlist" then callback = "mlist_to_hlist"
  else callback = "post_linebreak_filter"
  end

  return callback
end

function base.get_options(localoptions)
  options = localoptions
end

function base.execute()
  if options.interface == "guided" then
    luatexbase.add_to_callback(base.get_callback(options.callback), guided.get_nodes, "guided", 1000)
  else
    luatexbase.add_to_callback(base.get_callback(options.callback), automatic.get_nodes, "automatic", 1000)
  end
end

return base
