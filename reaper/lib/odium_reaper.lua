-- Odium Studio REAPER host integration
local H = {}
local base = debug.getinfo(1,'S').source:sub(2):match('^(.*[\\/])') or './'
local core = dofile(base .. 'odium_core.lua')
H.core = core

local function track_name(track)
  local _, name = reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', '', false)
  return name
end

function H.find_track(role_or_name)
  local count = reaper.CountTracks(0)
  for i=0,count-1 do
    local tr = reaper.GetTrack(0,i)
    local _, role = reaper.GetSetMediaTrackInfo_String(tr, 'P_EXT:ODIUM_ROLE', '', false)
    if role == role_or_name or track_name(tr) == role_or_name then return tr end
  end
end

function H.ensure_track(role, name)
  local tr = H.find_track(role) or H.find_track(name)
  if tr then return tr end
  local idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(idx, true)
  tr = reaper.GetTrack(0,idx)
  reaper.GetSetMediaTrackInfo_String(tr, 'P_NAME', name, true)
  reaper.GetSetMediaTrackInfo_String(tr, 'P_EXT:ODIUM_ROLE', role, true)
  return tr
end

local function item_ext(item, key, value)
  if value ~= nil then reaper.GetSetMediaItemInfo_String(item, 'P_EXT:'..key, tostring(value), true); return value end
  local _, v = reaper.GetSetMediaItemInfo_String(item, 'P_EXT:'..key, '', false); return v
end

function H.clear_managed_items(track, role)
  for i=reaper.CountTrackMediaItems(track)-1,0,-1 do
    local item = reaper.GetTrackMediaItem(track,i)
    if item_ext(item,'ODIUM_ROLE') == role then reaper.DeleteTrackMediaItem(track,item) end
  end
end

function H.add_audio_item(track, path, pos, len, name, role, line_id)
  local src = reaper.PCM_Source_CreateFromFile(path)
  if not src then return nil, 'Kaynak açılamadı: '..path end
  local item = reaper.AddMediaItemToTrack(track)
  local take = reaper.AddTakeToMediaItem(item)
  reaper.SetMediaItemTake_Source(take, src)
  reaper.SetMediaItemInfo_Value(item, 'D_POSITION', pos)
  reaper.SetMediaItemInfo_Value(item, 'D_LENGTH', len > 0 and len or core.source_duration(path))
  reaper.SetMediaItemInfo_Value(item, 'B_LOOPSRC', 0)
  reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', name or core.basename(path), true)
  item_ext(item,'ODIUM_ROLE',role); item_ext(item,'ODIUM_LINE_ID',line_id or '')
  return item
end

function H.place_originals(project)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  local tr = H.ensure_track('originals', project.tracks.originals)
  H.clear_managed_items(tr,'original')
  for _, line in ipairs(project.lines) do
    H.add_audio_item(tr, line.originalAbsolutePath, line.timelineStart, line.originalDuration, line.originalName, 'original', line.lineId)
  end
  local rec = H.ensure_track('recordings', project.tracks.recordings)
  reaper.SetMediaTrackInfo_Value(tr, 'B_MUTE', 0)
  reaper.SetMediaTrackInfo_Value(rec, 'I_RECARM', 1)
  reaper.PreventUIRefresh(-1); reaper.UpdateArrange(); reaper.Undo_EndBlock('Odium: orijinalleri yerleştir', -1)
  return #project.lines
end

local function source_path(take)
  if not take then return '' end
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return '' end
  local _, path = reaper.GetMediaSourceFileName(src, '')
  return path or ''
end

