-- @description Odium Studio - Kurulum/Kayıt Bootstrap
-- @version 2.0.0
-- @author Odium Studio
-- @about
--   Odium ana panelini ve güncelleme eylemini REAPER Action List'e kaydeder.

local function script_dir()
  local src = debug.getinfo(1, 'S').source
  if src:sub(1,1) == '@' then src = src:sub(2) end
  return src:match('^(.*[\\/])') or './'
end

local function join(a, b)
  local sep = package.config:sub(1,1)
  return (a:gsub('[\\/]+$', '')) .. sep .. b
end

local root = script_dir()
local main_script = join(root, 'Odium_Reaper_Extension.lua')
local update_script = join(root, 'Odium_Check_For_Updates.lua')

if not reaper.AddRemoveReaScript then
  reaper.MB('Bu REAPER sürümünde AddRemoveReaScript API bulunamadı. REAPER 6.80 veya daha yeni bir sürüm önerilir.', 'Odium Studio', 0)
  return
end

local function register(path, state_key)
  -- Idempotent kurulum: aynı yolu önce kaldırmayı dener, sonra yeniden ekler.
  pcall(reaper.AddRemoveReaScript, false, 0, path, true)
  local command_id = reaper.AddRemoveReaScript(true, 0, path, true)
  if not command_id or command_id == 0 then
    error('ReaScript kaydedilemedi: ' .. path)
  end
  reaper.SetExtState('OdiumReaper', state_key, tostring(command_id), true)
  reaper.SetExtState('OdiumReaper', state_key .. '_PATH', path, true)
  return command_id
end

local ok, result = xpcall(function()
  local main_id = register(main_script, 'MAIN_COMMAND_ID')
  register(update_script, 'UPDATE_COMMAND_ID')
  reaper.SetExtState('OdiumReaper', 'INSTALL_ROOT', root, true)
  return main_id
end, debug.traceback)

if not ok then
  reaper.MB(tostring(result), 'Odium Studio - Kurulum Hatası', 0)
  return
end

if reaper.ImGui_GetBuiltinPath then
  reaper.MB('Odium Studio REAPER eylemleri başarıyla kaydedildi. Ana panel şimdi açılacak.', 'Odium Studio', 0)
  reaper.Main_OnCommand(result, 0)
else
  reaper.MB('Odium Studio REAPER eylemleri başarıyla kaydedildi. ReaImGui bu REAPER oturumunda henüz yüklenmemiş görünüyor. REAPER\'ı tamamen kapatıp yeniden açın; ardından Action List içinden Odium Studio panelini çalıştırın.', 'Odium Studio', 0)
end
