-- @description Odium Studio - REAPER Dublaj Uzantısı
-- @version 2.1.2
-- @author Odium Studio
-- @about
--   Tek-instance launcher, stale-state kurtarma ve görünür pencere odaklama katmanı.

local SCRIPT_PATH = debug.getinfo(1,'S').source:sub(2)
local SCRIPT_DIR = SCRIPT_PATH:match('^(.*[\\/])') or './'
local EXT_SECTION = 'OdiumReaper'
local LEASE_KEY = 'UI_LEASE_UNTIL'
local FOCUS_KEY = 'UI_FOCUS_REQUEST'

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB('Odium REAPER Uzantısı için ReaImGui gerekli.', 'Odium Studio', 0)
  return
end

local _, _, section_id, command_id = reaper.get_action_context()
local has_action = type(section_id) == 'number' and type(command_id) == 'number' and command_id > 0

local function set_running(value)
  if not has_action or not reaper.SetToggleCommandState then return end
  reaper.SetToggleCommandState(section_id, command_id, value and 1 or 0)
  if reaper.RefreshToolbar2 then reaper.RefreshToolbar2(section_id, command_id) end
end

local function lease_is_alive()
  if not reaper.GetExtState then return false end
  local until_ts = tonumber(reaper.GetExtState(EXT_SECTION, LEASE_KEY) or '') or 0
  return until_ts >= os.time()
end

local function clear_runtime_state()
  if reaper.DeleteExtState then
    reaper.DeleteExtState(EXT_SECTION, LEASE_KEY, false)
    reaper.DeleteExtState(EXT_SECTION, FOCUS_KEY, false)
  end
end

local toggle_on = has_action and reaper.GetToggleCommandStateEx
  and reaper.GetToggleCommandStateEx(section_id, command_id) == 1

if toggle_on and lease_is_alive() then
  -- Gerçek UI yaşıyor. Yeni context açmak yerine mevcut pencereye odaklanma/kurtarma isteği gönder.
  reaper.SetExtState(EXT_SECTION, FOCUS_KEY, '1', false)
  return
end

if toggle_on then
  -- Önceki crash/abort'tan kalmış stale toggle. Kendi kendine iyileştir.
  set_running(false)
  clear_runtime_state()
end

set_running(true)
reaper.SetExtState(EXT_SECTION, LEASE_KEY, tostring(os.time() + 10), false)
-- Her normal açılışta pencerenin görünür çalışma alanına gelmesini iste.
reaper.SetExtState(EXT_SECTION, FOCUS_KEY, '1', false)

reaper.atexit(function()
  set_running(false)
  clear_runtime_state()
end)

-- ReaImGui 0.10 Lua örneklerinde End() yalnız Begin() true döndüğünde çağrılır.
-- Ana UI dosyasını eski Action kaydıyla çalıştıran kurulumlar için de proxy koruması sürdürülür.
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ok_factory, factory = pcall(require, 'imgui')
if not ok_factory then
  set_running(false)
  clear_runtime_state()
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
  clear_runtime_state()
  reaper.MB(tostring(err), 'Odium Studio - Başlatma Hatası', 0)
end
