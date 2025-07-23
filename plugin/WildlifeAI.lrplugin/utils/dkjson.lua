-- dkjson.lua (condensed)  https://github.com/LuaDist/dkjson
local dkjson = {}
local json = dkjson
local function kind_of(obj)
  if type(obj) ~= 'table' then return type(obj) end
  local i = 1
  for _ in pairs(obj) do
    if obj[i] ~= nil then i = i + 1 else return 'table' end
  end
  if i == 1 then return 'table' else return 'array' end
end
local function escape_str(s)
  s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
  return s
end
function json.encode(obj)
  local t = type(obj)
  if t == 'nil' then return 'null'
  elseif t == 'number' or t == 'boolean' then return tostring(obj)
  elseif t == 'string' then return '"'..escape_str(obj)..'"'
  elseif t == 'table' then
    local k = kind_of(obj)
    if k == 'array' then
      local res = {}
      for _,v in ipairs(obj) do res[#res+1] = json.encode(v) end
      return '['..table.concat(res, ',')..']'
    else
      local res = {}
      for key,v in pairs(obj) do res[#res+1] = json.encode(key)..':'..json.encode(v) end
      return '{'..table.concat(res, ',')..'}'
    end
  else error('unsupported type '..t) end
end
-- Simple decoder using load() for brevity (LR sandbox allows). For production, use full dkjson.
function json.decode(str)
  local f, err = load('return '..str, 'json', 't', {})
  if not f then error(err) end
  return f()
end
return json