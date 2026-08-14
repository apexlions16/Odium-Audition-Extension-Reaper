-- @description Odium Studio - Güncelleme Kontrolü
-- @version 2.0.0
-- @author Odium Studio

local SCRIPT_PATH = debug.getinfo(1,'S').source:sub(2)
local SCRIPT_DIR = SCRIPT_PATH:match('^(.*[\\/])') or './'
local sep = package.config:sub(1,1)
local core = dofile(SCRIPT_DIR .. 'lib' .. sep .. 'odium_core.lua')

local UPDATE_MANIFEST_URL = 'https://github.com/apexlions16/Odium-Audition-Extension-Reaper/releases/latest/download/version.json'
local RELEASE_PAGE = 'https://github.com/apexlions16/Odium-Audition-Extension-Reaper/releases/latest'

local function q(s)
  return core.shell_quote(tostring(s or ''))
end

local function temp_file(name)
  local base = os.getenv('TEMP') or os.getenv('TMPDIR') or '/tmp'
  return core.join(base, name)
end

local function fetch(url, dst)
  local ok, out = core.run_capture('curl -fL --retry 2 --connect-timeout 12 -o ' .. q(dst) .. ' ' .. q(url))
  if ok and core.file_exists(dst) then return true end
  if sep == '\\' then
    local cmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri ' ..
      string.format("'%s'", tostring(url):gsub("'", "''")) .. ' -OutFile ' ..
      string.format("'%s'", tostring(dst):gsub("'", "''")) .. '"'
    ok, out = core.run_capture(cmd)
    if ok and core.file_exists(dst) then return true end
  end
  return false, out
end

local function version_parts(v)
  local out = {}
  for n in tostring(v or ''):gmatch('%d+') do out[#out+1] = tonumber(n) or 0 end
  return out
end

local function newer(a, b)
  local aa, bb = version_parts(a), version_parts(b)
  for i=1,math.max(#aa,#bb) do
    local x, y = aa[i] or 0, bb[i] or 0
    if x ~= y then return x > y end
  end
  return false
end

local function os_family()
  local osname = (reaper.GetOS and reaper.GetOS() or ''):lower()
  if osname:find('win',1,true) then return 'windows' end
  if osname:find('osx',1,true) or osname:find('mac',1,true) then return 'macos' end
  return 'linux'
end

local function open_url(url)
  if not url or url == '' then url = RELEASE_PAGE end
  if os_family() == 'windows' then
    os.execute('start "" ' .. q(url))
  elseif os_family() == 'macos' then
    os.execute('open ' .. q(url) .. ' >/dev/null 2>&1 &')
  else
    os.execute('xdg-open ' .. q(url) .. ' >/dev/null 2>&1 &')
  end
end

local function sha256(path)
  if os_family() == 'windows' then
    local ok, out = core.run_capture('certutil -hashfile ' .. q(path) .. ' SHA256')
    if ok then
      for token in tostring(out or ''):gmatch('[0-9A-Fa-f]+') do
        if #token == 64 then return token end
      end
    end
  else
    local ok, out = core.run_capture('shasum -a 256 ' .. q(path))
    if not ok then ok, out = core.run_capture('sha256sum ' .. q(path)) end
    if ok then
      local token = tostring(out or ''):match('^([0-9A-Fa-f]+)')
      if token and #token == 64 then return token end
    end
  end
end

local manifest_path = temp_file('odium-reaper-version.json')
local ok, err = fetch(UPDATE_MANIFEST_URL, manifest_path)
if not ok then
  reaper.MB('Güncelleme manifesti alınamadı. İnternet bağlantınızı kontrol edin veya Releases sayfasını açın.\n\n' .. tostring(err or ''), 'Odium Studio', 0)
  open_url(RELEASE_PAGE)
  return
end

local text, read_err = core.read_file(manifest_path)
os.remove(manifest_path)
if not text then
  reaper.MB('Güncelleme manifesti okunamadı: ' .. tostring(read_err), 'Odium Studio', 0)
  return
end

local parsed_ok, manifest = pcall(core.json.decode, text)
if not parsed_ok or type(manifest) ~= 'table' then
  reaper.MB('Güncelleme manifesti geçersiz.', 'Odium Studio', 0)
  return
end

local latest = tostring(manifest.version or '')
if latest == '' then
  reaper.MB('Güncelleme manifestinde sürüm bilgisi yok.', 'Odium Studio', 0)
  return
end

if not newer(latest, core.VERSION) then
  reaper.MB('Odium Studio güncel.\n\nKurulu sürüm: ' .. core.VERSION .. '\nYayınlanan sürüm: ' .. latest, 'Odium Studio', 0)
  return
end

local family = os_family()
local url = family == 'windows' and manifest.setupUrl or family == 'macos' and manifest.macosUrl or manifest.linuxUrl
url = url or manifest.releaseUrl or RELEASE_PAGE

local notes = tostring(manifest.notes or '')
local answer = reaper.MB('Yeni Odium sürümü bulundu: v' .. latest .. '\n\n' .. notes .. '\n\nGüncellemeyi açmak ister misiniz?', 'Odium Studio - Güncelleme', 4)
if answer ~= 6 then return end

if family ~= 'windows' then
  open_url(url)
  return
end

local setup_path = temp_file('Odium-REAPER-Windows-Setup.exe')
local dl_ok, dl_err = fetch(url, setup_path)
if not dl_ok then
  reaper.MB('Windows kurucusu indirilemedi. Releases sayfası açılacak.\n\n' .. tostring(dl_err or ''), 'Odium Studio', 0)
  open_url(manifest.releaseUrl or RELEASE_PAGE)
  return
end

local expected = tostring(manifest.setupSha256 or ''):lower()
if expected ~= '' then
  local actual = (sha256(setup_path) or ''):lower()
  if actual == '' or actual ~= expected then
    os.remove(setup_path)
    reaper.MB('İndirilen kurucunun SHA-256 doğrulaması başarısız oldu. Dosya çalıştırılmadı.', 'Odium Studio - Güvenlik', 0)
    return
  end
end

reaper.MB('Kurucu indirildi. REAPER\'ı kapatmanız istenebilir; kurulum penceresi şimdi açılacak.', 'Odium Studio', 0)
os.execute('start "" ' .. q(setup_path))
