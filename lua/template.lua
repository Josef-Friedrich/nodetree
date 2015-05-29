local template = {}

function template.key_value(key,value)
  return colors.yellow .. key .. ': ' .. colors.green .. value .. '; ' .. colors.reset
end

function template.heading(text)
  return '\n' .. template.line() .. '% ' .. text .. template.line() .. '\n'
end

function template.length(input)
  return string.format("%gpt", input / 2^16)
end

function template.char(input)
  return string.format("%q", unicode.utf8.char(input))
end

function template.line()
  return '\n%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n'
end

function template.frame(text,callback)
  local begin_text = "BEGIN nodelist debug (Callback: " .. tostring(callback) .. ")"
  local end_text = "END nodelist debug"
  return template.heading(begin_text) .. text .. template.heading(end_text)
end

function template.type(type)
  return colors.red .. string.upper(type) .. ' ' .. colors.reset
end

function template.print(text)
  print(text)
end

return template
