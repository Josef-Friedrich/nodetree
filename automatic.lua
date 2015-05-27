dofile("base.lua")

---
--
-- n = node
-- f = field
---
format_field = function(n, f)
  local out = ''
  if not n[f] or n[f] == 0 then
    return
  end
  if f == 'prev' or f == 'next' or f == 'spec' or f == 'pre' then
    out = node.node_id(n[f])
  elseif f == 'subtype' then
    out = node.subtype(n)
  else
    out = tostring(n[f])
  end

  return f .. ': ' .. out
end

---
-- n = node
---
analayze_node = function(n)
  local out = {}

  out = string.upper(node.type(n.id)) .. ' '
  out = out .. 'no: '
  out = out .. node.node_id(n) .. '; '

  local tmp = {}
  fields = node.fields(n.id, n.subtype)
  for field_id,field_name in pairs(fields) do
    tmp[#tmp + 1] = format_field(n,field_name)
  end

  return out .. table.concat(tmp, "; ")
end

---
--
---
run_through = function(head)
  local out = {}
  while head do

    if head.id == 0 or head.id == 1 then
      out[#out + 1] = run_through(head.head)
    else
      out[#out + 1] = analayze_node(head)
    end

    head = head.next
  end

  return table.concat(out, "\n")
end

---
--
---
get_nodes = function(head)
  local out = run_through(head)
  texio.write(options.channel, fmt.frame(out))
end

---
--
---
register_callback = function()
  luatexbase.add_to_callback(get_callback(options.callback), get_nodes, "automatic")
end
