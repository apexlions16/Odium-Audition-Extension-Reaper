-- @description Odium Studio - REAPER Dublaj Uzantısı
-- @version 2.0.0
-- @author Odium Studio
-- @about
--   Tek-instance launcher ve ReaImGui 0.10 yaşam döngüsü uyumluluk katmanı.

local SCRIPT_PATH = debug.getinfo(1,'S').source:sub(2)
local SCRIPT_DIR = SCRIPT_PATH:match('^(.*[\\/])') or './'

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB('Odium REAPER Uzantısı için ReaImGui gerekli.', 'Odium Studio', 0)
  return
end

-- Aynı Action ikinci kez çalıştırılırsa ikinci bir ReaImGui context açma.
local _, _, section_id, command_id = reaper.get_action_context()
local has_action = type(section_id) == 'number' and type(command_id) == 'number' and command_id > 0
if has_action and reaper.GetToggleCommandStateEx and reaper.GetToggleCommandStateEx(section_id, command_id) == 1 then
  reaper.MB('Odium Studio zaten açık. Mevcut Odium penceresini kullanın.', 'Odium Studio', 0)
  return
end

local function set_running(value)
  if not has_action or not reaper.SetToggleCommandState then return end
  reaper.SetToggleCommandState(section_id, command_id, value and 1 or 0)
  if reaper.RefreshToolbar2 then reaper.RefreshToolbar2(section_id, command_id) end
end

set_running(true)
reaper.atexit(function() set_running(false) end)

-- ReaImGui 0.10 Lua örnekleri End() çağrısını yalnız Begin() true döndüğünde yapıyor.
-- Eski ana UI dosyası End() çağrısını koşul dışında yaptığı için görünmez/yeniden açılan
-- frame'lerde context bozulabiliyordu. Ana dosyaya dokunmadan küçük bir proxy ile düzelt.
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ok_factory, factory = pcall(require, 'imgui')
if not ok_factory then
  reaper.MB('ReaImGui yüklenemedi: ' .. tostring(factory), 'Odium Studio', 0)
  return
end

local real = factory('0.10')
local begin_visible = setmetatable({}, {__mode='k'})
local proxy = setmetatable({}, {__index=real})

proxy.Begin = function(ctx, ...)
  local visible, open = real.Begin(ctx, ...)
  begin_visible[ctx] = visible and true or false
  return visible, open
end

proxy.End = function(ctx)
  local visible = begin_visible[ctx]
  begin_visible[ctx] = nil
  if visible then return real.End(ctx) end
end

-- Kullanıcı arayüzündeki eski RPP metnini yeni Audition teslim akışına çevir.
proxy.Button = function(ctx, label, ...)
  if label == 'Projeyi kaydet + .rpp ile paketle + ZIP' then
    label = 'Adobe Audition .sesx paketi + ZIP oluştur'
  end
  return real.Button(ctx, label, ...)
end

package.loaded.imgui = function(version)
  if tostring(version or '') == '0.10' then return proxy end
  return factory(version)
end

local ok, err = xpcall(function()
  dofile(SCRIPT_DIR .. 'Odium_Reaper_Extension.lua')
end, debug.traceback)

if not ok then
  set_running(false)
  reaper.MB(tostring(err), 'Odium Studio - Başlatma Hatası', 0)
end
