local direct            = node.direct
local todirect          = direct.todirect
local properties        = direct.get_properties_table()

local function dump(o)
  if type(o) == 'table' then
     local s = '{ '
     for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump(v) .. ','
     end
     return s .. '} '
  else
     return tostring(o)
  end
end

local function get_glyph_info(n)
  local node_id = todirect(n) -- Convert to node id
  local props = properties[node_id]
  local info = props
  if info then
    print(dump(info))
    return info
  end
end

local function callback_function(head, groupcode)
  for n in node.traverse_id(29, head) do
    get_glyph_info(n)
  end
  return head
end

luatexbase.add_to_callback("pre_linebreak_filter", callback_function, "test", 1)