function H.scan_track(track)
  local items = {}
  for i=0,reaper.CountTrackMediaItems(track)-1 do
    local item = reaper.GetTrackMediaItem(track,i)
    local take = reaper.GetActiveTake(item)
    local pos = reaper.GetMediaItemInfo_Value(item,'D_POSITION')
    local len = reaper.GetMediaItemInfo_Value(item,'D_LENGTH')
    local name, sourceStart, playRate = '', 0, 1
    if take then
      local _, n = reaper.GetSetMediaItemTakeInfo_String(take,'P_NAME','',false); name=n or ''
      sourceStart = reaper.GetMediaItemTakeInfo_Value(take,'D_STARTOFFS') or 0
      playRate = reaper.GetMediaItemTakeInfo_Value(take,'D_PLAYRATE') or 1
    end
    items[#items+1] = {item=item,take=take,pos=pos,len=len,finish=pos+len,name=name,path=source_path(take),sourceStart=sourceStart,playRate=playRate}
  end
  table.sort(items,function(a,b) return a.pos<b.pos end)
  return items
end

function H.match_recordings(project, mode)
  local tr = H.find_track('recordings') or H.find_track(project.tracks.recordings)
  if not tr then error('Kayıt track’i bulunamadı.') end
  local items = H.scan_track(tr)
  local matched = 0
  for i,line in ipairs(project.lines) do
    local region_start = line.timelineStart
    local next_line = project.lines[i+1]
    local region_end = next_line and next_line.timelineStart or (line.timelineEnd + math.max(project.gapSeconds or 1, 10))
    local group = {}
    if mode == 'order' then
      if items[i] then group[1]=items[i] end
    else
      for _, it in ipairs(items) do
        local center = it.pos + it.len/2
        if center >= region_start and center < region_end then group[#group+1]=it end
      end
    end
    if #group > 0 then
      local first,last=group[1],group[#group]
      line.mixStart, line.mixEnd = first.pos, last.finish
      line.segments = {}
      for _,it in ipairs(group) do line.segments[#line.segments+1]={start=it.pos, finish=it.finish, duration=it.len, filePath=it.path, name=it.name, sourceStart=it.sourceStart, playRate=it.playRate} end
      local selected=group[1]
      local id=core.uid('take')
      line.takes=line.takes or {}; line.takes[#line.takes+1]={takeId=id,fileName=core.basename(selected.path),absolutePath=selected.path,sourceKind='reaper_track',createdAt=core.iso_now()}
      line.selectedTakeId,line.selectedTakePath=id,selected.path; line.status='take_matched'; matched=matched+1
      for _,it in ipairs(group) do item_ext(it.item,'ODIUM_LINE_ID',line.lineId); item_ext(it.item,'ODIUM_ROLE','recording') end
    end
  end
  return matched,#items
end

function H.build_from_tracks(original_index, recording_index, opts)
  local otr = reaper.GetTrack(0,(original_index or 1)-1)
  local rtr = reaper.GetTrack(0,(recording_index or 2)-1)
  if not otr or not rtr then error('Track numarası geçersiz.') end
  local originals = H.scan_track(otr)
  local project = {schemaVersion=3,app='Odium REAPER Extension',appVersion=core.VERSION,projectId=core.uid('project'),projectName=opts.projectName or 'REAPER_Dub_Project',createdAt=core.iso_now(),updatedAt=core.iso_now(),projectRootPath=opts.projectRootPath or '.',gapSeconds=0,exportPresetId='game_wav_48k_24_mono',levelMatchOriginal=true,tracks={originals=track_name(otr),recordings=track_name(rtr)},lines={}}
  for i,it in ipairs(originals) do
    local nm = it.name ~= '' and it.name or core.basename(it.path)
    project.lines[#project.lines+1]={lineId=core.uid('line'),index=i,originalName=nm,exportName=nm,originalAbsolutePath=it.path,originalDuration=it.len,timelineStart=it.pos,timelineEnd=it.finish,segments={},takes={}}
  end
  H.match_recordings_on_track(project,rtr)
  return project
end

function H.match_recordings_on_track(project, track)
  local items=H.scan_track(track); local matched=0
  for i,line in ipairs(project.lines) do
    local next_start=project.lines[i+1] and project.lines[i+1].timelineStart or math.huge
    local group={}
    for _,it in ipairs(items) do local c=it.pos+it.len/2; if c>=line.timelineStart and c<next_start then group[#group+1]=it end end
    if #group>0 then
      line.mixStart=group[1].pos; line.mixEnd=group[#group].finish; line.segments={}
      for _,it in ipairs(group) do line.segments[#line.segments+1]={start=it.pos,finish=it.finish,duration=it.len,filePath=it.path,name=it.name,sourceStart=it.sourceStart,playRate=it.playRate} end
      local id=core.uid('take'); line.takes={{takeId=id,fileName=core.basename(group[1].path),absolutePath=group[1].path,sourceKind='reaper_track',createdAt=core.iso_now()}}; line.selectedTakeId=id; line.selectedTakePath=group[1].path; matched=matched+1
    end
  end
  return matched
end

function H.current_project_path()
  local _, path = reaper.EnumProjects(-1, '')
  return path or ''
end

function H.save_current_project()
  reaper.Main_SaveProject(0, false)
  return H.current_project_path()
end

function H.select_line(project, index)
  local line=project.lines[index]; if not line then return end
  reaper.GetSet_LoopTimeRange(true,false,line.timelineStart,line.timelineEnd,false)
  reaper.SetEditCurPos(line.timelineStart,true,false)
end

return H
