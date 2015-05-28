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
draw_action = function(n)
  local ret = {}
  ret[#ret + 1] = "name: action; "
  ret[#ret + 1] = string.format("action_type: %s", tostring(n.action_type)) .. "; "
  ret[#ret + 1] = string.format("action_id: %s",tostring(n.action_id)) .. "; "
  ret[#ret + 1] = string.format("named_id: %s",tostring(n.named_id)) .. "; "
  ret[#ret + 1] = string.format("file: %s",tostring(n.file)) .. "; "
  ret[#ret + 1] = string.format("new_window: %s",tostring(n.new_window)) .. "; "
  ret[#ret + 1] = string.format("data: %s",tostring(n.data):gsub(">","\\>"):gsub("<","\\<")) .. "; "
  ret[#ret + 1] = string.format("ref_count: %s",tostring(n.ref_count)) .. "; "

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
  	    ret[#ret + 1] = run_through(head.head)
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
      ret[#ret + 1] = process.base(head) .. "subtype: user_defined; " .. uid .. t .. val
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
