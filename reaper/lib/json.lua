-- Odium Studio JSON library
-- Small self-contained JSON encoder/decoder for REAPER Lua.
local json = { _VERSION = "1.0.0" }

local escape_map = {
  ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
  ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t'
}
local escape_map_inv = { ['\\"']='"', ['\\\\']='\\', ['\\/']='/', ['\\b']='\b', ['\\f']='\f', ['\\n']='\n', ['\\r']='\r', ['\\t']='\t' }

local function encode_string(s)
  return '"' .. s:gsub('[%z\1-\31\\"]', function(c)
    return escape_map[c] or string.format('\\u%04x', c:byte())
  end) .. '"'
end

local function is_array(t)
  local max, count = 0, 0
  for k in pairs(t) do
    if type(k) ~= 'number' or k < 1 or k % 1 ~= 0 then return false end
    if k > max then max = k end
    count = count + 1
  end
  return max == count
end

local function encode_value(v, stack)
  local tv = type(v)
  if tv == 'nil' then return 'null' end
  if tv == 'boolean' then return v and 'true' or 'false' end
  if tv == 'number' then
    if v ~= v or v == math.huge or v == -math.huge then return 'null' end
    return string.format('%.14g', v)
  end
  if tv == 'string' then return encode_string(v) end
  if tv ~= 'table' then error('unsupported JSON type: ' .. tv) end
  if stack[v] then error('circular reference') end
  stack[v] = true
  local out = {}
  if is_array(v) then
    for i = 1, #v do out[#out+1] = encode_value(v[i], stack) end
    stack[v] = nil
    return '[' .. table.concat(out, ',') .. ']'
  end
  local keys = {}
  for k in pairs(v) do keys[#keys+1] = tostring(k) end
  table.sort(keys)
  for _, k in ipairs(keys) do
    out[#out+1] = encode_string(k) .. ':' .. encode_value(v[k], stack)
  end
  stack[v] = nil
  return '{' .. table.concat(out, ',') .. '}'
end

function json.encode(v)
  return encode_value(v, {})
end

local function decode_error(str, idx, msg)
  error(string.format('JSON decode error at %d: %s', idx, msg))
end

local function skip_ws(str, idx)
  local _, e = str:find('^[ \n\r\t]*', idx)
  return (e or idx - 1) + 1
end

local function parse_unicode_escape(hex)
  local n = tonumber(hex, 16)
  if not n then return '' end
  if n <= 0x7f then return string.char(n) end
  if n <= 0x7ff then
    return string.char(0xc0 + math.floor(n / 0x40), 0x80 + (n % 0x40))
  end
  return string.char(0xe0 + math.floor(n / 0x1000), 0x80 + (math.floor(n / 0x40) % 0x40), 0x80 + (n % 0x40))
end

local parse_value

local function parse_string(str, idx)
  idx = idx + 1
  local out = {}
  while idx <= #str do
    local c = str:sub(idx, idx)
    if c == '"' then return table.concat(out), idx + 1 end
    if c == '\\' then
      local esc = str:sub(idx, idx + 1)
      if escape_map_inv[esc] then
        out[#out+1] = escape_map_inv[esc]
        idx = idx + 2
      elseif str:sub(idx + 1, idx + 1) == 'u' then
        local hex = str:sub(idx + 2, idx + 5)
        if not hex:match('^%x%x%x%x$') then decode_error(str, idx, 'invalid unicode escape') end
        out[#out+1] = parse_unicode_escape(hex)
        idx = idx + 6
      else
        decode_error(str, idx, 'invalid escape')
      end
    else
      out[#out+1] = c
      idx = idx + 1
    end
  end
  decode_error(str, idx, 'unterminated string')
end

local function parse_number(str, idx)
  local s, e = str:find('^-?%d+%.?%d*[eE]?[+-]?%d*', idx)
  if not s then decode_error(str, idx, 'invalid number') end
  local n = tonumber(str:sub(s, e))
  if not n then decode_error(str, idx, 'invalid number') end
  return n, e + 1
end

local function parse_array(str, idx)
  local arr = {}
  idx = skip_ws(str, idx + 1)
  if str:sub(idx, idx) == ']' then return arr, idx + 1 end
  while true do
    local v
    v, idx = parse_value(str, idx)
    arr[#arr+1] = v
    idx = skip_ws(str, idx)
    local c = str:sub(idx, idx)
    if c == ']' then return arr, idx + 1 end
    if c ~= ',' then decode_error(str, idx, 'expected comma') end
    idx = skip_ws(str, idx + 1)
  end
end

local function parse_object(str, idx)
  local obj = {}
  idx = skip_ws(str, idx + 1)
  if str:sub(idx, idx) == '}' then return obj, idx + 1 end
  while true do
    if str:sub(idx, idx) ~= '"' then decode_error(str, idx, 'expected string key') end
    local key
    key, idx = parse_string(str, idx)
    idx = skip_ws(str, idx)
    if str:sub(idx, idx) ~= ':' then decode_error(str, idx, 'expected colon') end
    idx = skip_ws(str, idx + 1)
    obj[key], idx = parse_value(str, idx)
    idx = skip_ws(str, idx)
    local c = str:sub(idx, idx)
    if c == '}' then return obj, idx + 1 end
    if c ~= ',' then decode_error(str, idx, 'expected comma') end
    idx = skip_ws(str, idx + 1)
  end
end

parse_value = function(str, idx)
  idx = skip_ws(str, idx)
  local c = str:sub(idx, idx)
  if c == '"' then return parse_string(str, idx) end
  if c == '{' then return parse_object(str, idx) end
  if c == '[' then return parse_array(str, idx) end
  if c == '-' or c:match('%d') then return parse_number(str, idx) end
  if str:sub(idx, idx + 3) == 'true' then return true, idx + 4 end
  if str:sub(idx, idx + 4) == 'false' then return false, idx + 5 end
  if str:sub(idx, idx + 3) == 'null' then return nil, idx + 4 end
  decode_error(str, idx, 'unexpected token')
end

function json.decode(str)
  assert(type(str) == 'string', 'json.decode expects a string')
  local value, idx = parse_value(str, 1)
  idx = skip_ws(str, idx)
  if idx <= #str then decode_error(str, idx, 'trailing garbage') end
  return value
end

return json
