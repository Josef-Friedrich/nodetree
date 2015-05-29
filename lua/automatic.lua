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

  if options.verbosity < 2 and f == 'prev' or f == 'next' or f == 'id' or f == 'attr' then
    return ''
  end

  if f == 'prev' or f == 'next' or f == 'spec' or f == 'pre' or f == 'attr' then
    out = nodex.node_id(n[f])
  elseif f == 'subtype' then
    out = nodex.subtype(n)
  elseif f == 'width' or f == 'height' or f == 'depth' then
    out = template.length(n[f])
  elseif f == 'char' then
    out = template.char(n[f])
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

  if options.verbosity > 1 then
    out = out .. template.key_value('no', nodex.node_id(n))
  end

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

return automatic
