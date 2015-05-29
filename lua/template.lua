local template = {}

function template.key_value(key,value)
  return colors.yellow .. key .. ': ' .. colors.white .. value .. '; ' .. colors.reset
end

function template.heading(text)
  return '\n' .. template.line() .. '% ' .. text .. template.line() .. '\n'
end

function template.length(input)
	input = tonumber(input)
	input = input / 2^16
	input = math.floor((input * 10^2) + 0.5) / (10^2)
  return string.format("%gpt", input)
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

-- t = type
function template.type(t)
  return template.type_color(t) .. string.upper(t) .. colors.reset  .. ' '
end

-- t = type
function template.type_color(t)

  if t == 'hlist' then
    return colors.red
  elseif t == 'vlist' then
    return colors.green
  elseif t == 'rule' then
    return colors.yellow
  elseif t == 'disc' then
    return colors.bright .. colors.blue
  elseif t == 'whatsit' then
    return colors.bright .. colors.magenta
  elseif t == 'math' then
    return colors.cyan
  elseif t == 'glue' then
    return colors.bright .. colors.red
  elseif t == 'kern' then
    return colors.bright .. colors.yellow
  elseif t == 'penalty' then
    return colors.blue
  elseif t == 'glyph' then
    return colors.bright .. colors.green
  else
    return colors.magenta
  end
end

function template.print(text)
  print(text)
end

return template
