-- Pure Lua regression test for Odium_Reaper_Launcher.lua single-instance lease/focus logic.
local base = debug.getinfo(1,'S').source:sub(2):match('^(.*[\\/])')
local launcher_path = base .. '../Odium_Reaper_Launcher.lua'

local ext = {}
local toggle = 0
local toolbar_refreshes = 0
local main_runs = 0
local focus_calls = 0
local pos_calls = 0
local collapse_calls = 0
local size_calls = 0
local atexit_cb
local active_proxy

local real = {
  Cond_Always = 1,
  Cond_FirstUseEver = 2,
}

function real.Begin(_, _, open) return true, open end
function real.End(_) end
function real.SetNextWindowFocus(_) focus_calls = focus_calls + 1 end
function real.SetNextWindowCollapsed(_, collapsed, cond)
  assert(collapsed == false and cond == real.Cond_Always)
  collapse_calls = collapse_calls + 1
end
function real.GetMainViewport(_) return {} end
function real.Viewport_GetWorkPos(_) return 100, 200 end
function real.SetNextWindowPos(_, x, y, cond)
  assert(x == 136 and y == 236 and cond == real.Cond_Always)
  pos_calls = pos_calls + 1
end
function real.SetNextWindowSize(_, w, h, cond)
  assert(w == 650 and h == 760 and cond == real.Cond_FirstUseEver)
  size_calls = size_calls + 1
end
function real.Button(_, _, ...) return false end

local factory = function(version)
  assert(tostring(version) == '0.10')
  return real
end
package.preload.imgui = function() return factory end
package.loaded.imgui = nil

reaper = {
  ImGui_GetBuiltinPath = function() return '/mock/reaimgui' end,
  get_action_context = function() return false, launcher_path, 0, 4242 end,
  GetToggleCommandStateEx = function() return toggle end,
  SetToggleCommandState = function(_, _, value) toggle = value end,
  RefreshToolbar2 = function() toolbar_refreshes = toolbar_refreshes + 1 end,
  SetExtState = function(section, key, value) ext[section .. ':' .. key] = tostring(value) end,
  GetExtState = function(section, key) return ext[section .. ':' .. key] or '' end,
  DeleteExtState = function(section, key) ext[section .. ':' .. key] = nil end,
  atexit = function(fn) atexit_cb = fn end,
  MB = function() end,
}

local original_dofile = dofile
_G.dofile = function(path)
  if tostring(path):match('Odium_Reaper_Extension%.lua$') then
    main_runs = main_runs + 1
    local ImGui = require('imgui')('0.10')
    active_proxy = ImGui
    local ctx = {}
    local visible = ImGui.Begin(ctx, 'Odium', true)
    if visible then ImGui.End(ctx) end
    return true
  end
  return original_dofile(path)
end

local function run_launcher()
  local chunk, err = loadfile(launcher_path)
  assert(chunk, err)
  return chunk()
end

-- First launch: starts UI, sets toggle, renews lease and rescues window onto visible viewport.
run_launcher()
assert(main_runs == 1)
assert(toggle == 1)
assert(tonumber(ext['OdiumReaper:UI_LEASE_UNTIL'] or '0') >= os.time())
assert(ext['OdiumReaper:UI_FOCUS_REQUEST'] == nil)
assert(focus_calls == 1 and pos_calls == 1 and collapse_calls == 1 and size_calls == 1)
assert(type(atexit_cb) == 'function')

-- Second launch while lease is alive: must NOT start a new UI; it only requests focus.
run_launcher()
assert(main_runs == 1)
assert(ext['OdiumReaper:UI_FOCUS_REQUEST'] == '1')

-- Existing UI consumes that request on its next Begin and moves/focuses itself.
local ctx2 = {}
local visible2 = active_proxy.Begin(ctx2, 'Odium', true)
if visible2 then active_proxy.End(ctx2) end
assert(ext['OdiumReaper:UI_FOCUS_REQUEST'] == nil)
assert(focus_calls == 2 and pos_calls == 2 and collapse_calls == 2)

-- Simulate a crashed process: toggle remains ON but its lease is expired.
ext['OdiumReaper:UI_LEASE_UNTIL'] = '0'
package.loaded.imgui = nil
run_launcher()
assert(main_runs == 2)
assert(toggle == 1)
assert(tonumber(ext['OdiumReaper:UI_LEASE_UNTIL'] or '0') >= os.time())

-- Active instance exit must clean both toggle and transient runtime state.
assert(type(atexit_cb) == 'function')
atexit_cb()
assert(toggle == 0)
assert(ext['OdiumReaper:UI_LEASE_UNTIL'] == nil)
assert(ext['OdiumReaper:UI_FOCUS_REQUEST'] == nil)
assert(toolbar_refreshes > 0)

_G.dofile = original_dofile
print('Odium launcher lease/focus regression tests passed')
