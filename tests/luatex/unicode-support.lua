-- lower characters block somehow
for i=255,100000000 do
  print(i)
  print(unicode.utf8.char(i))
end
