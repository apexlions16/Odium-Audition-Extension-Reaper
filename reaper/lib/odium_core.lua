-- Odium Studio REAPER Extension - portable core
local M = { VERSION = '2.0.0' }

local sep = package.config:sub(1,1)
local function script_dir()
  local src = debug.getinfo(1, 'S').source
  if src:sub(1,1) == '@' then src = src:sub(2) end
  return src:match('^(.*[\\/])') or './'
end
local base = script_dir()
local json = dofile(base .. 'json.lua')
M.json = json

M.AUDIO_EXTENSIONS = {
  wav=true, wave=true, bwf=true, mp3=true, ogg=true, oga=true, flac=true,
  aif=true, aiff=true, aifc=true, m4a=true, aac=true, w64=true
}

M.EXPORT_PRESETS = {
  game_wav_48k_24_mono = { id='game_wav_48k_24_mono', name='Game VO - WAV 48kHz 24-bit Mono', ext='wav', sr=48000, channels=1, codec='pcm_s24le', tail_ms=0 },
  game_wav_48k_24_stereo = { id='game_wav_48k_24_stereo', name='Game VO - WAV 48kHz 24-bit Stereo', ext='wav', sr=48000, channels=2, codec='pcm_s24le', tail_ms=0 },
  game_wav_48k_16_mono = { id='game_wav_48k_16_mono', name='Game VO - WAV 48kHz 16-bit Mono', ext='wav', sr=48000, channels=1, codec='pcm_s16le', tail_ms=0 },
  wwise_wav_48k_24_mono = { id='wwise_wav_48k_24_mono', name='Wwise Ready - WAV 48kHz 24-bit Mono', ext='wav', sr=48000, channels=1, codec='pcm_s24le', tail_ms=50 },
  master_wav_48k_float_mono = { id='master_wav_48k_float_mono', name='Master - WAV 48kHz 32-bit Float Mono', ext='wav', sr=48000, channels=1, codec='pcm_f32le', tail_ms=0 },
  review_mp3_320_stereo = { id='review_mp3_320_stereo', name='Review - MP3 320 kbps Stereo', ext='mp3', sr=48000, channels=2, codec='libmp3lame', bitrate='320k', tail_ms=0 }
}

function M.join(...)
  local p = table.concat({...}, sep)
  p = p:gsub('[\\/]+', sep)
  return p
end

function M.normalize(path)
  if not path then return '' end
  return tostring(path):gsub('[\\/]+', sep)
end

function M.basename(path)
  return (tostring(path or ''):gsub('[\\/]+$',''):match('([^\\/]+)$')) or ''
end

function M.dirname(path)
  local p = tostring(path or ''):gsub('[\\/]+$','')
  return p:match('^(.*)[\\/][^\\/]+$') or ''
end

function M.splitext(path)
  local name = M.basename(path)
  local stem, ext = name:match('^(.*)%.([^%.]+)$')
  return stem or name, (ext or ''):lower()
end

function M.file_exists(path)
  local f = io.open(path, 'rb')
  if f then f:close(); return true end
  return false
end

function M.read_file(path)
  local f, err = io.open(path, 'rb')
  if not f then return nil, err end
  local data = f:read('*a'); f:close(); return data
end

function M.write_file(path, data)
  local dir = M.dirname(path)
  if dir ~= '' and reaper and reaper.RecursiveCreateDirectory then reaper.RecursiveCreateDirectory(dir, 0) end
  local f, err = io.open(path, 'wb')
  if not f then return nil, err end
  f:write(data); f:close(); return true
end

function M.copy_file(src, dst)
  local data, err = M.read_file(src)
  if not data then return nil, err end
  return M.write_file(dst, data)
end

