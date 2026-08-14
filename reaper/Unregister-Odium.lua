-- @description Odium Studio - Action List Kaydını Kaldır
-- @version 2.0.0
-- @author Odium Studio

local function script_dir()
  local src = debug.getinfo(1, 'S').source
  if src:sub(1,1) == '@' then src = src:sub(2) end
  return src:match('^(.*[\\/])') or './'
end

local function join(a, b)
  local sep = package.config:sub(1,1)
  return (a:gsub('[\\/]+$', '')) .. sep .. b
end

local root = reaper.GetExtState('OdiumReaper', 'INSTALL_ROOT')
if root == '' then root = script_dir() end

local targets = {
  join(root, 'Odium_Reaper_Extension.lua'),
  join(root, 'Odium_Check_For_Updates.lua')
}

local removed = 0
if reaper.AddRemoveReaScript then
  for _, path in ipairs(targets) do
    local ok, rv = pcall(reaper.AddRemoveReaScript, false, 0, path, true)
    if ok and rv and rv > 0 then removed = removed + 1 end
  end
end

for _, key in ipairs({
  'MAIN_COMMAND_ID', 'MAIN_COMMAND_ID_PATH',
  'UPDATE_COMMAND_ID', 'UPDATE_COMMAND_ID_PATH',
  'INSTALL_ROOT'
}) do
  reaper.DeleteExtState('OdiumReaper', key, true)
end

reaper.MB(string.format('Odium Action List kayıtları temizlendi (%d kayıt). Dosyaları artık güvenle kaldırabilirsiniz.', removed), 'Odium Studio', 0)
