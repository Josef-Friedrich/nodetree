
------------------------------------------------------------------------
-- string
------------------------------------------------------------------------

str = {}

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

fmt = {}

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


function get_callback(key)
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