-- Odium Studio REAPER portable package extension.
-- Applies streaming file copy and portable .rpp media relinking to odium_core.
return function(core)
  local sep = package.config:sub(1,1)
  local original_make_package = core.make_package

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

  local function is_absolute(path)
    path = tostring(path or '')
    return path:match('^%a:[\\/]') ~= nil
      or path:match('^[\\/][\\/]') ~= nil
      or path:sub(1,1) == '/'
  end

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

  function core.make_portable_rpp(rpp_path, package_root)
    local text, err = core.read_file(rpp_path)
    if not text then return nil, { 'RPP okunamadı: ' .. tostring(err) } end

    local media_dir = core.join(package_root, 'SessionMedia')
    reaper.RecursiveCreateDirectory(media_dir, 0)
    local rpp_dir = core.dirname(rpp_path)
    local path_map, copied_sources, warnings = {}, {}, {}
    local copied = 0

    for _, token in ipairs(core.collect_rpp_file_paths(text)) do
      local source = is_absolute(token) and core.normalize(token) or core.join(rpp_dir, token)
      local key = core.normalize(source):lower()
      local relative = copied_sources[key]
      if not relative then
        if core.file_exists(source) then
          copied = copied + 1
          relative = string.format('SessionMedia/%04d_%s', copied, core.basename(source))
          local ok, copy_err = core.copy_file(source, core.join(package_root, relative))
          if ok then
            copied_sources[key] = relative
          else
            copied = copied - 1
            relative = nil
            warnings[#warnings+1] = 'Session medyası kopyalanamadı: ' .. token .. ' (' .. tostring(copy_err) .. ')'
          end
        else
          warnings[#warnings+1] = 'RPP medya kaynağı bulunamadı: ' .. token
        end
      end
      if relative then path_map[token] = relative end
    end

    local rewritten, replacements = core.rewrite_rpp_file_paths(text, path_map)
    local destination = core.join(package_root, core.basename(rpp_path))
    local ok, write_err = core.write_file(destination, rewritten)
    if not ok then return nil, { 'Taşınabilir RPP yazılamadı: ' .. tostring(write_err) } end

    return {
      path = destination,
      mediaDirectory = media_dir,
      copiedMedia = copied,
      replacedReferences = replacements,
      warnings = warnings
    }
  end

  local function rebuild_zip(root)
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

  function core.make_package(project, opts)
    opts = opts or {}
    local requested_rpp = opts.rppPath
    local base_options = {}
    for key, value in pairs(opts) do base_options[key] = value end
    base_options.rppPath = nil

    local report = original_make_package(project, base_options)
    local portable, portable_errors
    if requested_rpp and core.file_exists(requested_rpp) then
      portable, portable_errors = core.make_portable_rpp(requested_rpp, report.packageRoot)
    end

    report.rpp = portable and portable.path or requested_rpp
    report.sessionMedia = portable and portable.copiedMedia or 0
    report.rppReferencesRewritten = portable and portable.replacedReferences or 0
    report.rppWarnings = portable and portable.warnings or portable_errors or {}

    local meta = core.join(report.packageRoot, '.audub')
    core.write_file(core.join(meta, 'package-report.json'), core.json.encode(report))
    report.zipPath, report.zipError = rebuild_zip(report.packageRoot)
    return report
  end

  return core
end
