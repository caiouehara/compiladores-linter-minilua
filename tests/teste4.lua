--[[ comentario de bloco
que ocupa duas quebras
]]
function conta_ate(n)
  local i = 1
  repeat
    i = i + 1
  until i > n
end

function soma_passos(n)
  local s = 0
  for i = 1, n, 2 do
    s = s + i
  end
  return s
end
