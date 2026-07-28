-- Pure Lua smoke tests. REAPER-dependent I/O functions are intentionally not called.
reaper = reaper or { RecursiveCreateDirectory=function() end }
local base = debug.getinfo(1,'S').source:sub(2):match('^(.*[\\/])')
local core = dofile(base .. '../lib/odium_core.lua')
dofile(base .. '../lib/odium_package.lua')(core)
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

local rpp = '<SOURCE WAVE\nFILE "C:\\Audio\\line01.wav" 1\n>\nFILE "relative/line02.wav" 1\n'
local paths = core.collect_rpp_file_paths(rpp)
assert(#paths == 2 and paths[1] == 'C:\\Audio\\line01.wav')
local rewritten, replacements = core.rewrite_rpp_file_paths(rpp, {
  ['C:\\Audio\\line01.wav'] = 'SessionMedia/0001_line01.wav',
  ['relative/line02.wav'] = 'SessionMedia/0002_line02.wav'
})
assert(replacements == 2)
assert(rewritten:find('FILE "SessionMedia/0001_line01.wav"', 1, true))
assert(rewritten:find('FILE "SessionMedia/0002_line02.wav"', 1, true))

print('Odium JSON/core smoke tests passed')
