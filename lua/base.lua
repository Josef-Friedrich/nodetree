colors = require("ansicolors")
template = require("template")
nodex = require("nodex")

local base = {}

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

return base