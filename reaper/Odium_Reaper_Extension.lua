-- @description Odium Studio - REAPER Dublaj Uzantısı
-- @version 2.0.0
-- @author Odium Studio
-- @about
--   Oyun dublajı için seslendirme sanatçısı ve mixçi iş akışı.
--   Requires: REAPER 7+, ReaImGui 0.10+, FFmpeg.

local SCRIPT_PATH = debug.getinfo(1,'S').source:sub(2)
local SCRIPT_DIR = SCRIPT_PATH:match('^(.*[\\/])') or './'
local lib = SCRIPT_DIR .. 'lib' .. package.config:sub(1,1)
local host = dofile(lib .. 'odium_reaper.lua')
local core = host.core

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB('Odium REAPER Uzantısı için ReaImGui gerekli. ReaPack > Browse packages içinde "ReaImGui" aratıp kurun.', 'Odium Studio', 0)
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ok_imgui, ImGui = pcall(require, 'imgui')
if not ok_imgui then
  reaper.MB('ReaImGui yüklenemedi: ' .. tostring(ImGui), 'Odium Studio', 0)
  return
end
ImGui = ImGui('0.10')

math.randomseed(os.time())
local ctx = ImGui.CreateContext('Odium Studio - REAPER Dublaj Uzantısı')
local font = ImGui.CreateFont('sans-serif', 15)
ImGui.Attach(ctx, font)

local state = {
  role = nil, project = nil, originalFolder = '', projectName = 'Game_Dub_Project',
  gap = 1.0, matchMode = 0, projectJson = '', mixFile = '', outputFolder = '',
  takeFolder = '', origTrack = 1, recTrack = 2, levelMatch = true,
  presetIndex = 1, status = 'Hazır', logs = {}, progress = 0, busy = false,
  ffmpeg = core.find_ffmpeg(SCRIPT_DIR), showAdvanced = false,
  updateText = '', pinInput = '', unlocked = false, pinSetup = ''
}

