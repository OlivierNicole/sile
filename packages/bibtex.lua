epnf = require( "epnf" )

local ID = lpeg.C( SILE.parserBits.letter * (SILE.parserBits.letter+SILE.parserBits.digit)^0 )
local identifier = (ID + lpeg.P("-"))^1

local balanced = lpeg.C{ "{" * lpeg.P(" ")^0 * lpeg.C(((1 - lpeg.S"{}") + lpeg.V(1))^0) * "}" } 
local doubleq = lpeg.C( lpeg.P '"' * lpeg.C(((1 - lpeg.S '"\r\n\f\\') + (lpeg.P '\\' * 1)) ^ 0) * '"' )

bibtexparser = epnf.define(function (_ENV)
  local _ = WS^0
  local sep = lpeg.S(",;") * _
  local myID = C( identifier + lpeg.P(1) ) / function (t) return t end
  local value = balanced + doubleq
  local pair = lpeg.Cg(myID * _ * "=" * _ * C(value)) * _ * sep^-1   / function (...) local t= {...}; return t[1], t[#t] end
  local list = lpeg.Cf(lpeg.Ct("") * pair^0, rawset)

  START "document";
  document = (V"entry" + V"comment")^1
  comment  = WS + 
    ((P("%") * (1-lpeg.S("\r\n"))^0 * lpeg.S("\r\n")) /function () return "" end) -- Don't bother telling me about comments
  entry = Ct( P("@") * Cg(myID, "type") * _ * P("{") * _ * Cg(myID, "label") * _ * sep * list * P("}") * _ )
end)

local parseBibtex = function(fn)
  local fh = io.open(fn)
  local doc = fh:read("*all")
  local t = epnf.parsestring(bibtexparser, doc)
  print(doc)
  if not(t) or not(t[1]) or t.id ~= "document" then
    SU.error("Error parsing bibtex")
  end
  foobar = t
  local entries = {}
  for i =1,#t do
    if t[i].id == "entry" then
      local ent = t[i][1]
      entries[ent.label] = {type = ent.type, attributes = ent[1]}
    end
  end
  return entries
end