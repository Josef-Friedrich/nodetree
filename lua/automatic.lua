base = require("base")

local automatic = {}

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
  if f == 'prev' or f == 'next' or f == 'spec' or f == 'pre' then
    out = nodex.node_id(n[f])
  elseif f == 'subtype' then
    out = nodex.subtype(n)
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
  out = out .. template.key_value('no', nodex.node_id(n))

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
end

---
--
---
function automatic.register_callback()
  luatexbase.add_to_callback(base.get_callback(options.callback), automatic.get_nodes, "automatic")
end

return automatic
