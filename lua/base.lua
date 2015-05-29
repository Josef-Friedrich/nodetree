colors = require("ansicolors")
template = require("template")
process = require("process")
nodex = require("nodex")
guided = require("guided")
automatic = require("automatic")

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

function base.execute()
  if options.interface == "guided" then
    luatexbase.add_to_callback(base.get_callback(options.callback), guided.get_nodes, "guided")
  else
    luatexbase.add_to_callback(base.get_callback(options.callback), automatic.get_nodes, "automatic")
  end
end

return base