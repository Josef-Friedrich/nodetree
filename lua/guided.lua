-- Based on http://gist.github.com/556247
base = require("base")

---
--
---
label = function(n,tab)
  local typ = node.type(n.id)
  local nodename = nodex.node_id(n)
  local subtype = nodex.subtype(n)
  local ret = string.format("name: %s; type: %s;",typ or "??",subtype or "?") .. "; "
  if tab then
    for i=1,#tab do
      if tab[i][1] then
        ret = ret .. string.format("%s: %s; ",tab[i][1],tab[i][2])
      end
    end
  end
  return process.base(n) .. ret .. "\n"
end

---
--
---
draw_node = function(n,tab)
  local ret = {}
  if not tab then
    tab = {}
  end
  local nodename = nodex.node_id(n)
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
      ret[#ret + 1] = draw_node(head, { })
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
