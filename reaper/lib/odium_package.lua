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

  dofile(base .. 'odium_sesx.lua')(core)
  core.VERSION = '2.1.0'

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
