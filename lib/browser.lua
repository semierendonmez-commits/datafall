-- lib/browser.lua
-- datafall: built-in file/folder browser

local browser = {}

browser.active = false
browser.path = "/home/we/"
browser.entries = {}
browser.selected = 1
browser.scroll = 0
browser.visible_rows = 6
browser.callback = nil

function browser.enter_dir(path)
  if not path then return end
  if path:sub(-1) ~= "/" then path = path .. "/" end
  browser.path = path
  browser.entries = {}
  browser.selected = 1
  browser.scroll = 0

  if path ~= "/" then
    table.insert(browser.entries, {
      name = "..", full_path = path:match("(.*/)[^/]+/$") or "/", is_dir = true,
    })
  end

  local dirs, files = {}, {}
  local handle = io.popen('ls -1pa "' .. path .. '" 2>/dev/null')
  if handle then
    for line in handle:lines() do
      if line ~= "./" and line ~= "../" and line:sub(1, 1) ~= "." then
        if line:sub(-1) == "/" then
          table.insert(dirs, { name = line:sub(1, -2), full_path = path .. line, is_dir = true })
        else
          table.insert(files, { name = line, full_path = path .. line, is_dir = false })
        end
      end
    end
    handle:close()
  end

  table.sort(dirs, function(a, b) return a.name:lower() < b.name:lower() end)
  table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
  for _, d in ipairs(dirs) do table.insert(browser.entries, d) end
  for _, f in ipairs(files) do table.insert(browser.entries, f) end
end

function browser.scroll_by(d)
  if #browser.entries == 0 then return end
  browser.selected = util.clamp(browser.selected + d, 1, #browser.entries)
  if browser.selected < browser.scroll + 1 then
    browser.scroll = browser.selected - 1
  elseif browser.selected > browser.scroll + browser.visible_rows then
    browser.scroll = browser.selected - browser.visible_rows
  end
end

function browser.action()
  if #browser.entries == 0 then return end
  local entry = browser.entries[browser.selected]
  if not entry then return end
  if entry.is_dir then
    browser.enter_dir(entry.full_path)
  else
    if browser.callback then browser.callback(entry.full_path) end
    browser.active = false
  end
end

function browser.go_back()
  if browser.path == "/" then
    browser.active = false
    return
  end
  browser.enter_dir(browser.path:match("(.*/)[^/]+/$") or "/")
end

function browser.close()
  browser.active = false
end

local function file_size_str(path)
  local f = io.open(path, "rb")
  if not f then return "?" end
  local size = f:seek("end"); f:close()
  if size > 1048576 then return string.format("%.1fM", size / 1048576)
  elseif size > 1024 then return string.format("%.0fK", size / 1024)
  else return size .. "B" end
end

function browser.draw()
  -- dark background overlay
  screen.level(0)
  screen.rect(0, 0, 128, 64)
  screen.fill()

  screen.level(12)
  screen.move(1, 7)
  screen.font_size(8)
  screen.text("BROWSE")

  screen.level(5)
  screen.move(40, 7)
  local dp = browser.path
  if #dp > 14 then dp = ".." .. dp:sub(-12) end
  screen.text(dp)

  screen.level(1)
  screen.move(0, 9); screen.line(128, 9); screen.stroke()

  if #browser.entries == 0 then
    screen.level(4); screen.move(20, 35); screen.text("(empty)")
    return
  end

  local rh, lt = 9, 13
  for i = 1, browser.visible_rows do
    local idx = browser.scroll + i
    if idx > #browser.entries then break end
    local entry = browser.entries[idx]
    local y = lt + (i - 1) * rh
    local is_sel = (idx == browser.selected)

    if is_sel then
      screen.level(2); screen.rect(0, y - 7, 128, rh); screen.fill()
      screen.level(15); screen.rect(0, y - 7, 2, rh); screen.fill()
    end

    if entry.is_dir then
      screen.level(is_sel and 12 or 6)
      screen.move(5, y); screen.text("> " .. entry.name)
    else
      screen.level(is_sel and 15 or 7)
      screen.move(5, y)
      local nm = entry.name
      if #nm > 18 then nm = nm:sub(1, 15) .. ".." end
      screen.text(nm)
      if is_sel then
        screen.level(4); screen.move(125, y)
        screen.text_right(file_size_str(entry.full_path))
      end
    end
  end

  if browser.scroll > 0 then screen.level(5); screen.move(124, 11); screen.text("^") end
  if browser.scroll + browser.visible_rows < #browser.entries then
    screen.level(5); screen.move(124, 62); screen.text("v")
  end

  screen.level(3); screen.move(1, 63); screen.text("E2:nav K3:open K2:back")
end

function browser.init(start_path, cb)
  browser.callback = cb
  browser.enter_dir(start_path or "/home/we/")
end

return browser
