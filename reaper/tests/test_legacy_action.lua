-- Regression test: a stale Action List entry pointing directly at Odium_Reaper_Extension.lua
-- must not call ReaImGui End() when Begin() returned false and must self-migrate to launcher.
local base = debug.getinfo(1,'S').source:sub(2):match('^(.*[\\/])')
local reaper_root = base .. '..' .. package.config:sub(1,1)

local calls = { end_count=0, add={}, ext={} }
reaper = {
  RecursiveCreateDirectory=function() end,
  get_action_context=function()
    return false, reaper_root .. 'Odium_Reaper_Extension.lua', 0, 12345, 0, 0, 0
  end,
  ImGui_GetBuiltinPath=function() return '/fake/reaimgui' end,
  AddRemoveReaScript=function(add, section, path, commit)
    calls.add[#calls.add+1] = {add=add, section=section, path=path, commit=commit}
    if add then return 67890 end
    return 1
  end,
  SetExtState=function(section, key, value, persist)
    calls.ext[key] = value
  end
}

local real_imgui = {}
real_imgui.Begin = function(ctx, ...)
  return false, true
end
real_imgui.End = function(ctx)
  calls.end_count = calls.end_count + 1
end
real_imgui.Button = function(ctx, label, ...)
  calls.last_button = label
  return false
end

package.preload.imgui = function()
  return function(version)
    assert(tostring(version) == '0.10')
    return real_imgui
  end
end

local core = dofile(base .. '../lib/odium_core.lua')
dofile(base .. '../lib/odium_package.lua')(core)
assert(core.VERSION == '2.1.3')

local factory = require('imgui')
local ImGui = factory('0.10')
local ctx = {}
local visible, open = ImGui.Begin(ctx, 'Odium', true)
assert(visible == false and open == true)
ImGui.End(ctx)
assert(calls.end_count == 0, 'End() must be suppressed when Begin() returned false')

ImGui.Button(ctx, 'Projeyi kaydet + .rpp ile paketle + ZIP')
assert(calls.last_button == 'Adobe Audition .sesx paketi + ZIP oluştur')

local removed_legacy, added_launcher = false, false
for _, call in ipairs(calls.add) do
  local normalized = tostring(call.path):gsub('\\','/')
  if not call.add and normalized:match('/Odium_Reaper_Extension%.lua$') then removed_legacy = true end
  if call.add and normalized:match('/Odium_Reaper_Launcher%.lua$') then added_launcher = true end
end
assert(removed_legacy, 'legacy raw Action must be removed')
assert(added_launcher, 'safe launcher Action must be registered')
assert(calls.ext.MAIN_COMMAND_ID == '67890')

print('Legacy Action lifecycle/self-heal regression test passed')
