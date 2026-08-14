-- Odium Studio - live REAPER Recording track -> Adobe Audition SESX delivery.
-- Loaded after odium_sesx.lua and overrides make_audition_package while reusing build_sesx().
return function(core)
  local sep = package.config:sub(1,1)
  local SAMPLE_RATE = core.SESX_SAMPLE_RATE or 48000

  local function sample_pos(seconds)
    return math.max(0, math.floor((tonumber(seconds) or 0) * SAMPLE_RATE + 0.5))
  end

  local function deep_copy(value)
    return core.json.decode(core.json.encode(value))
  end

  local function safe_file_name(name)
    local s = tostring(name or 'audio.wav')
    s = s:gsub('[<>:"/\\|%?%*%c]', '_'):gsub('^%s+', ''):gsub('%s+$', '')
    return s ~= '' and s or 'audio.wav'
  end

  local function add_file(manifest, relative_path)
    local key = tostring(relative_path or ''):lower():gsub('\\','/')
    if manifest.fileIds[key] ~= nil then return manifest.fileIds[key] end
    local id = #manifest.files
    manifest.files[#manifest.files+1] = {id=id, relativePath=relative_path}
    manifest.fileIds[key] = id
    return id
  end

  local function add_clip(manifest, role, relative_path, name, start_seconds, duration_seconds, source_in_seconds, source_span_seconds)
    local duration = math.max(1 / SAMPLE_RATE, tonumber(duration_seconds) or 0)
    local source_in = math.max(0, tonumber(source_in_seconds) or 0)
    local source_span = math.max(1 / SAMPLE_RATE, tonumber(source_span_seconds) or duration)
    local clip = {
      id = manifest.nextClipId,
      fileID = add_file(manifest, relative_path),
      name = name,
      startPoint = sample_pos(start_seconds),
      sourceInPoint = sample_pos(source_in),
      sourceOutPoint = sample_pos(source_in + source_span)
    }
    clip.endPoint = clip.startPoint + sample_pos(duration)
    manifest.nextClipId = manifest.nextClipId + 1
    manifest[role][#manifest[role]+1] = clip
    manifest.durationSamples = math.max(manifest.durationSamples, clip.endPoint)
  end

  local function zip_folder(root)
    local zip_path = root .. '.zip'
    os.remove(zip_path)
    local command
    if sep == '\\' then
      local escaped_root = root:gsub("'", "''")
      local escaped_zip = zip_path:gsub("'", "''")
      command = "powershell -NoProfile -ExecutionPolicy Bypass -Command \"& { Compress-Archive -LiteralPath '"
        .. escaped_root .. "' -DestinationPath '" .. escaped_zip .. "' -Force }\""
    else
      command = 'cd ' .. core.shell_quote(core.dirname(root))
        .. ' && zip -r ' .. core.shell_quote(zip_path) .. ' ' .. core.shell_quote(core.basename(root))
    end
    local ok, output = core.run_capture(command)
    return ok and zip_path or nil, ok and nil or output
  end

  local function package_timestamp()
    return os.date('%Y%m%d_%H%M%S')
  end

  local function selected_take(line)
    local path = line.selectedTakePath
    local meta = nil
    if line.selectedTakeId then
      for _, take in ipairs(line.takes or {}) do
        if take.takeId == line.selectedTakeId then
          meta = take
          if not path or path == '' then path = take.absolutePath or take.fileAbsolutePath or take.path end
          break
        end
      end
    end
    return path, meta
  end

  local function render_or_copy_line_take(line, index, root, ffmpeg, level_match, preset)
    local src, meta = selected_take(line)
    if not src or src == '' or not core.file_exists(src) then return nil, 'Seçili take dosyası bulunamadı.' end
    local stem = select(1, core.splitext(line.exportName or line.originalName or ('line_' .. index)))
    local name = string.format('%04d_%s_DUB.wav', index, safe_file_name(stem))
    local rel = 'Audio/Takes/' .. name
    local dst = core.join(root, 'Audio', 'Takes', name)
    local gain = nil
    if level_match and ffmpeg and line.originalAbsolutePath and core.file_exists(line.originalAbsolutePath) then
      gain = select(1, core.compute_level_gain(ffmpeg, line.originalAbsolutePath, src))
    end
    local ok, output = false, nil
    if ffmpeg then
      if line.segments and #line.segments > 0 then
        ok, output = core.export_segments(ffmpeg, line.segments, dst, preset, {gainDb=gain})
      else
        ok, output = core.export_file(ffmpeg, src, dst, preset, {gainDb=gain})
      end
    elseif (not line.segments or #line.segments <= 1) and not level_match then
      local _, ext = core.splitext(src)
      name = string.format('%04d_%s_DUB.%s', index, safe_file_name(stem), ext ~= '' and ext or 'wav')
      rel = 'Audio/Takes/' .. name
      dst = core.join(root, 'Audio', 'Takes', name)
      ok, output = core.copy_file(src, dst)
    else
      output = 'FFmpeg gerekli: çok parçalı kayıt veya düzey eşitleme paketlenemedi.'
    end
    if not ok then return nil, output end
    local start = tonumber(line.mixStart) or tonumber(line.timelineStart) or 0
    local duration = nil
    if tonumber(line.mixEnd) and tonumber(line.mixEnd) > start then
      duration = tonumber(line.mixEnd) - start
    elseif line.segments and #line.segments > 0 then
      local first, last = line.segments[1], line.segments[#line.segments]
      duration = math.max(0, (tonumber(last.finish) or 0) - (tonumber(first.start) or start))
    end
    if not duration or duration <= 0 then duration = core.source_duration(dst) end
    return {src=src, meta=meta, name=name, rel=rel, dst=dst, gain=gain, start=start, duration=duration}
  end

  function core.make_audition_package(project, opts)
    opts = opts or {}
    assert(project and type(project.lines) == 'table', 'Paketlenecek proje yok.')
    local project_root = project.projectRootPath or '.'
    local root = opts.packageRoot or core.join(project_root, safe_file_name(project.projectName or 'Odium_Project') .. '_AU_Dub_Package_' .. package_timestamp())
    local originals_dir = core.join(root, 'Audio', 'Originals')
    local takes_dir = core.join(root, 'Audio', 'Takes')
    local meta_dir = core.join(root, '.audub')
    reaper.RecursiveCreateDirectory(originals_dir, 0)
    reaper.RecursiveCreateDirectory(takes_dir, 0)
    reaper.RecursiveCreateDirectory(meta_dir, 0)

    local ffmpeg = opts.ffmpeg
    local recording_items = deep_copy(opts.recordingItems or {})
    local packaged = deep_copy(project)
    packaged.app = 'Odium REAPER Extension -> Adobe Audition SESX'
    packaged.packageFormat = 'sesx'
    packaged.packageRootPath = root
    packaged.packageCreatedAt = core.iso_now()
    packaged.sesxSampleRate = SAMPLE_RATE
    packaged.sesxTrackNames = {originals='ORIGINAL_REF', recordings='DUB_TAKE'}
    packaged.tracks = {originals='ORIGINAL_REF', recordings='DUB_TAKE'}
    packaged.recordingItems = {}

    local manifest = {files={}, fileIds={}, originalClips={}, takeClips={}, nextClipId=1, durationSamples=0}
    local report = {
      createdAt=core.iso_now(), packageRoot=root, format='sesx', originals=0, takes=0, leveled=0,
      recordingTrackItems=#recording_items, recordingTrackPackaged=0,
      missingOriginals={}, missingTakes={}, warnings={}
    }
    local preset = core.EXPORT_PRESETS.master_wav_48k_float_mono
    local lines_by_id, snapshot_line_ids = {}, {}
    for _, line in ipairs(project.lines) do if line.lineId then lines_by_id[line.lineId] = line end end
    for _, item in ipairs(recording_items) do if item.lineId and item.lineId ~= '' then snapshot_line_ids[item.lineId] = true end end

    -- Originals always come from the Odium line model.
    for i, line in ipairs(project.lines) do
      local pline = packaged.lines[i]
      local src = line.originalAbsolutePath
      if src and core.file_exists(src) then
        local name = string.format('%04d_%s', i, safe_file_name(line.originalName or ('line_' .. i .. '.wav')))
        local rel = 'Audio/Originals/' .. name
        local dst = core.join(root, 'Audio', 'Originals', name)
        local ok, err = core.copy_file(src, dst)
        if ok then
          report.originals = report.originals + 1
          pline.originalAbsolutePath, pline.originalRelativePath, pline.packageOriginalRelativePath = dst, rel, rel
          add_clip(manifest, 'originalClips', rel, line.originalName or name,
            tonumber(line.timelineStart) or 0,
            tonumber(line.originalDuration) or math.max(0, (tonumber(line.timelineEnd) or 0) - (tonumber(line.timelineStart) or 0)))
        else
          report.missingOriginals[#report.missingOriginals+1] = (line.originalName or line.lineId) .. ': ' .. tostring(err)
        end
      else
        report.missingOriginals[#report.missingOriginals+1] = line.originalName or line.lineId
      end

      -- If the live Recording snapshot covers this line, the exact track items below are authoritative.
      local live_covers_line = #recording_items > 0 and (snapshot_line_ids[line.lineId] or (line.segments and #line.segments > 0))
      if not live_covers_line then
        local take, err = render_or_copy_line_take(line, i, root, ffmpeg, opts.levelMatchOriginal, preset)
        if take then
          report.takes = report.takes + 1
          if take.gain then report.leveled = report.leveled + 1 end
          pline.selectedTakePath, pline.selectedTakeRelativePath, pline.packageTakeRelativePath = take.dst, take.rel, take.rel
          add_clip(manifest, 'takeClips', take.rel, 'DUB - ' .. (line.originalName or take.name), take.start, take.duration)
        elseif line.selectedTakePath or line.selectedTakeId then
          report.missingTakes[#report.missingTakes+1] = (line.originalName or line.lineId) .. ': ' .. tostring(err)
        end
      end
    end

    -- Live Recording track: every active item becomes an Audition DUB_TAKE clip at the exact REAPER timeline position.
    for i, item in ipairs(recording_items) do
      local src = item.filePath
      local start = tonumber(item.timelineStart) or 0
      local duration = math.max(0, tonumber(item.duration) or ((tonumber(item.timelineEnd) or 0) - start))
      local rate = tonumber(item.playRate) or 1
      if src and src ~= '' and duration > 0 and core.file_exists(src) then
        local stem = select(1, core.splitext(item.name or core.basename(src) or ('recording_' .. i)))
        local name = string.format('REC_%04d_%s.wav', i, safe_file_name(stem))
        local rel = 'Audio/Takes/' .. name
        local dst = core.join(root, 'Audio', 'Takes', name)
        local line = item.lineId and lines_by_id[item.lineId] or nil
        local gain = nil
        if opts.levelMatchOriginal and ffmpeg and line and line.originalAbsolutePath and core.file_exists(line.originalAbsolutePath) then
          gain = select(1, core.compute_level_gain(ffmpeg, line.originalAbsolutePath, src))
        end

        local ok, output = false, nil
        local source_in, source_span = 0, duration
        if ffmpeg then
          ok, output = core.export_segments(ffmpeg, {{
            start=0, finish=duration, duration=duration, filePath=src,
            sourceStart=tonumber(item.sourceStart) or 0, playRate=rate
          }}, dst, preset, {gainDb=gain})
        elseif math.abs(rate - 1) <= 0.0001 and not opts.levelMatchOriginal then
          local _, ext = core.splitext(src)
          name = string.format('REC_%04d_%s.%s', i, safe_file_name(stem), ext ~= '' and ext or 'wav')
          rel = 'Audio/Takes/' .. name
          dst = core.join(root, 'Audio', 'Takes', name)
          ok, output = core.copy_file(src, dst)
          source_in = math.max(0, tonumber(item.sourceStart) or 0)
        else
          output = 'FFmpeg gerekli: trim/play-rate veya düzey eşitlemeli Recording item paketlenemedi.'
        end

        if ok then
          report.takes = report.takes + 1
          report.recordingTrackPackaged = report.recordingTrackPackaged + 1
          if gain then report.leveled = report.leveled + 1 end
          add_clip(manifest, 'takeClips', rel, item.name or ('Recording ' .. i), start, duration, source_in, source_span)
          packaged.recordingItems[#packaged.recordingItems+1] = {
            index=i, lineId=item.lineId, name=item.name, timelineStart=start, timelineEnd=start+duration,
            duration=duration, playRate=rate, sourceStart=tonumber(item.sourceStart) or 0,
            sourceKind='reaper_recording_item', fileName=name, fileRelativePath=rel, absolutePath=dst
          }
        else
          report.missingTakes[#report.missingTakes+1] = (item.name or core.basename(src) or ('Recording ' .. i)) .. ': ' .. tostring(output)
        end
      elseif src and src ~= '' then
        report.missingTakes[#report.missingTakes+1] = (item.name or core.basename(src) or ('Recording ' .. i)) .. ': kaynak bulunamadı veya item süresi sıfır.'
      end
    end

    packaged.projectRootPath = root
    local json_path = core.join(meta_dir, 'project.json')
    core.save_project(packaged, json_path)

    local sesx_name = safe_file_name(project.projectName or 'Odium_Audition_Project'):gsub('%.sesx$', '') .. '.sesx'
    local sesx_path = core.join(root, sesx_name)
    local sesx = core.build_sesx(project.projectName or 'Odium_Audition_Project', manifest)
    local wrote, write_err = core.write_file(sesx_path, sesx)
    if not wrote then error('SESX yazılamadı: ' .. tostring(write_err)) end

    local readme = table.concat({
      'Odium Studio - Adobe Audition Mix Paketi',
      '========================================', '', 'Mixçi için:',
      '1. Bu klasörü komple aynı yapıda tutun.',
      '2. ' .. sesx_name .. ' dosyasını Adobe Audition ile açın.',
      '3. ORIGINAL_REF: orijinal referanslar.',
      '4. DUB_TAKE: paketleme anındaki gerçek REAPER Recording track itemları.',
      '5. .audub/project.json: Odium metadata ve paketlenmiş recordingItems listesi.', '',
      'Orijinal: ' .. tostring(report.originals),
      'Take toplam: ' .. tostring(report.takes),
      'Recording track item: ' .. tostring(report.recordingTrackPackaged) .. '/' .. tostring(report.recordingTrackItems),
      'Düzey eşitlenen: ' .. tostring(report.leveled),
      'Eksik orijinal: ' .. tostring(#report.missingOriginals),
      'Eksik take: ' .. tostring(#report.missingTakes), ''
    }, '\r\n')
    core.write_file(core.join(root, 'README_AUDITION_MIX.txt'), readme)

    report.sesxPath, report.projectJson = sesx_path, json_path
    report.sessionFiles = #manifest.files
    report.sessionClips = #manifest.originalClips + #manifest.takeClips
    core.write_file(core.join(meta_dir, 'package-report.json'), core.json.encode(report))
    report.zipPath, report.zipError = zip_folder(root)
    core.write_file(core.join(meta_dir, 'package-report.json'), core.json.encode(report))
    return report
  end

  return core
end
