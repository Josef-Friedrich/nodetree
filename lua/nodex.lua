
------------------------------------------------------------------------
-- nodex ; node extended
------------------------------------------------------------------------
local nodex = {}

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

return nodex