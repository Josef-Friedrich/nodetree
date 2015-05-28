local process = {}

---
-- Process fields which each node has.
---
function process.base(n)
  local out

  out = template.type(node.type(n.id))

  if options.verbosity > 1 then
    out = out .. template.key_value("id", nodex.node_id(n))
  end

  if options.verbosity > 2 then
    out = out .. template.key_value("next", nodex.node_id(n.next))
    out = out .. template.key_value("previous", nodex.node_id(n.prev))
  end

  return out
end

---
-- glyph
---
function process.glyph(n)
  local out = process.base(n) ..
    template.key_value("char", string.format("%q", unicode.utf8.char(n.char))) ..
    template.key_value("lang", string.format("%d", n.lang)) ..
    template.key_value("font", string.format("%d", n.font)) ..
    template.key_value("width", template.length(n.width))
  if n.components then
    out = out .. run_through(n.components)
  end

  return out
end

---
-- vlist
---
function process.vlist(n)
  local out
  if n.width ~= 0 then
    out = out .. template.key_value('width', template.length(n.width))
  end
  if n.height ~= 0 then
    out = out .. template.key_value('height', template.length(n.height))
  end
  if n.depth ~= 0 then
    out = out .. template.key_value('depth', template.length(n.depth))
  end
  if n.glue_set ~= 0 then
    out = out .. template.key_value('glue_set', n.glue_set)
  end
  if n.glue_sign ~= 0 then
    out = out .. template.key_value('glue_sign', n.glue_sign)
  end
  if n.glue_order ~= 0 then
    out = out .. template.key_value('glue_order', n.glue_order)
  end
  if n.shift ~= 0 then
    out = out .. template.key_value('shift', template.length(n.shift))
  end
  if n.head then
    out = out .. run_through(n.head)
  end

  return out
end

---
-- rule
---
function process.rule(n)
  local out = process.base(n)

  if n.width == -1073741824 then
    out = out .. template.key_value("width", "flexible")
  else
    out = out .. template.key_value("width", template.length(n.width))
  end

  if n.height == -1073741824 then
    out = out .. template.key_value("height", "flexible")
  else
    out = out .. template.key_value("height", template.length(n.height))
  end

  if n.depth == -1073741824 then
    out = out .. template.key_value("depth", "flexible")
  else
    out = out .. template.key_value("depth", template.length(n.depth))
  end

  return out
end

---
-- hlist
---
function process.hlist(n)
  local out = process.base(n)

  if n.width ~= 0 then
    out = out .. template.key_value("width", template.length(n.width))
  end

  if n.height ~= 0 then
    out = out .. template.key_value("height", template.length(n.height))
  end

  if n.depth ~= 0 then
    out = out .. template.key_value("depth", template.length(n.depth))
  end

  if n.glue_set ~= 0 then
    out = out .. template.key_value("glue_set", string.format("%d", n.glue_set))
  end

  if n.glue_sign ~= 0 then
    out = out .. template.key_value("glue_sign", string.format("%d", n.glue_sign))
  end

  if n.glue_order ~= 0 then
    out = out .. template.key_value("glue_order", string.format("%d", n.glue_order))
  end

  if n.shift ~= 0 then
    out = out .. template.key_value("shift", string.format("%d", n.shift))
  end

  out = out

  if n.head then
    out = out .. run_through(n.head)
  end

  return out
end

---
-- penalty
---
function process.penalty(n)
  return process.base(n) .. template.key_value("penalty", n.penalty)
end

---
-- disc
---
function process.disc(n)
  local out = process.base(n)
  out = out .. template.key_value("subtype", nodex.subtype(n))

  if n.pre then
    out = out .. run_through(n.pre)
  end

  if n.post then
    out = out .. run_through(n.post)
  end

  if n.replace then
    out = out .. run_through(n.replace)
  end

  return out
end

---
-- kern
---
function process.kern(n)
  return process.base(n) .. template.key_value("kern", template.length(n.kern))
end

---
-- glue
---
function process.glue(n)
  local subtype = nodex.subtype(n)
  local spec = string.format("%gpt", n.spec.width / 2^16)

  if n.spec.stretch ~= 0 then
    local stretch_order, shrink_order
    if n.spec.stretch_order == 0 then
      stretch_order = string.format(" + %gpt",n.spec.stretch / 2^16)
    else
      stretch_order = string.format(" + %g fi%s", n.spec.stretch  / 2^16, string.rep("l",n.spec.stretch_order - 1))
    end
    spec = spec .. stretch_order
  end
  if n.spec.shrink ~= 0 then
    if n.spec.shrink_order == 0 then
      shrink_order = string.format(" - %gpt",n.spec.shrink / 2^16)
    else
      shrink_order = string.format(" - %g fi%s", n.spec.shrink  / 2^16, string.rep("l",n.spec.shrink_order - 1))
    end

    spec = spec .. shrink_order
  end
  return process.base(n) .. template.key_value(subtype,spec)
end

---
-- whatsit colorstack
---
function process.whatsit_colorstack(n)
  return process.base(n) .. "subtype: colorstack; " ..
    template.key_value("stack", string.format("%d", n.stack)) ..
    template.key_value("cmd", string.format("%s", n.cmd)) ..
    template.key_value("data", string.format("%s", n.data))
end

return process