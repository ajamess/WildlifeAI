-- dkjson.lua (tiny)
local json = {}
local function kind(o)
  if type(o) ~= 'table' then return type(o) end
  local i=1; for _ in pairs(o) do if o[i]~=nil then i=i+1 else return 'table' end end
  return 'array'
end
local function esc(s) return s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t') end
function json.encode(o)
  local t=type(o)
  if t=='nil' then return 'null'
  elseif t=='number' or t=='boolean' then return tostring(o)
  elseif t=='string' then return '"'..esc(o)..'"'
  elseif t=='table' then
    local k=kind(o)
    if k=='array' then
      local r={} for _,v in ipairs(o) do r[#r+1]=json.encode(v) end
      return '['..table.concat(r,',')..']'
    else
      local r={} for k,v in pairs(o) do r[#r+1]=json.encode(k)..':'..json.encode(v) end
      return '{'..table.concat(r,',')..'}'
    end
  else error('bad type '..t) end
end
return json
