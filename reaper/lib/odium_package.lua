-- Odium Studio package compatibility layer.
-- v2.1: "make_package" artık REAPER RPP yerine taşınabilir Adobe Audition SESX paketi üretir.
return function(core)
  local base = debug.getinfo(1,'S').source:sub(2):match('^(.*[\\/])') or './'

  -- Büyük medya dosyalarını RAM'e tamamen almadan kopyala.
  function core.copy_file(src, dst)
    local dir = core.dirname(dst)
    if dir ~= '' and reaper and reaper.RecursiveCreateDirectory then
      reaper.RecursiveCreateDirectory(dir, 0)
    end
    local input, err = io.open(src, 'rb')
    if not input then return nil, err end
    local output, out_err = io.open(dst, 'wb')
    if not output then input:close(); return nil, out_err end
    while true do
      local chunk = input:read(4 * 1024 * 1024)
      if not chunk then break end
      local ok, write_err = output:write(chunk)
      if not ok then
        input:close(); output:close()
        return nil, write_err
      end
    end
    input:close(); output:close()
    return true
  end

  -- Eski RPP yardımcılarını test/geriye dönük veri araçları için tut; teslim paketi artık bunları kullanmaz.
  function core.collect_rpp_file_paths(text)
    local paths, seen = {}, {}
    for path in tostring(text or ''):gmatch('FILE%s+"([^"]+)"') do
      if not seen[path] then
        seen[path] = true
        paths[#paths+1] = path
      end
    end
    return paths
  end

  local function replace_plain(text, find, replacement)
    if find == '' then return text, 0 end
    local out, cursor, count = {}, 1, 0
    while true do
      local first, last = text:find(find, cursor, true)
      if not first then
        out[#out+1] = text:sub(cursor)
        break
      end
      out[#out+1] = text:sub(cursor, first - 1)
      out[#out+1] = replacement
      cursor = last + 1
      count = count + 1
    end
    return table.concat(out), count
  end

  function core.rewrite_rpp_file_paths(text, path_map)
    local rewritten, total = tostring(text or ''), 0
    for old_path, new_path in pairs(path_map or {}) do
      local before = 'FILE "' .. old_path .. '"'
      local after = 'FILE "' .. tostring(new_path):gsub('\\','/') .. '"'
      local count
      rewritten, count = replace_plain(rewritten, before, after)
      total = total + count
    end
    return rewritten, total
  end

  -- v2.1.1: v2.0 kurulumundan kalan doğrudan Odium_Reaper_Extension.lua Action kaydı
  -- çalıştırılırsa da ReaImGui 0.10 yaşam döngüsünü güvenli hale getir. Bu katman raw
  -- script require('imgui') yapmadan önce yüklenir, dolayısıyla eski Action List girdisi
  -- yeni kurucuyu beklemeden kendi kendini iyileştirebilir.
  local legacy_action_running = false
  if reaper and reaper.get_action_context then
    local ok, _, filename = pcall(reaper.get_action_context)
    if ok and filename and core.basename(filename) == 'Odium_Reaper_Extension.lua' then
      legacy_action_running = true
    end
  end

  local function install_direct_imgui_compat()
    if not legacy_action_running or not reaper or not reaper.ImGui_GetBuiltinPath then return end
    package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
    local ok_factory, factory = pcall(require, 'imgui')
    if not ok_factory or type(factory) ~= 'function' then return end

    local real = factory('0.10')
    local begin_visible = setmetatable({}, {__mode='k'})
    local proxy = setmetatable({}, {__index=real})

    proxy.Begin = function(ctx, ...)
      local visible, open = real.Begin(ctx, ...)
      begin_visible[ctx] = visible and true or false
      return visible, open
    end

    proxy.End = function(ctx)
      local visible = begin_visible[ctx]
      begin_visible[ctx] = nil
      if visible then return real.End(ctx) end
    end

    proxy.Button = function(ctx, label, ...)
      if label == 'Projeyi kaydet + .rpp ile paketle + ZIP' then
        label = 'Adobe Audition .sesx paketi + ZIP oluştur'
      end
      return real.Button(ctx, label, ...)
    end

    package.loaded.imgui = function(version)
      if tostring(version or '') == '0.10' then return proxy end
      return factory(version)
    end
  end

  local function migrate_legacy_action_to_launcher()
    if not legacy_action_running or not reaper or not reaper.AddRemoveReaScript then return end
    local lib_dir = base:gsub('[\\/]+$', '')
    local root = core.dirname(lib_dir)
    local legacy = core.join(root, 'Odium_Reaper_Extension.lua')
    local launcher = core.join(root, 'Odium_Reaper_Launcher.lua')
    if not core.file_exists(launcher) then return end

    -- Çalışmakta olan legacy scripti etkilemeden Action List'teki eski yolu kaldır.
    pcall(reaper.AddRemoveReaScript, false, 0, legacy, true)
    local ok, command_id = pcall(reaper.AddRemoveReaScript, true, 0, launcher, true)
    if ok and command_id and command_id ~= 0 then
      reaper.SetExtState('OdiumReaper', 'MAIN_COMMAND_ID', tostring(command_id), true)
      reaper.SetExtState('OdiumReaper', 'MAIN_COMMAND_ID_PATH', launcher, true)
      reaper.SetExtState('OdiumReaper', 'INSTALL_ROOT', root .. package.config:sub(1,1), true)
    end
  end

  install_direct_imgui_compat()
  migrate_legacy_action_to_launcher()

  dofile(base .. 'odium_sesx.lua')(core)
  core.VERSION = '2.1.1'

  -- Mevcut UI core.make_package çağırdığı için API adını koruyoruz; çıktı artık SESX'tir.
  function core.make_package(project, opts)
    opts = opts or {}
    return core.make_audition_package(project, {
      packageRoot = opts.packageRoot,
      ffmpeg = opts.ffmpeg,
      levelMatchOriginal = opts.levelMatchOriginal
    })
  end

  return core
end