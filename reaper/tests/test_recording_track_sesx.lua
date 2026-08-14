-- Regression: package must include live ODIUM - Recordings items even when project.json has no selected take.
local base = debug.getinfo(1,'S').source:sub(2):match('^(.*[\\/])')
local temp = '/tmp/odium-recording-sesx-test-' .. tostring(os.time()) .. '-' .. tostring(math.random(1000,9999))
os.execute('rm -rf ' .. string.format('%q', temp))
os.execute('mkdir -p ' .. string.format('%q', temp))

local original = temp .. '/original.wav'
local rec1 = temp .. '/recording-a.wav'
local rec2 = temp .. '/recording-b.wav'
for path, data in pairs({[original]='ORIGINAL',[rec1]='RECORDING_A',[rec2]='RECORDING_B'}) do
  local f = assert(io.open(path, 'wb')); f:write(data); f:close()
end

local track = {name='ODIUM - Recordings', role='recordings', items={}}
local function make_item(path, pos, len, name, source_start, line_id)
  local take = {path=path, name=name, sourceStart=source_start or 0, playRate=1}
  return {take=take, pos=pos, len=len, ext={ODIUM_LINE_ID=line_id or '', ODIUM_ROLE='recording'}}
end
track.items[1] = make_item(rec1, 1.0, 0.5, 'Recorded A', 0.25, 'line1')
track.items[2] = make_item(rec2, 2.0, 0.75, 'Recorded B', 0.0, '')

reaper = {
  RecursiveCreateDirectory=function(path) os.execute('mkdir -p ' .. string.format('%q', path)) end,
  CountTracks=function() return 1 end,
  GetTrack=function(_, index) if index == 0 then return track end end,
  GetSetMediaTrackInfo_String=function(tr, parm)
    if parm == 'P_NAME' then return true, tr.name end
    if parm == 'P_EXT:ODIUM_ROLE' then return true, tr.role end
    return true, ''
  end,
  CountTrackMediaItems=function(tr) return #tr.items end,
  GetTrackMediaItem=function(tr, index) return tr.items[index+1] end,
  GetActiveTake=function(item) return item.take end,
  GetMediaItemTake_Source=function(take) return take.path end,
  GetMediaSourceFileName=function(source) return true, source end,
  GetMediaItemInfo_Value=function(item, parm)
    if parm == 'D_POSITION' then return item.pos end
    if parm == 'D_LENGTH' then return item.len end
    return 0
  end,
  GetSetMediaItemTakeInfo_String=function(take, parm)
    if parm == 'P_NAME' then return true, take.name end
    return true, ''
  end,
  GetMediaItemTakeInfo_Value=function(take, parm)
    if parm == 'D_STARTOFFS' then return take.sourceStart end
    if parm == 'D_PLAYRATE' then return take.playRate end
    return 0
  end,
  GetSetMediaItemInfo_String=function(item, parm)
    local key = parm:match('^P_EXT:(.+)$')
    return true, key and (item.ext[key] or '') or ''
  end
}

local core = dofile(base .. '../lib/odium_core.lua')
dofile(base .. '../lib/odium_package.lua')(core)
assert(core.VERSION == '2.1.3')
-- Avoid invoking the real zip binary; this test validates package contents before archive transport.
core.run_capture = function() return true, '' end

local project = {
  schemaVersion=3, app='Odium REAPER Extension', appVersion=core.VERSION,
  projectId='p1', projectName='RecordingSnapshot', projectRootPath=temp,
  tracks={originals='ODIUM - Originals', recordings='ODIUM - Recordings'},
  lines={{
    lineId='line1', index=1, originalName='line1.wav', exportName='line1.wav',
    originalAbsolutePath=original, originalDuration=1.0, timelineStart=0, timelineEnd=1.0,
    segments={}, takes={}, selectedTakeId=nil, selectedTakePath=nil
  }}
}

local package_root = temp .. '/package'
local report = core.make_package(project, {packageRoot=package_root, ffmpeg=nil, levelMatchOriginal=false})
assert(report.recordingTrackItems == 2, 'live recording track item count must be 2')
assert(report.recordingTrackPackaged == 2, 'both recording items must be packaged')
assert(report.takes == 2, 'DUB_TAKE must contain both live recording items')

local sesx_path = package_root .. '/RecordingSnapshot.sesx'
local f = assert(io.open(sesx_path, 'rb')); local sesx = f:read('*a'); f:close()
assert(sesx:find('<name>DUB_TAKE</name>', 1, true))
assert(sesx:find('Recorded A', 1, true))
assert(sesx:find('Recorded B', 1, true))
assert(sesx:find('startPoint="48000"', 1, true), 'first recording must start at 1.0s')
assert(sesx:find('sourceInPoint="12000"', 1, true), 'trimmed first recording must preserve 0.25s source offset')
assert(sesx:find('sourceOutPoint="36000"', 1, true), 'first recording source out must be 0.75s')
assert(sesx:find('startPoint="96000"', 1, true), 'second recording must start at 2.0s')
assert(sesx:find('Audio\\Takes\\REC_0001_Recorded A.wav', 1, true))
assert(sesx:find('Audio\\Takes\\REC_0002_Recorded B.wav', 1, true))

local pj = assert(io.open(package_root .. '/.audub/project.json', 'rb'))
local json = pj:read('*a'); pj:close()
local packed = core.json.decode(json)
assert(type(packed.recordingItems) == 'table' and #packed.recordingItems == 2)
assert(packed.recordingItems[1].timelineStart == 1.0)
assert(packed.recordingItems[2].timelineStart == 2.0)

assert(core.file_exists(package_root .. '/Audio/Takes/REC_0001_Recorded A.wav'))
assert(core.file_exists(package_root .. '/Audio/Takes/REC_0002_Recorded B.wav'))

os.execute('rm -rf ' .. string.format('%q', temp))
print('Live Recording track -> SESX regression test passed')
