-- Odium Studio - Adobe Audition SESX package exporter.
-- Produces a portable Audition session + media + project.json + ZIP without requiring Audition.
return function(core)
  local sep = package.config:sub(1,1)
  local SAMPLE_RATE = 48000
  local SESSION_BIT_DEPTH = 32

  local function xml_escape(value)
    local s = tostring(value or '')
    return (s:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;'):gsub("'",'&apos;'))
  end

  local function relative_xml_path(path)
    return tostring(path or ''):gsub('/', '\\')
  end

  local function safe_file_name(name)
    local s = tostring(name or 'audio.wav')
    s = s:gsub('[<>:"/\\|%?%*%c]', '_')
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if s == '' then s = 'audio.wav' end
    return s
  end

  local function deep_copy(value)
    return core.json.decode(core.json.encode(value))
  end

  local function sample_pos(seconds)
    local n = tonumber(seconds) or 0
    return math.max(0, math.floor(n * SAMPLE_RATE + 0.5))
  end

  local function add_file(manifest, relative_path)
    local key = tostring(relative_path or ''):lower():gsub('\\','/')
    if manifest.fileIds[key] ~= nil then return manifest.fileIds[key] end
    local id = #manifest.files
    manifest.files[#manifest.files+1] = { id=id, relativePath=relative_path }
    manifest.fileIds[key] = id
    return id
  end

  local function add_clip(manifest, role, relative_path, name, start_seconds, duration_seconds)
    local duration = math.max(1 / SAMPLE_RATE, tonumber(duration_seconds) or 0)
    local file_id = add_file(manifest, relative_path)
    local clip = {
      id = manifest.nextClipId,
      fileID = file_id,
      name = name,
      startPoint = sample_pos(start_seconds),
      sourceInPoint = 0,
      sourceOutPoint = sample_pos(duration),
    }
    clip.endPoint = clip.startPoint + clip.sourceOutPoint
    manifest.nextClipId = manifest.nextClipId + 1
    manifest[role][#manifest[role]+1] = clip
    if clip.endPoint > manifest.durationSamples then manifest.durationSamples = clip.endPoint end
  end

  local function clip_xml(clip)
    return table.concat({
      string.format('        <audioClip clipAutoCrossfade="false" crossFadeHeadClipID="-1" crossFadeTailClipID="-1" endPoint="%d" fileID="%d" hue="-1" id="%d" lockedInTime="false" looped="false" name="%s" offline="false" select="false" sourceInPoint="%d" sourceOutPoint="%d" startPoint="%d" zOrder="%d">',
        clip.endPoint, clip.fileID, clip.id, xml_escape(clip.name), clip.sourceInPoint, clip.sourceOutPoint, clip.startPoint, clip.id),
      '          <component componentID="Audition.Fader" id="clipGain" name="volume" powered="true">',
      '            <parameter index="0" name="volume" parameterValue="1"/>',
      '            <parameter index="1" name="static gain" parameterValue="1"/>',
      '          </component>',
      '          <clipStretch pitchAdjustment="0" preserveFormants="true" stretchMode="rendered" stretchQuality="high" stretchRatio="1" stretchType="solo"/>',
      '        </audioClip>'
    }, '\n')
  end

  local function track_xml(id, index, name, hue, clips)
    local out = {
      string.format('      <audioTrack automationLaneOpenState="false" id="%d" index="%d" select="%s" visible="true">', id, index, index == 1 and 'true' or 'false'),
      string.format('        <trackParameters trackHeight="90" trackHue="%d" trackMinimized="false">', hue),
      '          <name>' .. xml_escape(name) .. '</name>',
      '        </trackParameters>',
      '        <trackAudioParameters audioChannelType="stereo" automationMode="1" monitoring="false" recordArmed="false" solo="false" soloSafe="false">',
      '          <trackOutput outputID="10000" type="trackID"/>',
      '          <trackInput inputID="-1"/>',
      '          <component componentID="Audition.Fader" id="trackFader" name="volume" powered="true">',
      '            <parameter index="0" name="volume" parameterValue="1"/>',
      '            <parameter index="1" name="static gain" parameterValue="1"/>',
      '          </component>',
      '          <component componentID="Audition.Mute" id="trackMute" name="Mute" powered="true">',
      '            <parameter index="0" parameterValue="0"/>',
      '            <parameter index="1" name="mute" parameterValue="0"/>',
      '          </component>',
      '        </trackAudioParameters>'
    }
    for _, clip in ipairs(clips) do out[#out+1] = clip_xml(clip) end
    out[#out+1] = '      </audioTrack>'
    return table.concat(out, '\n')
  end

  local function master_xml(index)
    return table.concat({
      string.format('      <masterTrack automationLaneOpenState="false" id="10000" index="%d" select="false" visible="true">', index),
      '        <trackParameters trackHeight="90" trackHue="-1" trackMinimized="false">',
      '          <name>Master</name>',
      '        </trackParameters>',
      '        <trackAudioParameters audioChannelType="stereo" automationMode="1" monitoring="false" recordArmed="false" solo="false" soloSafe="true">',
      '          <trackOutput outputID="1" type="hardwareOutput"/>',
      '          <trackInput inputID="-1"/>',
      '          <component componentID="Audition.Fader" id="trackFader" name="volume" powered="true">',
      '            <parameter index="0" name="volume" parameterValue="1"/>',
      '            <parameter index="1" name="static gain" parameterValue="1"/>',
      '          </component>',
      '        </trackAudioParameters>',
      '      </masterTrack>'
    }, '\n')
  end

  function core.build_sesx(project_name, manifest)
    manifest = manifest or {files={}, originalClips={}, takeClips={}, durationSamples=0}
    local duration = math.max(manifest.durationSamples or 0, SAMPLE_RATE)
    local out = {
      '<?xml version="1.0" encoding="UTF-8" standalone="no" ?>',
      '<!DOCTYPE sesx>',
      '<sesx version="1.1">',
      string.format('  <session appBuild="25.0.0.0" appVersion="25.0" audioChannelType="stereo" bitDepth="%d" duration="%d" sampleRate="%d">', SESSION_BIT_DEPTH, duration, SAMPLE_RATE),
      '    <name>' .. xml_escape(project_name or 'Odium_Audition_Project') .. '.sesx</name>',
      '    <tracks>',
      track_xml(10001, 1, 'ORIGINAL_REF', 160, manifest.originalClips or {}),
      track_xml(10002, 2, 'DUB_TAKE', 267, manifest.takeClips or {}),
      master_xml(3),
      '    </tracks>',
      '    <sessionState ctiPosition="0" smpteStart="0">',
      '      <selectionState selectionDuration="0" selectionStart="0"/>',
      string.format('      <viewState horizontalViewDuration="%d" horizontalViewStart="0" trackControlsWidth="224" verticalScrollOffset="0"/>', duration),
      '      <timeFormatState beatsPerBar="4" beatsPerMinute="120" customFrameRate="30" linkToDefaultTimeSettings="true" noteLength="4" subdivisions="16" timeCodeDropFrame="false" timeCodeFrameRate="30" timeCodeNTSC="false" timeFormat="timeFormatDecimal"/>',
      '      <mixingOptionState defaultPanModeLogarithmic="false" panPower="-3" playOverlappingClips="true"/>',
      '    </sessionState>',
      '    <clipGroups/>',
      '  </session>',
      '  <files>'
    }
    for _, file in ipairs(manifest.files or {}) do
      out[#out+1] = string.format('    <file id="%d" relativePath="%s"/>', file.id, xml_escape(relative_xml_path(file.relativePath)))
    end
    out[#out+1] = '  </files>'
    out[#out+1] = '</sesx>'
    return table.concat(out, '\n') .. '\n'
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
    local packaged = deep_copy(project)
    packaged.app = 'Odium REAPER Extension -> Adobe Audition SESX'
    packaged.packageFormat = 'sesx'
    packaged.packageRootPath = root
    packaged.packageCreatedAt = core.iso_now()
    packaged.sesxSampleRate = SAMPLE_RATE
    packaged.sesxTrackNames = { originals='ORIGINAL_REF', recordings='DUB_TAKE' }
    packaged.tracks = { originals='ORIGINAL_REF', recordings='DUB_TAKE' }

    local manifest = {
      files = {}, fileIds = {}, originalClips = {}, takeClips = {},
      nextClipId = 1, durationSamples = 0
    }
    local report = {
      createdAt = core.iso_now(), packageRoot = root, format = 'sesx',
      originals = 0, takes = 0, leveled = 0, missingOriginals = {}, missingTakes = {}, warnings = {}
    }
    local preset = core.EXPORT_PRESETS.master_wav_48k_float_mono

    for i, line in ipairs(project.lines) do
      local pline = packaged.lines[i]
      local original_src = line.originalAbsolutePath
      if original_src and core.file_exists(original_src) then
        local original_name = string.format('%04d_%s', i, safe_file_name(line.originalName or ('line_'..i..'.wav')))
        local original_rel = 'Audio/Originals/' .. original_name
        local original_dst = core.join(root, 'Audio', 'Originals', original_name)
        local copied, copy_err = core.copy_file(original_src, original_dst)
        if copied then
          report.originals = report.originals + 1
          pline.originalAbsolutePath = original_dst
          pline.originalRelativePath = original_rel
          pline.packageOriginalRelativePath = original_rel
          add_clip(manifest, 'originalClips', original_rel, line.originalName or original_name,
            tonumber(line.timelineStart) or 0,
            tonumber(line.originalDuration) or math.max(0, (tonumber(line.timelineEnd) or 0) - (tonumber(line.timelineStart) or 0)))
        else
          report.missingOriginals[#report.missingOriginals+1] = (line.originalName or line.lineId) .. ': ' .. tostring(copy_err)
        end
      else
        report.missingOriginals[#report.missingOriginals+1] = line.originalName or line.lineId
      end

      local take_src = line.selectedTakePath
      if (not take_src or take_src == '') and line.selectedTakeId then
        for _, take in ipairs(line.takes or {}) do
          if take.takeId == line.selectedTakeId then
            take_src = take.absolutePath or take.fileAbsolutePath or take.path
            break
          end
        end
      end

      if take_src and core.file_exists(take_src) then
        local stem = select(1, core.splitext(line.exportName or line.originalName or ('line_'..i)))
        local take_name = string.format('%04d_%s_DUB.wav', i, safe_file_name(stem))
        local take_rel = 'Audio/Takes/' .. take_name
        local take_dst = core.join(root, 'Audio', 'Takes', take_name)
        local gain = nil
        if opts.levelMatchOriginal and ffmpeg and line.originalAbsolutePath and core.file_exists(line.originalAbsolutePath) then
          gain = select(1, core.compute_level_gain(ffmpeg, line.originalAbsolutePath, take_src))
        end

        local ok, output = false, nil
        if ffmpeg then
          if line.segments and #line.segments > 0 then
            ok, output = core.export_segments(ffmpeg, line.segments, take_dst, preset, {gainDb=gain})
          else
            ok, output = core.export_file(ffmpeg, take_src, take_dst, preset, {gainDb=gain})
          end
        elseif (not line.segments or #line.segments <= 1) and not opts.levelMatchOriginal then
          local _, ext = core.splitext(take_src)
          take_name = string.format('%04d_%s_DUB.%s', i, safe_file_name(stem), ext ~= '' and ext or 'wav')
          take_rel = 'Audio/Takes/' .. take_name
          take_dst = core.join(root, 'Audio', 'Takes', take_name)
          ok, output = core.copy_file(take_src, take_dst)
        else
          output = 'FFmpeg gerekli: çok parçalı kayıt veya düzey eşitleme doğrudan SESX paketine hazırlanamaz.'
        end

        if ok then
          report.takes = report.takes + 1
          if gain then report.leveled = report.leveled + 1 end
          pline.selectedTakePath = take_dst
          pline.selectedTakeRelativePath = take_rel
          pline.packageTakeRelativePath = take_rel
          for _, packaged_take in ipairs(pline.takes or {}) do
            if not pline.selectedTakeId or packaged_take.takeId == pline.selectedTakeId then
              packaged_take.fileName = take_name
              packaged_take.absolutePath = take_dst
              packaged_take.fileAbsolutePath = take_dst
              packaged_take.fileRelativePath = take_rel
              if pline.selectedTakeId then break end
            end
          end
          local take_start = tonumber(line.mixStart) or tonumber(line.timelineStart) or 0
          local take_duration = nil
          if tonumber(line.mixEnd) and tonumber(line.mixEnd) > take_start then
            take_duration = tonumber(line.mixEnd) - take_start
          elseif line.segments and #line.segments > 0 then
            local first, last = line.segments[1], line.segments[#line.segments]
            take_duration = math.max(0, (tonumber(last.finish) or 0) - (tonumber(first.start) or take_start))
          end
          if not take_duration or take_duration <= 0 then take_duration = core.source_duration(take_dst) end
          add_clip(manifest, 'takeClips', take_rel, 'DUB - ' .. (line.originalName or take_name), take_start, take_duration)
        else
          report.missingTakes[#report.missingTakes+1] = (line.originalName or line.lineId) .. ': ' .. tostring(output)
        end
      else
        report.missingTakes[#report.missingTakes+1] = line.originalName or line.lineId
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
      '========================================',
      '',
      'Mixçi için:',
      '1. Bu klasörü komple aynı yapıda tutun.',
      '2. ' .. sesx_name .. ' dosyasını Adobe Audition ile açın.',
      '3. ORIGINAL_REF trackinde orijinal referanslar, DUB_TAKE trackinde REAPER kayıtları bulunur.',
      '4. .audub/project.json Odium metadata ve export isimlerini içerir.',
      '',
      'Paket REAPER .rpp dosyasına ihtiyaç duymaz.',
      'Orijinal: ' .. tostring(report.originals),
      'Take: ' .. tostring(report.takes),
      'Düzey eşitlenen: ' .. tostring(report.leveled),
      'Eksik orijinal: ' .. tostring(#report.missingOriginals),
      'Eksik take: ' .. tostring(#report.missingTakes),
      ''
    }, '\r\n')
    core.write_file(core.join(root, 'README_AUDITION_MIX.txt'), readme)

    report.sesxPath = sesx_path
    report.projectJson = json_path
    report.sessionFiles = #manifest.files
    report.sessionClips = #manifest.originalClips + #manifest.takeClips
    core.write_file(core.join(meta_dir, 'package-report.json'), core.json.encode(report))
    report.zipPath, report.zipError = zip_folder(root)
    core.write_file(core.join(meta_dir, 'package-report.json'), core.json.encode(report))
    return report
  end

  core.SESX_SAMPLE_RATE = SAMPLE_RATE
  return core
end