local function natural_chunks(s)
  local out = {}
  for text, num in tostring(s):lower():gmatch('([^%d]*)(%d*)') do
    if text ~= '' then out[#out+1] = text end
    if num ~= '' then out[#out+1] = tonumber(num) end
  end
  return out
end

function M.natural_less(a, b)
  local aa, bb = natural_chunks(M.basename(a)), natural_chunks(M.basename(b))
  local n = math.max(#aa, #bb)
  for i=1,n do
    if aa[i] == nil then return true end
    if bb[i] == nil then return false end
    if aa[i] ~= bb[i] then
      if type(aa[i]) == type(bb[i]) then return aa[i] < bb[i] end
      return tostring(aa[i]) < tostring(bb[i])
    end
  end
  return tostring(a) < tostring(b)
end

function M.enumerate_audio_files(root, recursive)
  local files = {}
  local function walk(dir)
    local i = 0
    while true do
      local name = reaper.EnumerateFiles(dir, i)
      if not name then break end
      local _, ext = M.splitext(name)
      if M.AUDIO_EXTENSIONS[ext] then files[#files+1] = M.join(dir, name) end
      i = i + 1
    end
    if recursive then
      local j = 0
      while true do
        local sub = reaper.EnumerateSubdirectories(dir, j)
        if not sub then break end
        walk(M.join(dir, sub)); j = j + 1
      end
    end
  end
  walk(root)
  table.sort(files, M.natural_less)
  return files
end

function M.uid(prefix)
  local t = os.time()
  local r = math.random(100000, 999999)
  return string.format('%s_%d_%d', prefix or 'id', t, r)
end

function M.iso_now()
  return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

function M.source_duration(path)
  local src = reaper.PCM_Source_CreateFromFile(path)
  if not src then return 0 end
  local len = reaper.GetMediaSourceLength(src)
  reaper.PCM_Source_Destroy(src)
  return tonumber(len) or 0
end

function M.create_project(opts)
  opts = opts or {}
  local folder = assert(opts.originalFolder, 'originalFolder required')
  local files = M.enumerate_audio_files(folder, true)
  if #files == 0 then error('Seçilen klasörde desteklenen ses bulunamadı.') end
  local gap = tonumber(opts.gapSeconds) or 1.0
  local cursor, lines = 0, {}
  for i, path in ipairs(files) do
    local dur = M.source_duration(path)
    local name = M.basename(path)
    lines[#lines+1] = {
      lineId = M.uid('line'), index = i, originalName = name, exportName = name,
      originalAbsolutePath = path, originalRelativePath = M.join('Audio','Originals',name),
      originalDuration = dur, timelineStart = cursor, timelineEnd = cursor + dur,
      mixStart = nil, mixEnd = nil, segments = {}, takes = {}, selectedTakeId = nil,
      status = 'original_ready'
    }
    cursor = cursor + dur + gap
  end
  return {
    schemaVersion = 3, app = 'Odium REAPER Extension', appVersion = M.VERSION,
    projectId = M.uid('project'), projectName = opts.projectName or M.basename(folder),
    createdAt = M.iso_now(), updatedAt = M.iso_now(), originalFolder = folder,
    projectRootPath = opts.projectRootPath or folder, gapSeconds = gap,
    exportPresetId = opts.exportPresetId or 'game_wav_48k_24_mono',
    levelMatchOriginal = opts.levelMatchOriginal ~= false,
    tracks = { originals = 'ODIUM - Originals', recordings = 'ODIUM - Recordings' },
    lines = lines
  }
end

function M.normalize_loaded_project(project, loaded_path)
  assert(type(project) == 'table' and type(project.lines) == 'table', 'Geçersiz project.json')
  project.schemaVersion = project.schemaVersion or 2
  project.app = 'Odium REAPER Extension'
  project.appVersion = M.VERSION
  project.loadedFromPath = loaded_path
  project.projectRootPath = project.projectRootPath or M.dirname(M.dirname(loaded_path))
  project.tracks = project.tracks or { originals='ODIUM - Originals', recordings='ODIUM - Recordings' }
  project.exportPresetId = project.exportPresetId or (project.exportPreset and project.exportPreset.id) or 'game_wav_48k_24_mono'
  for i, line in ipairs(project.lines) do
    line.index = line.index or i
    line.lineId = line.lineId or M.uid('line')
    line.originalName = line.originalName or line.exportName or ('line_' .. i .. '.wav')
    line.exportName = line.exportName or line.originalName
    line.segments = line.segments or {}
    line.takes = line.takes or {}
  end
  return project
end

function M.save_project(project, path)
  project.updatedAt = M.iso_now()
  local ok, err = M.write_file(path, json.encode(project))
  if not ok then error(err) end
  project.loadedFromPath = path
  return path
end

function M.load_project(path)
  local text, err = M.read_file(path)
  if not text then error(err) end
  return M.normalize_loaded_project(json.decode(text), path)
end

function M.project_summary(project)
  local matched, takes = 0, 0
  for _, line in ipairs(project.lines or {}) do
    if line.mixStart and line.mixEnd then matched = matched + 1 end
    if line.selectedTakeId or line.selectedTakePath then takes = takes + 1 end
  end
  return { total=#(project.lines or {}), matched=matched, takes=takes }
end

function M.shell_quote(s)
  s = tostring(s or '')
  if sep == '\\' then return '"' .. s:gsub('"','\\"') .. '"' end
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

function M.run_capture(command)
  local p = io.popen(command .. ' 2>&1')
  if not p then return false, 'Komut çalıştırılamadı.' end
  local out = p:read('*a')
  local a,b,c = p:close()
  local ok = (a == true) or (type(a) == 'number' and a == 0) or c == 0
  return ok, out
end

function M.find_ffmpeg(script_root)
  local names = sep == '\\' and {'ffmpeg.exe'} or {'ffmpeg'}
  for _, n in ipairs(names) do
    local bundled = M.join(script_root or '', 'tools', n)
    if M.file_exists(bundled) then return bundled end
  end
  local ok = M.run_capture((sep == '\\' and 'where ffmpeg' or 'command -v ffmpeg'))
  if ok then return 'ffmpeg' end
  return nil
end

function M.measure_volume(ffmpeg, path)
  local nullout = sep == '\\' and 'NUL' or '/dev/null'
  local cmd = table.concat({M.shell_quote(ffmpeg), '-hide_banner -nostats -i', M.shell_quote(path), '-af volumedetect -f null', M.shell_quote(nullout)}, ' ')
  local _, out = M.run_capture(cmd)
  local mean = tonumber((out or ''):match('mean_volume:%s*(-?[%d%.]+)%s*dB'))
  local maxv = tonumber((out or ''):match('max_volume:%s*(-?[%d%.]+)%s*dB'))
  if not mean then return nil end
  return { mean=mean, max=maxv }
end

function M.compute_level_gain(ffmpeg, original, take)
  local a, b = M.measure_volume(ffmpeg, original), M.measure_volume(ffmpeg, take)
  if not a or not b or b.max == nil then return nil, 'Düzey ölçülemedi.' end
  local target = a.mean - b.mean
  local peak_limit = -1.0 - b.max
  return math.min(target, peak_limit), {target=target, peakLimit=peak_limit, original=a, recording=b}
end

local function preset_args(p)
  local args = {'-ar', tostring(p.sr), '-ac', tostring(p.channels)}
  if p.codec then args[#args+1]='-c:a'; args[#args+1]=p.codec end
  if p.bitrate then args[#args+1]='-b:a'; args[#args+1]=p.bitrate end
  return args
end

function M.export_file(ffmpeg, src, dst, preset, opts)
  opts = opts or {}
  local args = {M.shell_quote(ffmpeg), '-hide_banner -loglevel error -y -i', M.shell_quote(src)}
  local filters = {}
  if opts.gainDb and math.abs(opts.gainDb) >= 0.01 then filters[#filters+1] = string.format('volume=%.3fdB', opts.gainDb) end
  if opts.trimStart and opts.trimStart > 0 then args[#args+1] = '-ss ' .. string.format('%.6f', opts.trimStart) end
  if opts.duration and opts.duration > 0 then args[#args+1] = '-t ' .. string.format('%.6f', opts.duration) end
  if #filters > 0 then args[#args+1] = '-af ' .. M.shell_quote(table.concat(filters, ',')) end
  for _, a in ipairs(preset_args(preset)) do args[#args+1] = a end
  args[#args+1] = M.shell_quote(dst)
  return M.run_capture(table.concat(args, ' '))
end

function M.split_mix(project, ffmpeg, mix_path, out_dir, on_progress)
  reaper.RecursiveCreateDirectory(out_dir, 0)
  local preset = M.EXPORT_PRESETS.game_wav_48k_24_mono
  local report = { createdAt=M.iso_now(), mixPath=mix_path, items={}, errors={} }
  for i, line in ipairs(project.lines) do
    local s, e = tonumber(line.mixStart), tonumber(line.mixEnd)
    if s and e and e > s then
      local stem = M.splitext(line.exportName or line.originalName)
      local dst = M.join(out_dir, stem .. '.wav')
      local ok, output = M.export_file(ffmpeg, mix_path, dst, preset, {trimStart=s, duration=e-s})
      if ok then
        local take_id = M.uid('take')
        line.takes = line.takes or {}
        line.takes[#line.takes+1] = {takeId=take_id, fileName=M.basename(dst), absolutePath=dst, sourceKind='mix_split', createdAt=M.iso_now()}
        line.selectedTakeId, line.selectedTakePath = take_id, dst
        report.items[#report.items+1] = {lineId=line.lineId, output=dst, start=s, finish=e}
      else
        report.errors[#report.errors+1] = {lineId=line.lineId, error=output}
      end
    else
      report.errors[#report.errors+1] = {lineId=line.lineId, error='Kesim sınırı yok.'}
    end
    if on_progress then on_progress(i, #project.lines) end
  end
  return report
end

function M.export_segments(ffmpeg, segments, dst, preset, opts)
  opts = opts or {}
  if not segments or #segments == 0 then return false, 'Segment yok.' end
  local cmd = {M.shell_quote(ffmpeg), '-hide_banner -loglevel error -y'}
  local filters, labels = {}, {}
  for i, s in ipairs(segments) do
    local rate = tonumber(s.playRate) or 1
    local source_dur = (tonumber(s.duration) or 0) * rate
    cmd[#cmd+1] = '-ss '..string.format('%.6f', tonumber(s.sourceStart) or 0)
    cmd[#cmd+1] = '-t '..string.format('%.6f', source_dur)
    cmd[#cmd+1] = '-i '..M.shell_quote(s.filePath)
    local label='a'..i
    local chain=string.format('[%d:a]aresample=%d',i-1,preset.sr)
    if math.abs(rate-1) > 0.0001 then
      local pieces={}; local r=rate
      while r>2.0 do pieces[#pieces+1]='atempo=2.0'; r=r/2.0 end
      while r<0.5 do pieces[#pieces+1]='atempo=0.5'; r=r/0.5 end
      pieces[#pieces+1]=string.format('atempo=%.6f',r)
      chain=chain..','..table.concat(pieces,',')
    end
    chain=chain..string.format(',aformat=sample_rates=%d:channel_layouts=%s[%s]',preset.sr,preset.channels==1 and 'mono' or 'stereo',label)
    filters[#filters+1]=chain; labels[#labels+1]='['..label..']'
    if i < #segments then
      local gap=math.max(0,(tonumber(segments[i+1].start) or 0)-(tonumber(s.finish) or ((tonumber(s.start) or 0)+(tonumber(s.duration) or 0))))
      if gap>0.0005 then
        local sl='sil'..i
        filters[#filters+1]=string.format('anullsrc=r=%d:cl=%s:d=%.6f[%s]',preset.sr,preset.channels==1 and 'mono' or 'stereo',gap,sl)
        labels[#labels+1]='['..sl..']'
      end
    end
  end
  local out='joined'
  filters[#filters+1]=table.concat(labels,'')..string.format('concat=n=%d:v=0:a=1[%s]',#labels,out)
  if opts.gainDb and math.abs(opts.gainDb)>=0.01 then
    filters[#filters+1]=string.format('[%s]volume=%.3fdB[outa]',out,opts.gainDb); out='outa'
  end
  cmd[#cmd+1]='-filter_complex '..M.shell_quote(table.concat(filters,';'))
  cmd[#cmd+1]='-map '..M.shell_quote('['..out..']')
  for _,a in ipairs(preset_args(preset)) do cmd[#cmd+1]=a end
  cmd[#cmd+1]=M.shell_quote(dst)
  return M.run_capture(table.concat(cmd,' '))
end

function M.export_project(project, ffmpeg, out_dir, preset_id, level_match, on_progress)
  reaper.RecursiveCreateDirectory(out_dir, 0)
  local preset = assert(M.EXPORT_PRESETS[preset_id or project.exportPresetId], 'Export preset bulunamadı.')
  local report = { createdAt=M.iso_now(), preset=preset.id, items={}, errors={} }
  for i, line in ipairs(project.lines) do
    local src = line.selectedTakePath
    if not src and line.selectedTakeId then
      for _, t in ipairs(line.takes or {}) do if t.takeId == line.selectedTakeId then src = t.absolutePath or t.path break end end
    end
    if src and M.file_exists(src) then
      local stem = M.splitext(line.exportName or line.originalName)
      local dst = M.join(out_dir, stem .. '.' .. preset.ext)
      local gain = nil
      if level_match and line.originalAbsolutePath and M.file_exists(line.originalAbsolutePath) then
        gain = select(1, M.compute_level_gain(ffmpeg, line.originalAbsolutePath, src))
      end
      local ok, output
      if line.segments and #line.segments > 0 then ok,output=M.export_segments(ffmpeg,line.segments,dst,preset,{gainDb=gain})
      else ok,output=M.export_file(ffmpeg,src,dst,preset,{gainDb=gain}) end
      if ok then report.items[#report.items+1] = {lineId=line.lineId, source=src, output=dst, gainDb=gain}
      else report.errors[#report.errors+1] = {lineId=line.lineId, error=output} end
    else
      report.errors[#report.errors+1] = {lineId=line.lineId, error='Seçili take dosyası bulunamadı.'}
    end
    if on_progress then on_progress(i, #project.lines) end
  end
  return report
end

function M.attach_takes_by_name(project, folder)
  local files = M.enumerate_audio_files(folder, true)
  local by_stem = {}
  for _, path in ipairs(files) do local stem=M.splitext(M.basename(path)); by_stem[stem:lower()] = path end
  local count = 0
  for _, line in ipairs(project.lines) do
    local stem = M.splitext(line.originalName)
    local path = by_stem[stem:lower()]
    if path then
      local id = M.uid('take')
      line.takes = line.takes or {}
      line.takes[#line.takes+1] = {takeId=id, fileName=M.basename(path), absolutePath=path, sourceKind='folder_match', createdAt=M.iso_now()}
      line.selectedTakeId, line.selectedTakePath = id, path
      count = count + 1
    end
  end
  return count
end

function M.health_check(project, ffmpeg)
  local result = { ok=true, checkedAt=M.iso_now(), errors={}, warnings={}, summary=M.project_summary(project) }
  if not ffmpeg then result.ok=false; result.errors[#result.errors+1]='FFmpeg bulunamadı.' end
  for _, line in ipairs(project.lines or {}) do
    if line.originalAbsolutePath and not M.file_exists(line.originalAbsolutePath) then result.warnings[#result.warnings+1]='Orijinal yok: '..line.originalName end
    if line.selectedTakePath and not M.file_exists(line.selectedTakePath) then result.warnings[#result.warnings+1]='Take yok: '..line.originalName end
  end
  return result
end

function M.make_package(project, opts)
  opts = opts or {}
  local root = opts.packageRoot or M.join(project.projectRootPath or '.', 'Odium_REAPER_Package_' .. os.date('%Y%m%d_%H%M%S'))
  local audio_orig, audio_takes, meta = M.join(root,'Audio','Originals'), M.join(root,'Audio','Takes'), M.join(root,'.audub')
  reaper.RecursiveCreateDirectory(audio_orig, 0); reaper.RecursiveCreateDirectory(audio_takes, 0); reaper.RecursiveCreateDirectory(meta, 0)
  local packaged = json.decode(json.encode(project))
  packaged.packageRootPath = root; packaged.projectRootPath = root; packaged.packageCreatedAt = M.iso_now()
  local ffmpeg = opts.ffmpeg
  local copied_orig, copied_takes, leveled = 0,0,0
  for i, line in ipairs(project.lines) do
    local pline = packaged.lines[i]
    if line.originalAbsolutePath and M.file_exists(line.originalAbsolutePath) then
      local dst = M.join(audio_orig, line.originalName)
      M.copy_file(line.originalAbsolutePath, dst); copied_orig=copied_orig+1
      pline.originalAbsolutePath=dst; pline.originalRelativePath=M.join('Audio','Originals',line.originalName)
    end
    local src = line.selectedTakePath
    if src and M.file_exists(src) then
      local stem=M.splitext(line.exportName or line.originalName)
      local dst = M.join(audio_takes, stem .. '.wav')
      local gain=nil
      if opts.levelMatchOriginal and ffmpeg and line.originalAbsolutePath and M.file_exists(line.originalAbsolutePath) then
        gain=select(1,M.compute_level_gain(ffmpeg,line.originalAbsolutePath,src))
      end
      local preset=M.EXPORT_PRESETS.master_wav_48k_float_mono
      local ok
      if ffmpeg then
        if line.segments and #line.segments>0 then ok=M.export_segments(ffmpeg,line.segments,dst,preset,{gainDb=gain})
        else ok=M.export_file(ffmpeg,src,dst,preset,{gainDb=gain}) end
      end
      if not ok then dst=M.join(audio_takes,M.basename(src)); M.copy_file(src,dst) end
      if gain and ok then leveled=leveled+1 end
      copied_takes=copied_takes+1; pline.selectedTakePath=dst
    end
  end
  if opts.rppPath and M.file_exists(opts.rppPath) then M.copy_file(opts.rppPath, M.join(root, M.basename(opts.rppPath))) end
  M.save_project(packaged, M.join(meta,'project.json'))
  local report = {createdAt=M.iso_now(), packageRoot=root, originals=copied_orig, takes=copied_takes, leveled=leveled, rpp=opts.rppPath}
  M.write_file(M.join(meta,'package-report.json'), json.encode(report))
  local zip_path = root .. '.zip'
  local cmd
  if sep == '\\' then
    local pr=root:gsub("'","''"); local pz=zip_path:gsub("'","''")
    cmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command \"& { Compress-Archive -LiteralPath '" .. pr .. "' -DestinationPath '" .. pz .. "' -Force }\""
  else
    cmd = 'cd ' .. M.shell_quote(M.dirname(root)) .. ' && zip -r ' .. M.shell_quote(zip_path) .. ' ' .. M.shell_quote(M.basename(root))
  end
  local ok, out = M.run_capture(cmd)
  report.zipPath = ok and zip_path or nil; report.zipError = ok and nil or out
  return report
end

return M
