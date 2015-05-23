-- Based on http://gist.github.com/556247

local io,string,table = io,string,table
local assert,tostring,type = assert,tostring,type
local tex,texio,node,unicode,font=tex,texio,node,unicode,font

module(..., package.seeall)

------------------------------------------------------------------------
-- string
------------------------------------------------------------------------

local str = {}

-- points
str.pt = function(input)
  return string.format("%gpt", input / 2^16)
end

-- decimal
str.d = function(input)
  return string.format("%d", input)
end

-- string
str.s = function(input)
  return string.format("%s", input)
end

-- quoted string
str.q = function(input)
  return string.format("%q", input)
end

------------------------------------------------------------------------
-- format
------------------------------------------------------------------------

local fmt = {}

-- key value
fmt.kv = function(key, value)
  return key .. ': ' .. value .. '; '
end

fmt.heading = function(text)
  return '\n' .. fmt.line() .. '% ' .. text .. fmt.line() .. '\n'
end

fmt.line = function()
  return '\n%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n'
end

------------------------------------------------------------------------
-- node
------------------------------------------------------------------------

-- Get the node id form <node    nil <    172 >    nil : hlist 2>
node.node_id = function(n)
  return string.gsub(tostring(n), "^<node%s+%S+%s+<%s+(%d+).*","%1")
end