local preset_ids = {}
for id in pairs(core.EXPORT_PRESETS) do preset_ids[#preset_ids+1] = id end
table.sort(preset_ids)
for i,id in ipairs(preset_ids) do if id == 'game_wav_48k_24_mono' then state.presetIndex=i end end

local function log(msg)
  state.status = tostring(msg)
  state.logs[#state.logs+1] = os.date('%H:%M:%S') .. '  ' .. tostring(msg)
  if #state.logs > 250 then table.remove(state.logs,1) end
end

local function protect(label, fn)
  if state.busy then return end
  state.busy=true; state.progress=0; log(label .. '...')
  local ok, result = xpcall(fn, debug.traceback)
  state.busy=false
  if ok then
    state.progress=1
    if result then log(tostring(result)) else log(label .. ' tamamlandı.') end
  else
    log('HATA: ' .. tostring(result))
    reaper.MB(tostring(result), 'Odium Studio - Hata', 0)
  end
end

local function browse_folder(title, initial)
  if reaper.JS_Dialog_BrowseForFolder then
    local rv, path = reaper.JS_Dialog_BrowseForFolder(title or 'Klasör seç', initial or '')
    if rv == 1 and path and path ~= '' then return path end
  end
  local ok, value = reaper.GetUserInputs(title or 'Klasör yolu', 1, 'Klasör yolu:,extrawidth=300', initial or '')
  if ok and value ~= '' then return value end
end

local function browse_file(title, ext, initial)
  local ok, path = reaper.GetUserFileNameForRead(initial or '', title or 'Dosya seç', ext or '')
  if ok then return path end
end

local function default_project_json(project)
  local root = project and project.projectRootPath or state.originalFolder
  return core.join(root, '.audub', 'project.json')
end

local function save_project()
  assert(state.project, 'Önce proje oluşturun veya yükleyin.')
  local path = state.projectJson ~= '' and state.projectJson or default_project_json(state.project)
  core.save_project(state.project, path); state.projectJson=path
  return 'Project JSON kaydedildi: ' .. path
end

local function select_preset(project)
  local id = preset_ids[state.presetIndex] or 'game_wav_48k_24_mono'
  if project then project.exportPresetId=id end
  return id
end

local function update_summary()
  if not state.project then return 'Proje yok.' end
  local s=core.project_summary(state.project)
  return string.format('%s | %d replik | %d eşleşmiş | %d take', state.project.projectName or 'Proje',s.total,s.matched,s.takes)
end

local function fnv1a(s)
  local hash=2166136261
  for i=1,#s do hash=((hash ~ s:byte(i)) * 16777619) & 0xffffffff end
  return string.format('%08x',hash)
end

local saved_pin_hash = reaper.GetExtState('OdiumReaper','PIN_HASH')
state.unlocked = saved_pin_hash == ''

local function check_pin()
  if saved_pin_hash == '' or fnv1a(state.pinInput) == saved_pin_hash then state.unlocked=true; state.pinInput=''; log('Yetkili giriş başarılı.')
  else log('Hatalı PIN.') end
end

local function input_text(label, value, width)
  if width then ImGui.SetNextItemWidth(ctx,width) end
  local changed,new = ImGui.InputText(ctx,label,value or '')
  return changed and new or value
end

local function path_row(label, value, pick_fn)
  ImGui.Text(ctx,label)
  ImGui.SetNextItemWidth(ctx,-105)
  local ch,new=ImGui.InputText(ctx,'##'..label,value or '')
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx,'Gözat##'..label,95,0) then local p=pick_fn(); if p then new=p; ch=true end end
  return ch and new or value
end

local function button(label, fn, w)
  local clicked=ImGui.Button(ctx,label,w or -1,0)
  if clicked and not state.busy then fn() end
end

local function draw_login()
  ImGui.TextWrapped(ctx,'Bu REAPER kurulumu için Odium erişim PIN’i tanımlı. Devam etmek için PIN’i girin.')
  ImGui.SetNextItemWidth(ctx,-1)
  local changed; changed,state.pinInput=ImGui.InputText(ctx,'##pin',state.pinInput)
  if ImGui.Button(ctx,'Giriş Yap',-1,0) then check_pin() end
end

local function draw_header()
  ImGui.Text(ctx,'Odium Studio')
  ImGui.SameLine(ctx)
  ImGui.TextDisabled(ctx,'REAPER Dublaj Uzantısı v'..core.VERSION)
  ImGui.Separator(ctx)
  ImGui.TextWrapped(ctx,state.status)
  if state.busy then ImGui.ProgressBar(ctx,state.progress,-1,4) end
end

local function draw_role_chooser()
  ImGui.Spacing(ctx); ImGui.TextWrapped(ctx,'Çalışma rolünü seçin. Her rol yalnızca kendi üç ana adımını gösterir.')
  ImGui.Spacing(ctx)
  if ImGui.Button(ctx,'🎙  Seslendirme Sanatçısı',-1,54) then state.role='voice' end
  if ImGui.Button(ctx,'🎚  Mixçi',-1,54) then state.role='mixer' end
end

local function draw_voice()
  if ImGui.Button(ctx,'← Rol seçimine dön') then state.role=nil end
  ImGui.SeparatorText(ctx,'1. Orijinalleri hazırla')
  state.projectName=input_text('Proje adı',state.projectName)
  local changed; changed,state.gap=ImGui.InputDouble(ctx,'Replik arası boşluk (sn)',state.gap,0.1,1.0,'%.2f')
  state.originalFolder=path_row('Orijinal ses klasörü',state.originalFolder,function() return browse_folder('Orijinal ses klasörü',state.originalFolder) end)
  button('Proje oluştur + REAPER timeline’a yerleştir',function()
    protect('Proje oluşturuluyor',function()
      assert(state.originalFolder~='','Orijinal klasörünü seçin.')
      local _,rpp= reaper.EnumProjects(-1,'')
      local root=(rpp and rpp~='') and core.dirname(rpp) or state.originalFolder
      state.project=core.create_project{originalFolder=state.originalFolder,projectName=state.projectName,gapSeconds=state.gap,projectRootPath=root,exportPresetId=select_preset(),levelMatchOriginal=state.levelMatch}
      host.place_originals(state.project); state.projectJson=default_project_json(state.project); core.save_project(state.project,state.projectJson)
      return update_summary()
    end)
  end)

  ImGui.SeparatorText(ctx,'2. Kaydı eşle')
  ImGui.TextWrapped(ctx,'Kayıtları "ODIUM - Recordings" track’ine alın. Pozisyon modu, her kaydı üstündeki orijinal bölgesine bağlar; sıra modu item sırasını kullanır.')
  local combo_items='Pozisyona göre\0Sıraya göre\0\0'
  local c; c,state.matchMode=ImGui.Combo(ctx,'Eşleme modu',state.matchMode,combo_items)
  button('REAPER kayıt item’larını eşleştir',function()
    protect('Kayıtlar eşleştiriliyor',function()
      assert(state.project,'Önce proje oluşturun.')
      local m,n=host.match_recordings(state.project,state.matchMode==1 and 'order' or 'position')
      core.save_project(state.project,state.projectJson~='' and state.projectJson or default_project_json(state.project))
      return string.format('%d/%d kayıt item’ı eşleştirildi. %s',m,n,update_summary())
    end)
  end)
  state.takeFolder=path_row('Hazır take klasörü',state.takeFolder,function() return browse_folder('Take klasörü',state.takeFolder) end)
  button('Klasörden dosya adına göre take bağla',function()
    protect('Take dosyaları bağlanıyor',function()
      assert(state.project,'Proje yok.'); assert(state.takeFolder~='','Take klasörünü seçin.')
      local n=core.attach_takes_by_name(state.project,state.takeFolder); save_project(); return n..' take bağlandı.'
    end)
  end)

  ImGui.SeparatorText(ctx,'3. Mixçiye gönder')
  local ch; ch,state.levelMatch=ImGui.Checkbox(ctx,'Kayıt düzeyini orijinal ortalama dB seviyesine eşitle',state.levelMatch)
  ImGui.TextWrapped(ctx,'Düzey eşitleme yalnız paket kopyalarına uygulanır. Kaynak kayıtlarınıza dokunulmaz; tepe -1 dBFS’i aşmayacak şekilde gain sınırlandırılır.')
  button('Projeyi kaydet + .rpp ile paketle + ZIP',function()
    protect('Paket hazırlanıyor',function()
      assert(state.project,'Proje yok.')
      local rpp=host.save_current_project(); assert(rpp~='','Önce REAPER projesini .rpp olarak kaydedin.')
      state.project.levelMatchOriginal=state.levelMatch; state.project.projectRootPath=core.dirname(rpp); save_project()
      local rep=core.make_package(state.project,{rppPath=rpp,ffmpeg=state.ffmpeg,levelMatchOriginal=state.levelMatch})
      return string.format('Paket hazır: %s | orijinal %d, take %d, eşitlenen %d%s',rep.packageRoot,rep.originals,rep.takes,rep.leveled,rep.zipPath and ' | ZIP: '..rep.zipPath or '')
    end)
  end)
end

local function draw_mixer()
  if ImGui.Button(ctx,'← Rol seçimine dön') then state.role=nil end
  ImGui.SeparatorText(ctx,'1. Projeyi yükle')
  state.projectJson=path_row('project.json',state.projectJson,function() return browse_file('Odium project.json seç','json',state.projectJson) end)
  button('Project JSON yükle',function()
    protect('Proje yükleniyor',function()
      assert(state.projectJson~='','project.json seçin.')
      state.project=core.load_project(state.projectJson); state.projectName=state.project.projectName or state.projectName
      for i,id in ipairs(preset_ids) do if id==state.project.exportPresetId then state.presetIndex=i end end
      return update_summary()
    end)
  end)
  ImGui.SeparatorText(ctx,'PROJECT.JSON YOKSA')
  local c; c,state.origTrack=ImGui.InputInt(ctx,'Orijinal track no',state.origTrack)
  c,state.recTrack=ImGui.InputInt(ctx,'Kayıt track no',state.recTrack)
  state.outputFolder=path_row('Yeni proje kökü',state.outputFolder,function() return browse_folder('Proje kökü',state.outputFolder) end)
  button('Track pozisyonlarından proje oluştur',function()
    protect('Track’lerden proje oluşturuluyor',function()
      local _,rpp=reaper.EnumProjects(-1,''); local root=state.outputFolder~='' and state.outputFolder or (rpp~='' and core.dirname(rpp) or '.')
      state.project=host.build_from_tracks(state.origTrack,state.recTrack,{projectName=state.projectName,projectRootPath=root})
      state.projectJson=default_project_json(state.project); core.save_project(state.project,state.projectJson); return update_summary()
    end)
  end)

  ImGui.SeparatorText(ctx,'2. Tek mixdown dosyasını böl')
  state.mixFile=path_row('Mixdown dosyası',state.mixFile,function() return browse_file('Tek parça mixdown seç','wav,flac,mp3',state.mixFile) end)
  local splitDefault=state.project and core.join(state.project.projectRootPath,'Audio','MixSplit') or state.outputFolder
  state.outputFolder=path_row('Çıktı klasörü',state.outputFolder,function() return browse_folder('Çıktı klasörü',state.outputFolder~='' and state.outputFolder or splitDefault) end)
  button('Mix dosyasını replik sınırlarına göre böl',function()
    protect('Mix bölünüyor',function()
      assert(state.project,'Proje yükleyin.'); assert(state.mixFile~='','Mix dosyasını seçin.'); assert(state.ffmpeg,'FFmpeg bulunamadı.')
      local out=state.outputFolder~='' and state.outputFolder or core.join(state.project.projectRootPath,'Audio','MixSplit')
      local rep=core.split_mix(state.project,state.ffmpeg,state.mixFile,out,function(i,n) state.progress=i/n end)
      core.write_file(core.join(out,'mix-split-report.json'),core.json.encode(rep)); save_project()
      return string.format('%d dosya üretildi, %d hata.',#rep.items,#rep.errors)
    end)
  end)

  ImGui.SeparatorText(ctx,'3. Orijinal isimlerle toplu export')
  local labels={}; for _,id in ipairs(preset_ids) do labels[#labels+1]=core.EXPORT_PRESETS[id].name end
  local combo=table.concat(labels,'\0')..'\0\0'; local changed
  local zero_index=state.presetIndex-1
  changed,zero_index=ImGui.Combo(ctx,'Export preset',zero_index,combo)
  state.presetIndex=zero_index+1
  local preset=core.EXPORT_PRESETS[preset_ids[state.presetIndex]]
  ImGui.TextWrapped(ctx,string.format('%s | %d Hz | %d kanal | %s',preset.name,preset.sr,preset.channels,preset.codec))
  state.outputFolder=path_row('Export klasörü',state.outputFolder,function() return browse_folder('Export klasörü',state.outputFolder) end)
  local ch; ch,state.levelMatch=ImGui.Checkbox(ctx,'Export sırasında orijinal düzeyine eşitle',state.levelMatch)
  button('Toplu export çalıştır',function()
    protect('Export çalışıyor',function()
      assert(state.project,'Proje yükleyin.'); assert(state.ffmpeg,'FFmpeg bulunamadı.'); assert(state.outputFolder~='','Export klasörünü seçin.')
      local id=select_preset(state.project)
      local rep=core.export_project(state.project,state.ffmpeg,state.outputFolder,id,state.levelMatch,function(i,n) state.progress=i/n end)
      core.write_file(core.join(state.outputFolder,'export-report.json'),core.json.encode(rep)); save_project()
      return string.format('%d çıktı üretildi, %d hata.',#rep.items,#rep.errors)
    end)
  end)
end

local function draw_advanced()
  ImGui.SeparatorText(ctx,'Gelişmiş / Sağlık')
  state.ffmpeg=path_row('FFmpeg yolu',state.ffmpeg or '',function() return browse_file('ffmpeg seç',package.config:sub(1,1)=='\\' and 'exe' or '',state.ffmpeg or '') end)
  button('Sağlık kontrolü',function()
    protect('Sağlık kontrolü',function()
      assert(state.project,'Proje yok.')
      local r=core.health_check(state.project,state.ffmpeg)
      local root=state.project.projectRootPath or '.'; core.write_file(core.join(root,'.audub','health-report.json'),core.json.encode(r))
      return string.format('Sağlık: %s | %d hata | %d uyarı',r.ok and 'OK' or 'HATALI',#r.errors,#r.warnings)
    end)
  end)
  button('Project JSON kaydet',function() protect('Project JSON kaydediliyor',save_project) end)
  if state.project then
    ImGui.SeparatorText(ctx,'Replikler')
    local max=math.min(#state.project.lines,200)
    if ImGui.BeginChild(ctx,'lines',-1,180) then
      for i=1,max do
        local line=state.project.lines[i]
        local mark=(line.selectedTakePath and '✓' or line.mixStart and '◐' or '·')
        if ImGui.Selectable(ctx,string.format('%s %04d  %s',mark,i,line.originalName or line.lineId),false) then host.select_line(state.project,i) end
      end
      ImGui.EndChild(ctx)
    end
  end
  ImGui.SeparatorText(ctx,'Yerel erişim PIN’i')
  state.pinSetup=input_text('Yeni PIN (boş = kaldır)',state.pinSetup)
  if ImGui.Button(ctx,'PIN ayarını kaydet',-1,0) then
    if state.pinSetup=='' then reaper.DeleteExtState('OdiumReaper','PIN_HASH',true); saved_pin_hash=''; log('PIN kaldırıldı.')
    else saved_pin_hash=fnv1a(state.pinSetup); reaper.SetExtState('OdiumReaper','PIN_HASH',saved_pin_hash,true); state.pinSetup=''; log('PIN kaydedildi.') end
  end
end

local function draw_log()
  ImGui.SeparatorText(ctx,'İşlem günlüğü')
  if ImGui.BeginChild(ctx,'log',-1,130) then
    for _,line in ipairs(state.logs) do ImGui.TextWrapped(ctx,line) end
    if #state.logs>0 then ImGui.SetScrollHereY(ctx,1.0) end
    ImGui.EndChild(ctx)
  end
end

local open=true
local function loop()
  local visible
  visible,open=ImGui.Begin(ctx,'Odium Studio - REAPER Dublaj Uzantısı',open)
  if visible then
    ImGui.PushFont(ctx,font)
    draw_header()
    if not state.unlocked then draw_login()
    elseif not state.role then draw_role_chooser()
    elseif state.role=='voice' then draw_voice()
    else draw_mixer() end
    if state.unlocked then
      state.showAdvanced=ImGui.CollapsingHeader(ctx,'Gelişmiş / Tam Panel')
      if state.showAdvanced then draw_advanced() end
      draw_log()
      ImGui.TextDisabled(ctx,update_summary())
    end
    ImGui.PopFont(ctx)
    ImGui.End(ctx)
  end
  if open then reaper.defer(loop) end
end

log(state.ffmpeg and ('FFmpeg hazır: '..state.ffmpeg) or 'FFmpeg bulunamadı; split/export için kurulum gerekli.')
loop()
