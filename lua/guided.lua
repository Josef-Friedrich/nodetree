-- Based on http://gist.github.com/556247
base = require("base")

---
--
---
run_through = function(head)
  local ret = {}
  local typ,nodename
	while head do
	  typ = node.type(head.id)
	  nodename = nodex.node_id(head)

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
      ret[#ret + 1] = 'draw_node(head, { })'
    end

    head = head.next
	end
  return table.concat(ret, "\n")
end

---
--
---
get_nodes = function(head)
  local out = run_through(head)
  print(template.frame(out,callback))
end

---
--
---
register_callback = function()
  luatexbase.add_to_callback(base.get_callback(options.callback), get_nodes, "guided")
end