node.subtype = function(n)
  typ = node.type(n.id)
  local subtypes = {
    hlist = {
      [0] = "unknown origin",
      "created by linebreaking",
      "explicit box command",
      "parindent",
      "alignment column or row",
      "alignment cell",
    },
    glyph = {
      [0] = "character",
      "glyph",
      "ligature",
    },
    disc  = {
      [0] = "\\discretionary",
      "\\-",
      "- (auto)",
      "h&j (simple)",
      "h&j (hard, first item)",
      "h&j (hard, second item)",
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
-- process
------------------------------------------------------------------------

local process = {}

-- Process fields which each node has.
process.base = function(n)
  local out

  out = string.upper(node.type(n.id)) .. " "

  if options.verbosity > 1 then
    out = out .. fmt.kv("id", node.node_id(n))
  end

  if options.verbosity > 2 then
    out = out .. fmt.kv("next", node.node_id(n.next))
    out = out .. fmt.kv("previous", node.node_id(n.prev))
  end

  return out
end

-- glyph
process.glyph = function(n)
  local out = process.base(n) ..
    fmt.kv("char", str.q(unicode.utf8.char(n.char))) ..
    fmt.kv("lang", str.d(n.lang)) ..
    fmt.kv("font", str.d(n.font)) ..
    fmt.kv("width", str.pt(n.width))
  if n.components then
    out = out .. analyze_nodelist(n.components)
  end

  return out
end

-- rule
process.rule = function(n)
  local out = process.base(n)

  if n.width == -1073741824 then
    out = out .. fmt.kv("width", "flexible")
  else
    out = out .. fmt.kv("width", str.pt(n.width))
  end

  if n.height == -1073741824 then
    out = out .. fmt.kv("height", "flexible")
  else
    out = out .. fmt.kv("height", str.pt(n.height))
  end

  if n.depth == -1073741824 then
    out = out .. fmt.kv("depth", "flexible")
  else
    out = out .. fmt.kv("depth", str.pt(n.depth))
  end

  return out
end

-- hlist
process.hlist = function(n)
  local out = process.base(n)

  if n.width ~= 0 then
    out = out .. fmt.kv("width", str.pt(n.width))
  end

  if n.height ~= 0 then
    out = out .. fmt.kv("height", str.pt(n.height))
  end

  if n.depth ~= 0 then
    out = out .. fmt.kv("depth", str.pt(n.depth))
  end

  if n.glue_set ~= 0 then
    out = out .. fmt.kv("glue_set", str.d(n.glue_set))
  end

  if n.glue_sign ~= 0 then
    out = out .. fmt.kv("glue_sign", str.d(n.glue_sign))
  end

  if n.glue_order ~= 0 then
    out = out .. fmt.kv("glue_order", str.d(n.glue_order))
  end

  if n.shift ~= 0 then
    out = out .. fmt.kv("shift", str.d(n.shift))
  end

  out = out

  if n.head then
    out = out .. analyze_nodelist(n.head)
  end

  return out
end

-- penalty
process.penalty = function(n)
  return process.base(n) .. fmt.kv("penalty", n.penalty)
end

-- disc
process.disc = function(n)
  local out = process.base(n)
  out = out .. fmt.kv("subtype", get_subtype(n))

  if n.pre then
    out = out .. analyze_nodelist(n.pre)
  end

  if n.post then
    out = out .. analyze_nodelist(n.post)
  end

  if n.replace then
    out = out .. analyze_nodelist(n.replace)
  end

  return out
end

-- kern
process.kern = function(n)
  return process.base(n) .. fmt.kv("kern", str.pt(n.kern))
end

-- glue
process.glue = function(n)
  local subtype = get_subtype(n)
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
  return process.base(n) .. subtype .. ": " .. spec .. ";"
end

-- whatsit colorstack
process.whatsit_colorstack = function(n)
  return process.base(n) .. "subtype: colorstack; " ..
    fmt.kv("stack", str.d(n.stack)) ..
    fmt.kv("cmd", str.s(n.cmd)) ..
    fmt.kv("data", str.s(n.data))
end


-- tostring(a_node) looks like "<node    nil <    172 >    nil : hlist 2>", so we can
-- grab the number in the middle (172 here) as a unique id. So the node
-- is named "node172"
local function get_nodename(n)
  return "\"n" .. string.gsub(tostring(n), "^<node%s+%S+%s+<%s+(%d+).*","%1") .. "\""
end

function get_subtype(n)
  typ = node.type(n.id)
  local subtypes = {
    hlist = {
      [0] = "unknown origin",
      "created by linebreaking",
      "explicit box command",
      "parindent",
      "alignment column or row",
      "alignment cell",
    },
    glyph = {
      [0] = "character",
      "glyph",
      "ligature",
    },
    disc  = {
      [0] = "\\discretionary",
      "\\-",
      "- (auto)",
      "h&j (simple)",
      "h&j (hard, first item)",
      "h&j (hard, second item)",
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

local function label(n,tab)
  local typ = node.type(n.id)
  local nodename = get_nodename(n)
  local subtype = get_subtype(n)
  local ret = string.format("name: %s; type: %s;",typ or "??",subtype or "?") .. "; "
  if tab then
    for i=1,#tab do
      if tab[i][1] then
        ret = ret .. string.format("%s: %s; ",tab[i][1],tab[i][2])
      end
    end
  end
  return format_type(typ) .. ret .. "\n"
end

local function draw_node(n,tab)
  local ret = {}
  if not tab then
    tab = {}
  end
  local nodename = get_nodename(n)
  if n.id ~= 50 then
    local attlist = n.attr
    if attlist then
      attlist = attlist.next
      while attlist do
        tab[#tab + 1] = { "", string.format("attr%d=%d",attlist.number, attlist.value) }
        attlist = attlist.next
      end
    end
  end
  ret[#ret + 1] = label(n,tab)
  return table.concat(ret)
end

local function draw_action(n)
  local ret = {}
  ret[#ret + 1] = "name: action; "
  ret[#ret + 1] = string.format("action_type: %s", tostring(n.action_type)) .. "; "
  ret[#ret + 1] = string.format("action_id: %s",tostring(n.action_id)) .. "; "
  ret[#ret + 1] = string.format("named_id: %s",tostring(n.named_id)) .. "; "
  ret[#ret + 1] = string.format("file: %s",tostring(n.file)) .. "; "
  ret[#ret + 1] = string.format("new_window: %s",tostring(n.new_window)) .. "; "
  ret[#ret + 1] = string.format("data: %s",tostring(n.data):gsub(">","\\>"):gsub("<","\\<")) .. "; "
  ret[#ret + 1] = string.format("ref_count: %s",tostring(n.ref_count)) .. "; "

  return table.concat(ret )
end

function analyze_nodelist(head)
  local ret = {}
  local typ,nodename
	while head do
	  typ = node.type(head.id)
	  nodename = get_nodename(head)

  	if typ == "hlist" then ret[#ret + 1] = process.hlist(head)

    -- vlist
    --
  	elseif typ == "vlist" then
      local tmp = {}
      if head.width ~= 0 then
        local width = string.format("width %gpt",head.width / 2^16)
        tmp[#tmp + 1] = {"width",width}
      end
      if head.height ~= 0 then
        local height= string.format("height %gpt",head.height / 2^16)
        tmp[#tmp + 1] = {"height",height}
      end
      if head.depth ~= 0 then
        local depth = string.format("depth %gpt",head.depth / 2^16)
        tmp[#tmp + 1] = {"depth",depth}
      end
      if head.glue_set ~= 0 then
        local glue_set = string.format("glue_set %d",head.glue_set)
        tmp[#tmp + 1] =  {"glue_set",glue_set}
      end
      if head.glue_sign ~= 0 then
        local glue_sign = string.format("glue_sign %d",head.glue_sign)
        tmp[#tmp + 1] ={"glue_sign",glue_sign}
      end
      if head.glue_order ~= 0 then
        local glue_order = string.format("glue_order %d",head.glue_order)
        tmp[#tmp + 1] = {"glue_order",glue_order}
      end
      if head.shift ~= 0 then
  	    local shift = string.format("shift %gpt",head.shift / 2^16)
        tmp[#tmp + 1] = {"shift",shift }
      end
      tmp[#tmp + 1] = {"head", "head"}
      ret[#ret + 1] = draw_node(head, tmp)
  	  if head.head then
  	    ret[#ret + 1] = analyze_nodelist(head.head)
  	  end


  	elseif typ == "glue" then ret[#ret + 1] = process.glue(head)
  	elseif typ == "kern" then ret[#ret + 1] = process.kern(head)
    elseif typ == "rule" then ret[#ret + 1] = process.rule(head)
    elseif typ == "penalty" then ret[#ret + 1] = process.penalty(head)
    elseif typ == "disc" then ret[#ret + 1] = process.disc(head)
  	elseif typ == "glyph" then ret[#ret + 1] = process.glyph(head)

    -- math
    --
    elseif typ == "math" then
      ret[#ret + 1] = draw_node(head, { "math", head.subtype == 0 and "on" or "off" })

    -- whatsit
    --
    elseif typ == "whatsit" and head.subtype == 7 then
      ret[#ret + 1] = draw_node(head, { { "dir", head.dir } })

    -- whatsit
    --
    elseif typ == "whatsit" and head.subtype == 16 then
      local wd  = string.format("width (pt): %gpt",  head.width / 2^16)
      local ht  = string.format("height: %gpt", head.height / 2^16)
      local dp  = string.format("depth %gpt",  head.depth / 2^16)
      local objnum = string.format("objnum %d",head.objnum)
      ret[#ret + 1] = draw_action(head.action)
      ret[#ret + 1] = draw_node(head, {{ "subtype", "pdf_start_link"}, {"width", wd},{"widthraw",head.width}, {"height" , ht}, {"depth",dp}, {"objnum", objnum}, {"action", "action"}})

    elseif typ == "whatsit" and head.subtype == 39 then ret[#ret + 1] = process.whatsit_colorstack(head)


    -- whatsit
    --
    elseif typ == "whatsit" and head.subtype == 44 then
      local uid = string.format("user_id: %s; ",tostring(head.user_id))
      local t = string.format("type: %s; ",tostring(head.type))
      local val = string.format("value: %s; ", tostring(head.value))
      ret[#ret + 1] = format_type(typ) .. "subtype: user_defined; " .. uid .. t .. val
    else
      ret[#ret + 1] = draw_node(head, { })
    end

    head = head.next
	end
  return table.concat(ret, "\n")
end

function format_type(typ)
  return string.upper(typ) .. " "
end

function nodelist_visualize(nodelist)

  local output = analyze_nodelist(nodelist)

  output = fmt.heading("BEGIN nodelist debug (Callback: " .. callback .. ")") ..
    output ..
    fmt.heading("END nodelist debug")

  texio.write(options.channel, output)
end

function get_luatex_callback(key)
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
