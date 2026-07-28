-- Pure Lua smoke tests. REAPER-dependent I/O functions are intentionally not called.
reaper = reaper or { RecursiveCreateDirectory=function() end }
local base = debug.getinfo(1,'S').source:sub(2):match('^(.*[\\/])')
local core = dofile(base .. '../lib/odium_core.lua')
local json = core.json

local encoded = json.encode({a=1,b=true,c={'x','y'},tr='İstanbul'})
local decoded = json.decode(encoded)
assert(decoded.a == 1 and decoded.b == true and decoded.c[2] == 'y')
assert(decoded.tr == 'İstanbul')

local files = {'line10.wav','line2.wav','line1.wav'}
table.sort(files, core.natural_less)
assert(files[1] == 'line1.wav' and files[2] == 'line2.wav' and files[3] == 'line10.wav')

local project = core.normalize_loaded_project({projectName='Test',lines={{originalName='hello.wav'}}}, '/tmp/pkg/.audub/project.json')
assert(project.app == 'Odium REAPER Extension')
assert(project.lines[1].lineId and project.lines[1].exportName == 'hello.wav')
assert(project.exportPresetId == 'game_wav_48k_24_mono')

print('Odium JSON/core smoke tests passed')
